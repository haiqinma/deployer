#!/usr/bin/env bash
# Upload existing PostgreSQL database backup files from /opt/backup.

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1; pwd)
project_root=$(cd "${script_dir}/.." || exit 1; pwd)
backup_conf="${script_dir}/backup.conf"
backup_env_file="${script_dir}/.env"
common_env_file="${project_root}/common/.env"
transfer_file_script="${project_root}/common/transfer_file.sh"
feishu_common_sh="${project_root}/feishu-notify/common.sh"

# shellcheck disable=SC1091
source "${project_root}/common/common.sh"

if [[ -f "$feishu_common_sh" ]]; then
    # shellcheck disable=SC1090
    source "$feishu_common_sh"
fi

MODULES=()
backup_dir="${BACKUP_DIR:-/opt/backup}"
feishu_scene="backup_database"
notify_from="${NOTIFY_FROM:-}"

usage() {
    cat <<EOF
Usage:
  $0
  $0 upload
  $0 download <local_directory>
Notes:
  - module list is read from ${backup_conf}
  - backup files are read from ${backup_dir}
  - backup file format follows ../middleware/postgresql/database-backup.sh:
    <module>-YYYYMMDD-HHMMSS.sql.gz
  - when multiple files exist for a module, only the latest file is uploaded
  - WebDAV config is read from ${backup_env_file}, then falls back to ${common_env_file}
  - download checks that the local directory exists
EOF
}

notify_feishu() {
    local message=$1

    if ! declare -F send_feishu_message >/dev/null 2>&1; then
        log "WARN! feishu notify helper is missing, skip notification: ${message}"
        return 0
    fi

    if ! send_feishu_message "$feishu_scene" "$message" >> "$LOGFILE" 2>&1; then
        log "WARN! failed to send feishu notification: ${message}"
    fi
}

load_backup_modules() {
    load_modules "$backup_conf"
}

prepare_webdav_env() {
    local tmp_env=$1

    if [[ -f "$backup_env_file" ]]; then
        cp -f "$backup_env_file" "$tmp_env"
        log "use WebDAV file config from ${backup_env_file}"
        return 0
    fi

    if [[ ! -f "$common_env_file" ]]; then
        log "ERROR! env file is missing: ${backup_env_file} or ${common_env_file}"
        return 1
    fi

    cp -f "$common_env_file" "$tmp_env"
    log "use WebDAV file config from ${common_env_file}"
}

find_latest_backup_file() {
    local module_name=$1
    local latest_file

    latest_file=$(
        find "$backup_dir" -maxdepth 1 -type f -name "${module_name}-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9].sql.gz" -printf '%f %p\n' 2>/dev/null \
            | sort -r \
            | awk 'NR == 1 { sub(/^[^ ]+ /, ""); print }'
    )

    [[ -n "$latest_file" ]] || return 1
    printf '%s' "$latest_file"
}

upload_backup_file() {
    local backup_file=$1
    local tmp_env tmp_dir upload_status

    tmp_dir=$(mktemp -d "/tmp/upload_database_backup_env.XXXXXX")
    tmp_env="${tmp_dir}/.env"

    if [[ ! -x "$transfer_file_script" ]]; then
        rm -rf "$tmp_dir"
        log "ERROR! transfer file script is missing or not executable: ${transfer_file_script}"
        return 1
    fi

    prepare_webdav_env "$tmp_env" || {
        rm -rf "$tmp_dir"
        return 1
    }

    upload_status=0
    WEBDAV_FILE_ENV_FILE="$tmp_env" bash "$transfer_file_script" upload "$backup_file" || upload_status=$?
    rm -rf "$tmp_dir"
    return "$upload_status"
}

download_backup_files() {
    local target_dir=$1
    local tmp_env tmp_dir download_status

    if [[ ! -d "$target_dir" ]]; then
        log "ERROR! local directory is missing: ${target_dir}"
        return 1
    fi

    tmp_dir=$(mktemp -d "/tmp/upload_database_backup_env.XXXXXX")
    tmp_env="${tmp_dir}/.env"

    if [[ ! -x "$transfer_file_script" ]]; then
        rm -rf "$tmp_dir"
        log "ERROR! transfer file script is missing or not executable: ${transfer_file_script}"
        return 1
    fi

    prepare_webdav_env "$tmp_env" || {
        rm -rf "$tmp_dir"
        return 1
    }

    download_status=0
    WEBDAV_FILE_ENV_FILE="$tmp_env" bash "$transfer_file_script" download "$target_dir" || download_status=$?
    rm -rf "$tmp_dir"
    return "$download_status"
}

main() {
    local operation module_name backup_file

    operation="${1:-upload}"

    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi

    init_log_file "upload-database-backup.log"

    if [[ "$operation" == "download" ]]; then
        if [[ $# -ne 2 ]]; then
            usage
            exit 1
        fi

        download_backup_files "$2" || exit 1
        exit 0
    fi

    if [[ "$operation" != "upload" || $# -gt 1 ]]; then
        usage
        exit 1
    fi

    if [[ -z "$notify_from" ]]; then
        notify_from=$(hostname)
    fi

    load_backup_modules || exit 1

    if [[ ! -d "$backup_dir" ]]; then
        log "ERROR! backup directory is missing: ${backup_dir}"
        exit 1
    fi

    for module_name in "${MODULES[@]}"; do
        if ! backup_file=$(find_latest_backup_file "$module_name"); then
            log "no database backup file found for module: ${module_name}"
            notify_feishu "${module_name}模块没有需要备份的数据库文件"
            continue
        fi

        log "upload latest database backup file for ${module_name}: ${backup_file}"
        if upload_backup_file "$backup_file"; then
            notify_feishu "${module_name}模块的数据库备份文件 ${backup_file} 上传成功"
        else
            notify_feishu "${module_name}模块的数据库备份文件 ${backup_file} 上传失败"
            exit 1
        fi
    done
}

main "$@"
