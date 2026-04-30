#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 固定配置（按当前发布流程约定）
REPO_BASE="/root/code"
MODULES_CONF="$script_dir/modules.conf"
TAG_GLOB="v[0-9]*.[0-9]*.[0-9]*"
CODEX_BIN="${RELEASE_NOTES_CODEX_BIN:-codex}"
ARCHIVE_DIR="/opt/packages"
KEEP_RAW_INPUT="false"
DEFAULT_REMOTE="origin"
FEISHU_SENDER="$script_dir/send_feishu_robot_message.py"

load_env_file() {
  local env_file="$1"
  [[ -f "$env_file" ]] || return 0

  set -a
  # shellcheck disable=SC1090
  source "$env_file"
  set +a
}

authoring_note() {
  :
}

usage() {
  cat <<EOF
用法:
  ./scripts/release_notes.sh
  ./scripts/release_notes.sh --module <模块名>

说明:
  1. 默认从 $MODULES_CONF 读取模块列表（每行一个模块，支持 # 注释）。
  2. 每个模块仓库默认位于：$REPO_BASE/<模块名>
  3. 版本范围默认按“本地 $DEFAULT_REMOTE 跟踪分支 + tag”比较：
     - 若 $DEFAULT_REMOTE 默认分支 == 最新 tag：使用 上一个tag..最新tag
     - 否则：使用 最新tag..$DEFAULT_REMOTE 默认分支
  4. 每个模块先写：/tmp/release_notes_<模块名>.md
  5. 然后尝试追加到：$ARCHIVE_DIR/release_notes_<模块名>.md
  6. 若归档中已存在相同版本范围标题，则跳过追加
EOF
}

fail() {
  printf 'Error: %s
' "$*" >&2
  exit 1
}

load_runtime_config() {
  load_env_file "$script_dir/.env"
  load_env_file "$script_dir/release_notes.env"
}

warn() {
  printf 'Warn: %s
' "$*" >&2
}

trim() {
  local v="$1"
  v="${v#"${v%%[![:space:]]*}"}"
  v="${v%"${v##*[![:space:]]}"}"
  printf '%s' "$v"
}

read_modules() {
  local conf="$1"
  [[ -f "$conf" ]] || fail "modules.conf 不存在：$conf"

  local line module
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    module="$(trim "$line")"
    [[ -n "$module" ]] || continue
    modules+=("$module")
  done < "$conf"
}

get_semver_tags() {
  local repo_dir="$1"
  git -C "$repo_dir" tag -l "$TAG_GLOB" | sort -V
}

resolve_origin_ref() {
  local repo_dir="$1"
  local remote_head remote_branch

  remote_head="$(git -C "$repo_dir" symbolic-ref -q "refs/remotes/$DEFAULT_REMOTE/HEAD" 2>/dev/null || true)"
  if [[ -n "$remote_head" ]]; then
    printf '%s' "${remote_head#refs/remotes/}"
    return 0
  fi

  remote_branch="$(git -C "$repo_dir" for-each-ref --format='%(refname:short)' "refs/remotes/$DEFAULT_REMOTE/main" "refs/remotes/$DEFAULT_REMOTE/master" | head -n 1)"
  if [[ -n "$remote_branch" ]]; then
    printf '%s' "$remote_branch"
    return 0
  fi

  return 1
}

resolve_default_range() {
  local repo_dir="$1"
  local latest_tag latest_tag_commit target_commit

  mapfile -t semver_tags < <(get_semver_tags "$repo_dir")
  if [[ "${#semver_tags[@]}" -eq 0 ]]; then
    return 1
  fi

  target_ref="$(resolve_origin_ref "$repo_dir")" || return 1
  latest_tag="${semver_tags[-1]}"
  latest_tag_commit="$(git -C "$repo_dir" rev-list -n 1 "$latest_tag")"
  target_commit="$(git -C "$repo_dir" rev-parse "$target_ref")"

  if [[ "$latest_tag_commit" == "$target_commit" ]]; then
    if [[ "${#semver_tags[@]}" -lt 2 ]]; then
      return 1
    fi
    old_ref="${semver_tags[-2]}"
    new_ref="$latest_tag"
  else
    old_ref="$latest_tag"
    new_ref="$target_ref"
  fi
  return 0
}

build_raw_payload() {
  local repo_dir="$1"
  local range="$2"
  local commit_total stats_line files_changed insertions deletions contributors_md
  local commit_list commit_list_all changed_files

  commit_total="$(git -C "$repo_dir" rev-list --count "$range")"
  [[ "$commit_total" -gt 0 ]] || return 1

  stats_line="$(git -C "$repo_dir" diff --shortstat "$old_ref" "$new_ref" | sed 's/^ *//')"
  files_changed="$(printf '%s
' "$stats_line" | sed -n 's/.*\([0-9][0-9]*\) files\? changed.*//p')"
  insertions="$(printf '%s
' "$stats_line" | sed -n 's/.*\([0-9][0-9]*\) insertions\?(+).*//p')"
  deletions="$(printf '%s
' "$stats_line" | sed -n 's/.*\([0-9][0-9]*\) deletions\?(-).*//p')"
  files_changed="${files_changed:-0}"
  insertions="${insertions:-0}"
  deletions="${deletions:-0}"

  contributors_md="$(git -C "$repo_dir" shortlog -sne "$range" | awk '{
    count=$1
    $1=""
    sub(/^ +/, "", $0)
    name=$0
    sub(/ <.*$/, "", name)
    if (name == "") name="unknown"
    printf "- @%s (%s 次提交)\n", name, count
  }')"
  if [[ -z "$contributors_md" ]]; then
    contributors_md="- 无"
  fi

  commit_list="$(git -C "$repo_dir" log --reverse --no-merges --format='- `%h` | %ad | %an | %s' --date=short "$range")"
  if [[ -z "$commit_list" ]]; then
    commit_list="- 无（该范围只有合并提交）"
  fi

  commit_list_all="$(git -C "$repo_dir" log --reverse --format='- `%h` | %ad | %an | %s' --date=short "$range")"
  changed_files="$(git -C "$repo_dir" diff --name-status "$old_ref" "$new_ref" | awk '{print "- `" $1 "` " $2}')"
  if [[ -z "$changed_files" ]]; then
    changed_files="- 无"
  fi

  raw_report=""
  raw_report="${raw_report}# 版本区间原始变更数据"$'

'
  raw_report="${raw_report}> 模块：\`${module_name}\`"$'
'
  raw_report="${raw_report}> 仓库：\`${repo_dir}\`"$'
'
  raw_report="${raw_report}> 版本范围：\`${old_ref}\` -> \`${new_ref}\`"$'
'
  raw_report="${raw_report}> 提交范围：\`${range}\`"$'

'

  raw_report="${raw_report}## 统计信息"$'
'
  raw_report="${raw_report}- 提交总数：${commit_total}"$'
'
  raw_report="${raw_report}- 变更文件数：${files_changed}"$'
'
  raw_report="${raw_report}- 代码行数变化：+${insertions} / -${deletions}"$'

'

  raw_report="${raw_report}## 贡献者列表"$'
'
  raw_report="${raw_report}${contributors_md}"$'

'

  raw_report="${raw_report}## 提交列表（不含 merge）"$'
'
  raw_report="${raw_report}${commit_list}"$'

'

  raw_report="${raw_report}## 提交列表（含 merge）"$'
'
  raw_report="${raw_report}${commit_list_all}"$'

'

  raw_report="${raw_report}## 变更文件（name-status）"$'
'
  raw_report="${raw_report}${changed_files}"$'
'

  return 0
}

