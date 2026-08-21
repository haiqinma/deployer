#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required but was not found." >&2
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 is required but was not found." >&2
  exit 1
fi

docker compose up -d

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

smtp_port="${MAILPIT_SMTP_PORT:-1025}"
web_port="${MAILPIT_WEB_PORT:-8025}"

echo
echo "Mailpit Web:  http://127.0.0.1:${web_port}"
echo "SMTP server:  127.0.0.1:${smtp_port}"
docker compose ps
