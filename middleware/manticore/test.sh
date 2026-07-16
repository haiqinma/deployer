#!/usr/bin/env bash

set -euo pipefail

if [[ -f .env ]]; then
  # shellcheck disable=SC1091
  source .env
fi

HTTP_PORT="${MANTICORE_HTTP_PORT:-9308}"
BASE_URL="http://127.0.0.1:${HTTP_PORT}"
TABLE_NAME="quickstart_test"

echo "Checking Manticore HTTP endpoint at ${BASE_URL} ..."
curl -fsS "${BASE_URL}/cli" -d "SHOW TABLES" >/dev/null

echo "Creating test table ${TABLE_NAME} ..."
curl -fsS "${BASE_URL}/sql" \
  -d "mode=raw&query=CREATE TABLE IF NOT EXISTS ${TABLE_NAME} (title text, content text, gid int)" >/dev/null

echo "Inserting one document ..."
curl -fsS "${BASE_URL}/json/insert" \
  -H "Content-Type: application/json" \
  -d "{\"index\":\"${TABLE_NAME}\",\"id\":1,\"doc\":{\"title\":\"hello\",\"content\":\"manticore\",\"gid\":1}}" >/dev/null

echo "Running search ..."
curl -fsS "${BASE_URL}/json/search" \
  -H "Content-Type: application/json" \
  -d "{\"index\":\"${TABLE_NAME}\",\"query\":{\"match\":{\"*\":\"hello\"}}}"

echo
echo "Manticore is working."