codex_supports_exec() {
  "$CODEX_BIN" exec --help >/dev/null 2>&1
}

codex_supports_legacy_io() {
  local help_text
  help_text="$("$CODEX_BIN" --help 2>&1 || true)"
  [[ "$help_text" == *"--input"* && "$help_text" == *"--output"* ]]
}

check_codex_requirements() {
  command -v "$CODEX_BIN" >/dev/null 2>&1 || fail "未找到 codex 命令：$CODEX_BIN"

  if codex_supports_exec; then
    return 0
  fi
  if codex_supports_legacy_io; then
    return 0
  fi

  fail "Codex CLI 不兼容：需要支持 'codex exec -C -o' 或旧版 '--input/--output' 参数"
}

run_codex() {
  local repo_dir="$1"
  local raw_file="$2"
  local final_file="$3"
  local raw_payload codex_prompt codex_log_file exec_supported="false" legacy_supported="false"

  raw_payload="$(cat "$raw_file")"

  codex_prompt="$(cat <<EOF
你现在要生成模块发布说明。下面是原始变更数据：
<raw_release_data>
$raw_payload
</raw_release_data>

请输出中文 Markdown，要求：
1. 标题：## 版本变更摘要（$old_ref → $new_ref）
2. 小节顺序固定：
   - 新增
   - 体验
   - 性能
   - 安全
3. 每个小节使用 1、2、3 编号；无内容写“无”。
4. 语言简洁，不要照抄英文 commit 原文。
5. 不要包含以下信息：
   - 提交总数
   - 变更文件数
   - 代码行数变化
   - 贡献者列表
6. 只输出最终 Markdown 正文，不要解释过程。
EOF
)"

  codex_log_file="$(mktemp "${TMPDIR:-/tmp}/release-notes-codex.${module_name}.XXXXXX.log")"
  if codex_supports_exec; then
    exec_supported="true"
  elif codex_supports_legacy_io; then
    legacy_supported="true"
  else
    fail "Codex CLI 不兼容：需要支持 'codex exec -C -o' 或旧版 '--input/--output' 参数"
  fi

  if [[ "$exec_supported" == "true" ]]; then
    if "$CODEX_BIN" exec -C "$repo_dir" -o "$final_file" "$codex_prompt" > /dev/null 2>"$codex_log_file"; then
      [[ -s "$final_file" ]] || fail "codex exec 未生成有效文件：$final_file"
      rm -f "$codex_log_file"
      return 0
    fi
  fi

  if [[ "$legacy_supported" == "true" ]]; then
    if "$CODEX_BIN" --input "$codex_prompt" --output "$final_file" > /dev/null 2>"$codex_log_file"; then
      [[ -s "$final_file" ]] || fail "codex 未生成有效文件：$final_file"
      rm -f "$codex_log_file"
      return 0
    fi
  fi

  if [[ -s "$codex_log_file" ]]; then
    sed -n '1,40p' "$codex_log_file" >&2
  fi
  rm -f "$codex_log_file"
  return 1
}

