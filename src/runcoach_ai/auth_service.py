"""Password hashing and short-lived HS256 access tokens."""

import base64
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import json
import logging
import os
import secrets
from typing import Any


logger = logging.getLogger(__name__)
_TOKEN_SECRET = os.getenv("SECRET_KEY")
if not _TOKEN_SECRET:
    _APP_ENV = os.getenv("APP_ENV", os.getenv("ENVIRONMENT", "development")).lower()
    if _APP_ENV in {"prod", "production"}:
        raise RuntimeError("SECRET_KEY must be configured in production.")
    _TOKEN_SECRET = secrets.token_urlsafe(48)
    logger.warning("SECRET_KEY is not configured; access tokens expire on restart")

_PBKDF2_ITERATIONS = 310_000
_TOKEN_LIFETIME = timedelta(days=30)


def hash_password(password: str) -> str:
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt,
        _PBKDF2_ITERATIONS,
    )
    return "pbkdf2_sha256${}${}${}".format(
        _PBKDF2_ITERATIONS,
        _encode(salt),
        _encode(digest),
    )


def verify_password(password: str, encoded: str) -> bool:
    try:
        algorithm, iterations, salt, expected = encoded.split("$", maxsplit=3)
        if algorithm != "pbkdf2_sha256":
            return False
        digest = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            _decode(salt),
            int(iterations),
        )
    except (ValueError, TypeError):
        return False
    return hmac.compare_digest(_encode(digest), expected)


def create_access_token(user_id: str, email: str) -> str:
    now = datetime.now(timezone.utc)
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": user_id,
        "email": email,
        "iat": int(now.timestamp()),
        "exp": int((now + _TOKEN_LIFETIME).timestamp()),
    }
    signing_input = f"{_encode_json(header)}.{_encode_json(payload)}"
    signature = hmac.new(
        _TOKEN_SECRET.encode("utf-8"),
        signing_input.encode("ascii"),
        hashlib.sha256,
    ).digest()
    return f"{signing_input}.{_encode(signature)}"


def decode_access_token(token: str) -> dict[str, Any] | None:
    try:
        encoded_header, encoded_payload, encoded_signature = token.split(".")
        signing_input = f"{encoded_header}.{encoded_payload}"
        expected_signature = hmac.new(
            _TOKEN_SECRET.encode("utf-8"),
            signing_input.encode("ascii"),
            hashlib.sha256,
        ).digest()
        if not hmac.compare_digest(_decode(encoded_signature), expected_signature):
            return None
        header = json.loads(_decode(encoded_header))
        payload = json.loads(_decode(encoded_payload))
        if header != {"alg": "HS256", "typ": "JWT"}:
            return None
        if not isinstance(payload, dict) or int(payload["exp"]) <= int(
            datetime.now(timezone.utc).timestamp()
        ):
            return None
        if not isinstance(payload.get("sub"), str) or not isinstance(
            payload.get("email"), str
        ):
            return None
        return payload
    except (ValueError, TypeError, KeyError, json.JSONDecodeError):
        return None


def _encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _decode(value: str) -> bytes:
    return base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))


def _encode_json(value: dict[str, Any]) -> str:
    return _encode(json.dumps(value, separators=(",", ":"), sort_keys=True).encode())
