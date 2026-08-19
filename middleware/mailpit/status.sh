#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

web_port="${MAILPIT_WEB_PORT:-8025}"

docker compose ps
curl --fail --silent --show-error "http://127.0.0.1:${web_port}/livez"
echo