archive_has_range() {
  local dst_file="$1"
  local heading="$2"

  [[ -f "$dst_file" ]] || return 1
  grep -Fqx "$heading" "$dst_file"
}

append_to_archive() {
  local src_file="$1"
  local dst_file="$2"
  local heading="$3"

  mkdir -p "$(dirname "$dst_file")" || return 1
  if archive_has_range "$dst_file" "$heading"; then
    printf '归档已存在相同版本范围，跳过追加：%s
' "$heading"
    return 0
  fi
  if [[ -f "$dst_file" && -s "$dst_file" ]]; then
    {
      printf '

---

'
      cat "$src_file"
    } >> "$dst_file" || return 1
  else
    cat "$src_file" > "$dst_file" || return 1
  fi
  return 0
}

send_to_feishu() {
  local module_name="$1"
  local final_file="$2"

  [[ -n "${FEISHU_WEBHOOK_URL:-}" ]] || return 0
  [[ -f "$FEISHU_SENDER" ]] || fail "未找到飞书发送脚本：$FEISHU_SENDER"

  python3 "$FEISHU_SENDER" \
    --module "$module_name" \
    --file "$final_file"
}

modules=()
single_module=""

authoring_note
load_runtime_config

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --module)
      [[ $# -ge 2 ]] || fail "--module 缺少参数"
      single_module="$2"
      shift 2
      ;;
    *)
      fail "未知参数：$1（可用 --help 查看帮助）"
      ;;
  esac
done

if [[ -n "$single_module" ]]; then
  modules=("$single_module")
else
  read_modules "$MODULES_CONF"
fi

[[ "${#modules[@]}" -gt 0 ]] || fail "没有可处理的模块。"
check_codex_requirements

failed_count=0
for module_name in "${modules[@]}"; do
  repo_dir="$REPO_BASE/$module_name"
  raw_tmp_file="/tmp/release_notes_${module_name}.raw.md"
  final_tmp_file="/tmp/release_notes_${module_name}.md"
  archive_file="$ARCHIVE_DIR/release_notes_${module_name}.md"

  if ! git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    warn "跳过模块 $module_name：仓库不可用（$repo_dir）"
    failed_count=$((failed_count + 1))
    continue
  fi

  old_ref=""
  new_ref=""
  target_ref=""
  if ! resolve_default_range "$repo_dir"; then
    warn "跳过模块 $module_name：无法推断版本范围（检查本地 $DEFAULT_REMOTE 引用与 tag，规则 TAG_GLOB=$TAG_GLOB）"
    failed_count=$((failed_count + 1))
    continue
  fi

  range="${old_ref}..${new_ref}"
  raw_report=""
  if ! build_raw_payload "$repo_dir" "$range"; then
    warn "跳过模块 $module_name：版本范围内没有提交（$range）"
    failed_count=$((failed_count + 1))
    continue
  fi

  printf '%s' "$raw_report" > "$raw_tmp_file"
  if ! run_codex "$repo_dir" "$raw_tmp_file" "$final_tmp_file"; then
    warn "模块 $module_name：Codex 生成失败"
    failed_count=$((failed_count + 1))
    continue
  fi

  summary_heading="## 版本变更摘要（$old_ref → $new_ref）"
  if ! append_to_archive "$final_tmp_file" "$archive_file" "$summary_heading"; then
    warn "模块 $module_name：追加到归档失败（$archive_file）"
    failed_count=$((failed_count + 1))
    continue
  fi

  if ! send_to_feishu "$module_name" "$final_tmp_file"; then
    warn "模块 $module_name：飞书推送失败"
    failed_count=$((failed_count + 1))
    continue
  fi

  if [[ "$KEEP_RAW_INPUT" != "true" ]]; then
    rm -f "$raw_tmp_file"
  fi
  printf '模块 %s 已生成：%s，并已处理归档：%s
' "$module_name" "$final_tmp_file" "$archive_file"
done

if [[ "$failed_count" -gt 0 ]]; then
  fail "完成但有失败模块数量：$failed_count"
fi

printf '全部模块处理完成。
'
