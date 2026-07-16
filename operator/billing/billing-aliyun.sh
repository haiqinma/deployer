#!/usr/bin/env bash
# Query Aliyun account balance and notify when cash balance is below threshold.

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1; pwd)
project_root=$(cd "${script_dir}/.." || exit 1; pwd)
env_file="${script_dir}/.env"
python_script="${script_dir}/aliyun.py"
venv_dir="${script_dir}/venv"
requirements_file="${script_dir}/requirements.txt"
dingtalk_script="${project_root}/dingtalk-notify/dingtalk_reminder.py"
feishu_common_sh="${project_root}/feishu-notify/common.sh"
dingtalk_scene="${BILLING_ALIYUN_DINGTALK_SCENE:-monitor_service}"
feishu_scene="${BILLING_ALIYUN_FEISHU_SCENE:-monitor_service}"

# shellcheck disable=SC1091
source "${project_root}/common/common.sh"

if [[ -f "$feishu_common_sh" ]]; then
    # shellcheck disable=SC1090
    source "$feishu_common_sh"
fi

init_log_file "billing-aliyun.log"

usage() {
    log "Usage: $0"
    log "Query Aliyun balance with ${python_script}, using ${env_file} for AK/SK and threshold."
}

load_billing_env() {
    if [[ ! -f "$env_file" ]]; then
        log_err "ERROR! env file is missing: ${env_file}"
        return 1
    fi

    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a

    if [[ -z "${ALIYUN_ACCESS_KEY_ID:-}" || -z "${ALIYUN_ACCESS_KEY_SECRET:-}" ]]; then
        log_err "ERROR! set ALIYUN_ACCESS_KEY_ID and ALIYUN_ACCESS_KEY_SECRET in ${env_file}."
        return 1
    fi

    if [[ -z "${ALARM_CASHAMOUNT_ALIYUN:-}" ]]; then
        log_err "ERROR! set ALARM_CASHAMOUNT_ALIYUN in ${env_file}."
        return 1
    fi

    dingtalk_scene="${BILLING_ALIYUN_DINGTALK_SCENE:-$dingtalk_scene}"
    feishu_scene="${BILLING_ALIYUN_FEISHU_SCENE:-$feishu_scene}"
}

ensure_venv() {
    if [[ ! -x "${venv_dir}/bin/python" ]]; then
        log "create Python venv: ${venv_dir}"
        python3 -m venv "$venv_dir"
    fi

    if ! "${venv_dir}/bin/python" - <<'PY' >/dev/null 2>&1
from aliyunsdkbssopenapi.request.v20171214.QueryAccountBalanceRequest import QueryAccountBalanceRequest
from aliyunsdkcore.client import AcsClient
PY
    then
        if [[ ! -f "$requirements_file" ]]; then
            log_err "ERROR! Python dependencies are missing and ${requirements_file} does not exist."
            return 1
        fi

        log "install Python dependencies from ${requirements_file}"
        "${venv_dir}/bin/python" -m pip install -r "$requirements_file" >> "$LOGFILE" 2>&1
    fi
}

query_balance() {
    "${venv_dir}/bin/python" "$python_script"
}

json_field() {
    local json_payload=$1
    local field_name=$2

    "${venv_dir}/bin/python" - "$json_payload" "$field_name" <<'PY'
import json
import sys

payload = json.loads(sys.argv[1])
print(payload.get(sys.argv[2], ""))
PY
}

amount_lt() {
    local left=$1
    local right=$2

    "${venv_dir}/bin/python" - "$left" "$right" <<'PY'
from decimal import Decimal, InvalidOperation
import sys

try:
    print("true" if Decimal(sys.argv[1]) < Decimal(sys.argv[2]) else "false")
except InvalidOperation as exc:
    raise SystemExit(f"invalid decimal value: {exc}")
PY
}

notify_dingtalk() {
    local message=$1

    if [[ ! -f "$dingtalk_script" ]]; then
        log "WARN! dingtalk script is missing: ${dingtalk_script}"
        return 0
    fi

    if ! python3 "$dingtalk_script" "$dingtalk_scene" "True" "$message" >> "$LOGFILE" 2>&1; then
        log "WARN! failed to send dingtalk notification"
    fi
}

notify_feishu() {
    local message=$1

    if declare -F send_feishu_message >/dev/null 2>&1; then
        if ! send_feishu_message "$feishu_scene" "$message" >> "$LOGFILE" 2>&1; then
            log "WARN! failed to send feishu notification"
        fi
        return 0
    fi

    log "WARN! feishu notify helper is missing, skip notification"
}

notify_alarm() {
    local available_cash_amount=$1
    local alarm_time=$2
    local message

    message=$(cat <<EOF
[余额告警]
截至 ${alarm_time}，阿里云帐号余额为 ${available_cash_amount}元，请尽快评估是否需要充值
EOF
)

    notify_dingtalk "$message"
    notify_feishu "$message"
}

main() {
    local balance_json available_cash_amount currency request_id alarm_time is_alarm

    if [[ $# -ne 0 ]]; then
        usage
        exit 1
    fi

    load_billing_env
    ensure_venv

    log "begin query Aliyun account balance"
    if ! balance_json=$(query_balance 2>> "$LOGFILE"); then
        log_err "ERROR! failed to query Aliyun account balance"
        exit 1
    fi

    available_cash_amount=$(json_field "$balance_json" "available_cash_amount")
    currency=$(json_field "$balance_json" "currency")
    request_id=$(json_field "$balance_json" "request_id")
    log "Aliyun account balance: AvailableCashAmount=${available_cash_amount} ${currency}, RequestId=${request_id}"

    is_alarm=$(amount_lt "$available_cash_amount" "$ALARM_CASHAMOUNT_ALIYUN")
    if [[ "$is_alarm" == "true" ]]; then
        alarm_time=$(date '+%Y-%m-%d %H:%M:%S')
        log "AvailableCashAmount ${available_cash_amount} is below threshold ${ALARM_CASHAMOUNT_ALIYUN}; send notifications"
        notify_alarm "$available_cash_amount" "$alarm_time"
    else
        log "AvailableCashAmount ${available_cash_amount} is not below threshold ${ALARM_CASHAMOUNT_ALIYUN}; no notification"
    fi
}

main "$@"
