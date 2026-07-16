#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json
import os
import sys
from pathlib import Path

from aliyunsdkbssopenapi.request.v20171214.QueryAccountBalanceRequest import (
    QueryAccountBalanceRequest,
)
from aliyunsdkcore.acs_exception.exceptions import ClientException, ServerException
from aliyunsdkcore.client import AcsClient


ENV_FILE = Path(__file__).resolve().parent / ".env"


def load_env_file(env_path: Path) -> None:
    if not env_path.exists():
        return

    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()

        if (value.startswith('"') and value.endswith('"')) or (
            value.startswith("'") and value.endswith("'")
        ):
            value = value[1:-1]

        if not os.getenv(key):
            os.environ[key] = value


def get_account_balance() -> dict:
    access_key_id = os.getenv("ALIYUN_ACCESS_KEY_ID")
    access_key_secret = os.getenv("ALIYUN_ACCESS_KEY_SECRET")

    if not access_key_id or not access_key_secret:
        raise RuntimeError("missing ALIYUN_ACCESS_KEY_ID or ALIYUN_ACCESS_KEY_SECRET")

    client = AcsClient(access_key_id, access_key_secret, "cn-hangzhou")
    request = QueryAccountBalanceRequest()
    request.set_accept_format("json")

    response = client.do_action_with_exception(request)
    result = json.loads(response.decode("utf-8") if isinstance(response, bytes) else response)

    if not result.get("Success"):
        message = result.get("Message") or result.get("Code") or result
        raise RuntimeError(f"QueryAccountBalance failed: {message}")

    data = result.get("Data") or {}
    available_cash_amount = data.get("AvailableCashAmount")
    if available_cash_amount is None:
        raise RuntimeError(f"QueryAccountBalance response missing Data.AvailableCashAmount: {result}")

    return {
        "available_cash_amount": str(available_cash_amount),
        "currency": data.get("Currency", "CNY"),
        "request_id": result.get("RequestId", ""),
    }


def main() -> int:
    load_env_file(ENV_FILE)

    try:
        print(json.dumps(get_account_balance(), ensure_ascii=False))
        return 0
    except (ClientException, ServerException) as exc:
        error_code = getattr(exc, "get_error_code", lambda: "")()
        error_msg = getattr(exc, "get_error_msg", lambda: str(exc))()
        print(
            f"Aliyun API exception: ErrorCode={error_code}, Message={error_msg}",
            file=sys.stderr,
        )
        return 1
    except Exception as exc:
        print(f"Aliyun balance query failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
