#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE_DEFAULT="${SCRIPT_DIR}/.env"
BACKUP_CONF_DEFAULT="${SCRIPT_DIR}/backup.conf"
BACKUP_DIR_DEFAULT="/opt/backup"
LOG_FILE_DEFAULT="/opt/logs/mysql-backup.log"
LOG_MAX_SIZE_BYTES=$((1024 * 1024))
SERVICE_NAME="${SERVICE_NAME:-mysql}"

usage() {
  cat <<'EOF'
Usage:
  ./mysql-backup.sh

Environment variables:
  ENV_FILE       Path to the MySQL .env file
  BACKUP_CONF    Path to the backup database list config
  BACKUP_DIR     Backup output directory
  LOG_FILE       Backup log file path
  SERVICE_NAME   Docker Compose service name, default: mysql
EOF
}

error() {
  echo "ERROR: $*" >&2
}

read_env_var() {
  local env_file="$1"
  local key="$2"
  local value=""

  value="$(
    awk -v k="${key}" '
      /^[[:space:]]*#/ { next }
      /^[[:space:]]*$/ { next }
      {
        line = $0
        split(line, parts, "=")
        raw_key = parts[1]
        sub(/^[[:space:]]*export[[:space:]]+/, "", raw_key)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", raw_key)
        if (raw_key == k) {
          sub(/^[^=]*=/, "", line)
          val = line
        }
      }
      END {
        if (val == "") exit 1
        print val
      }
    ' "${env_file}"
  )" || return 1

  value="$(printf '%s' "${value}" | sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  if [ "${#value}" -ge 2 ]; then
    if [ "${value:0:1}" = "\"" ] && [ "${value: -1}" = "\"" ]; then
      value="${value:1:${#value}-2}"
    elif [ "${value:0:1}" = "'" ] && [ "${value: -1}" = "'" ]; then
      value="${value:1:${#value}-2}"
    fi
  fi

  printf '%s\n' "${value}"
}

require_commands() {
  local cmd=""
  for cmd in docker gzip date stat mkdir; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      error "Required command not found: ${cmd}"
      exit 1
    fi
  done

  if ! docker compose version >/dev/null 2>&1; then
    error "docker compose is not available."
    exit 1
  fi
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

on_exit() {
  local exit_code=$?
  if [ "${exit_code}" -eq 0 ]; then
    log "Script finished"
  else
    log "Script finished with error code: ${exit_code}"
  fi
}

prepare_log_file() {
  local log_file="$1"
  local log_dir=""
  local size=0

  log_dir="$(dirname "${log_file}")"
  mkdir -p "${log_dir}"

  if [ -f "${log_file}" ]; then
    size="$(stat -c '%s' "${log_file}")"
    if [ "${size}" -gt "${LOG_MAX_SIZE_BYTES}" ]; then
      : > "${log_file}"
    fi
  fi
}

load_env() {
  local env_file="$1"

  if [ ! -f "${env_file}" ]; then
    error ".env not found: ${env_file}"
    exit 1
  fi

  MYSQL_USER="$(read_env_var "${env_file}" "MYSQL_USER")" || {
    error "MYSQL_USER is required in ${env_file}"
    exit 1
  }
  MYSQL_PASSWORD="$(read_env_var "${env_file}" "MYSQL_PASSWORD")" || {
    error "MYSQL_PASSWORD is required in ${env_file}"
    exit 1
  }
}

load_backup_databases() {
  local conf_file="$1"

  if [ ! -f "${conf_file}" ]; then
    error "Backup config not found: ${conf_file}"
    error "Create it from template first: cp ${BACKUP_CONF_DEFAULT}.template ${conf_file}"
    exit 1
  fi

  mapfile -t BACKUP_DATABASES < <(
    sed -e 's/\r$//' "${conf_file}" \
      | awk '
          /^[[:space:]]*#/ { next }
          /^[[:space:]]*$/ { next }
          {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
            print
          }
        '
  )

  if [ "${#BACKUP_DATABASES[@]}" -eq 0 ]; then
    error "No databases configured in ${conf_file}"
    exit 1
  fi
}

container_running() {
  local cid=""
  cid="$(docker compose ps -q "${SERVICE_NAME}" 2>/dev/null || true)"
  if [ -z "${cid}" ]; then
    return 1
  fi

  [ "$(docker inspect -f '{{.State.Running}}' "${cid}" 2>/dev/null || true)" = "true" ]
}

sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

database_exists() {
  local database_name="$1"
  local escaped_database_name=""

  escaped_database_name="$(sql_escape "${database_name}")"

  docker compose exec -T "${SERVICE_NAME}" env MYSQL_PWD="${MYSQL_PASSWORD}" \
    mysql -u "${MYSQL_USER}" --batch --skip-column-names \
    -e "SELECT 1 FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='${escaped_database_name}' LIMIT 1;" \
    | tr -d '[:space:]'
}

backup_database() {
  local database_name="$1"
  local backup_dir="$2"
  local timestamp="$3"
  local output_file="${backup_dir}/${database_name}-${timestamp}.sql.gz"

  log "Start backup database: ${database_name}"
  docker compose exec -T "${SERVICE_NAME}" env MYSQL_PWD="${MYSQL_PASSWORD}" \
    mysqldump -u "${MYSQL_USER}" \
      --single-transaction \
      --no-tablespaces \
      --routines \
      --triggers \
      --events \
      --databases "${database_name}" \
    | gzip > "${output_file}"

  log "Backup created: ${output_file}"
}

main() {
  local env_file="${ENV_FILE:-${ENV_FILE_DEFAULT}}"
  local backup_conf="${BACKUP_CONF:-${BACKUP_CONF_DEFAULT}}"
  local backup_dir="${BACKUP_DIR:-${BACKUP_DIR_DEFAULT}}"
  local log_file="${LOG_FILE:-${LOG_FILE_DEFAULT}}"
  local timestamp=""
  local database_name=""
  local exists=""

  if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
  fi

  cd "${SCRIPT_DIR}"

  prepare_log_file "${log_file}"
  exec >>"${log_file}" 2>&1
  trap on_exit EXIT
  log "Script started"
  require_commands
  load_env "${env_file}"
  load_backup_databases "${backup_conf}"

  mkdir -p "${backup_dir}"

  if ! container_running; then
    error "MySQL container is not running."
    exit 1
  fi

  timestamp="$(date '+%Y%m%d-%H%M%S')"

  for database_name in "${BACKUP_DATABASES[@]}"; do
    exists="$(database_exists "${database_name}")"
    if [ "${exists}" != "1" ]; then
      log "Database not found, skip: ${database_name}"
      continue
    fi

    backup_database "${database_name}" "${backup_dir}" "${timestamp}"
  done
}

main "$@"
