#!/usr/bin/env bash
# Monitor root filesystem usage and send Feishu notifications when needed.

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1; pwd)
# shellcheck disable=SC1091
source "${script_dir}/../common/common.sh"
feishu_common_sh="${script_dir}/../feishu-notify/common.sh"
if [[ -f "$feishu_common_sh" ]]; then
    # shellcheck disable=SC1090
    source "$feishu_common_sh"
fi

init_log_file "monitor-host.log"

env_file="${script_dir}/.env"
feishu_scene="monitor_service"
notify_from=""
disk_usage_threshold=""
disk_monitor_enabled="False"
disk_usage_threshold_value=0
certbot_command="${CERTBOT_COMMAND:-/usr/local/bin/certbot}"
certificate_monitor_enabled="False"
certificate_expiry_threshold=0

if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
fi

notify_from="${NOTIFY_FROM:-}"
disk_usage_threshold="${DISK_USAGE_THRESHOLD:-}"
if [[ "$disk_usage_threshold" =~ ^[0-9]+$ ]]; then
    disk_usage_threshold_value=$((10#$disk_usage_threshold))
    if (( disk_usage_threshold_value > 0 && disk_usage_threshold_value < 100 )); then
        disk_monitor_enabled="True"
    else
        log "DISK_USAGE_THRESHOLD is outside (0, 100), skip disk usage check: ${disk_usage_threshold}"
    fi
elif [[ -n "$disk_usage_threshold" ]]; then
    log "DISK_USAGE_THRESHOLD is not a positive integer below 100, skip disk usage check: ${disk_usage_threshold}"
fi

ssl_valid_threshold="${SSL_VALID_THRESHOLD:-}"
if [[ "$ssl_valid_threshold" =~ ^[0-9]+$ ]]; then
    ssl_valid_threshold_value=$((10#$ssl_valid_threshold))
    if (( ssl_valid_threshold_value > 0 )); then
        certificate_expiry_threshold=$ssl_valid_threshold_value
        if (( certificate_expiry_threshold > 90 )); then
            certificate_expiry_threshold=90
        elif (( certificate_expiry_threshold < 3 )); then
            certificate_expiry_threshold=3
        fi
        certificate_monitor_enabled="True"
    else
        log "SSL_VALID_THRESHOLD is not positive, skip certificate expiry check: ${ssl_valid_threshold}"
    fi
elif [[ -n "$ssl_valid_threshold" ]]; then
    log "SSL_VALID_THRESHOLD is not a positive integer, skip certificate expiry check: ${ssl_valid_threshold}"
fi

if [[ -z "$notify_from" ]]; then
    notify_from=$(hostname)
fi

notify_feishu() {
    local message=$1

    if ! declare -F send_feishu_message >/dev/null 2>&1; then
        log "WARN! feishu notify helper is missing, skip notification"
        return 0
    fi

    if ! send_feishu_message "$feishu_scene" "$message" >> "$LOGFILE" 2>&1; then
        log "WARN! failed to send feishu notification"
    fi
}

format_disk_alert() {
    local filesystem=$1
    local size=$2
    local used=$3
    local available=$4
    local usage=$5

    cat <<EOF
【异常通知】主机磁盘空间告警

发现时间：$(date '+%Y-%m-%d %H:%M')
异常等级：P1
当前状态：已发现，待处理

异常现象：
- 根分区（/）使用率：${usage}%
- 告警阈值：${disk_usage_threshold_value}%
- 文件系统：${filesystem}
- 总容量：${size}
- 已用空间：${used}
- 可用空间：${available}

影响范围：
- 影响环境：${notify_from}
- 影响功能：可能导致日志写入、服务部署及业务运行失败

当前判断：
- 本地系统盘空间不足

下一步动作：
1. 登录 ${notify_from} 检查大文件和日志占用
2. 清理无用文件或扩容系统盘
EOF
}

format_certificate_alert() {
    local certificate_name=$1
    local days_remaining=$2

    cat <<EOF
【域名证书通知】域名证书续签提醒

发现时间：$(date '+%Y-%m-%d %H:%M')

通知内容：
- 域名信息：${certificate_name}
- 剩余有效期：${days_remaining} 天
- 域名节点：${notify_from}

建议操作：
1. 登录 ${notify_from} 执行/usr/local/bin/certbot renew --quiet 进行证书续签
EOF
}

check_certificate_expiry() {
    if [[ ! -x "$certbot_command" ]]; then
        log "certbot is not installed at ${certbot_command}, skip certificate expiry check"
        return 0
    fi

    local certificates_output
    if ! certificates_output=$("$certbot_command" certificates 2>&1); then
        log "WARN! failed to query certbot certificates: ${certificates_output}"
        return 0
    fi

    local certificate_records
    if ! certificate_records=$(printf '%s\n' "$certificates_output" | awk '
        /Certificate Name:/ {
            name = $0
            sub(/^.*Certificate Name:[[:space:]]*/, "", name)
            sub(/[[:space:]]*$/, "", name)
        }
        /VALID:/ {
            valid = $0
            sub(/^.*VALID:[[:space:]]*/, "", valid)
            sub(/[^0-9].*$/, "", valid)
            if (name != "" && valid ~ /^[0-9]+$/) {
                print name "\t" valid
                name = ""
            }
        }
    '); then
        log "WARN! failed to parse certbot certificate output"
        return 0
    fi

    if [[ -z "$certificate_records" ]]; then
        log "WARN! no certificate expiry records found in certbot output"
        return 0
    fi

    while IFS=$'\t' read -r certificate_name days_remaining; do
        [[ -n "$certificate_name" && "$days_remaining" =~ ^[0-9]+$ ]] || continue
        log "certificate ${certificate_name} has ${days_remaining} days remaining"
        if (( days_remaining < certificate_expiry_threshold )); then
            log "certificate ${certificate_name} is below the ${certificate_expiry_threshold}-day renewal threshold"
            notify_feishu "$(format_certificate_alert "$certificate_name" "$days_remaining")"
        fi
    done <<< "$certificate_records"
}

if [[ "$certificate_monitor_enabled" == "True" ]]; then
    check_certificate_expiry
else
    log "certificate expiry check is disabled"
fi

if [[ "$disk_monitor_enabled" != "True" ]]; then
    log "disk usage check is disabled"
    exit 0
fi

if ! df_output=$(df -hP / 2>&1); then
    log "ERROR! failed to query root filesystem usage: ${df_output}"
    exit 1
fi

root_line=$(printf '%s\n' "$df_output" | awk 'NR == 2 { print; exit }')
if [[ -z "$root_line" ]]; then
    log "ERROR! failed to parse root filesystem usage: ${df_output}"
    exit 1
fi

read -r root_filesystem root_size root_used root_available root_capacity root_mount <<< "$root_line"
root_usage="${root_capacity%\%}"

if ! [[ "$root_usage" =~ ^[0-9]+$ ]]; then
    log "ERROR! invalid root filesystem usage from df: ${root_line}"
    exit 1
fi

log "root filesystem usage: ${root_usage}% (threshold: ${disk_usage_threshold_value}%, filesystem: ${root_filesystem}, mount: ${root_mount})"

if (( root_usage <= disk_usage_threshold_value )); then
    log "root filesystem usage is below the alert threshold, no notification sent"
    exit 0
fi

log "root filesystem usage exceeds the alert threshold, sending notification"
message=$(format_disk_alert "$root_filesystem" "$root_size" "$root_used" "$root_available" "$root_usage")
notify_feishu "$message"

exit 0