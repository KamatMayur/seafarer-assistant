"""Manage admin accounts.

    python -m sa_backend.admin.manage create EMAIL [--role owner|editor]   (asks for a password, prints TOTP setup)
    python -m sa_backend.admin.manage list
    python -m sa_backend.admin.manage disable EMAIL | enable EMAIL
    python -m sa_backend.admin.manage reset-password EMAIL
    python -m sa_backend.admin.manage reset-totp EMAIL                    (new authenticator secret)

The password can also be passed in SA_NEW_ADMIN_PASSWORD (for scripts). Every change is audit-logged.
"""

from __future__ import annotations

import argparse
import getpass
import os
import sys
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.orm import Session

from sa_backend.admin import auth
from sa_backend.db.models import AdminAccount, AdminAuditLog
from sa_backend.db.session import session_scope


class ManageError(Exception):
    pass


def _password(email: str) -> str:
    pw = os.environ.get("SA_NEW_ADMIN_PASSWORD")
    if pw is None:
        pw = getpass.getpass(f"Password for {email} (min {auth.MIN_PASSWORD} chars): ")
        if getpass.getpass("Repeat: ") != pw:
            raise ManageError("passwords do not match")
    if len(pw) < auth.MIN_PASSWORD:
        raise ManageError(f"password must be at least {auth.MIN_PASSWORD} characters")
    return pw


def _get(db: Session, email: str) -> AdminAccount:
    acct = auth.find_account(db, email)
    if acct is None:
        raise ManageError(f"no admin account {email}")
    return acct


def _audit(db: Session, action: str, email: str) -> None:
    db.add(AdminAuditLog(admin="cli", action=action, target=email.lower()))


def create(db: Session, email: str, password: str, role: str = "editor") -> tuple[AdminAccount, str]:
    """Returns the account and its TOTP secret (shown once)."""
    if role not in ("owner", "editor"):
        raise ManageError("role must be owner or editor")
    if auth.find_account(db, email):
        raise ManageError(f"{email} already exists")
    secret = auth.new_totp_secret()
    acct = AdminAccount(
        email=email.strip().lower(),
        role=role,
        password_hash=auth.hash_password(password),
        totp_secret_enc=auth.encrypt_secret(secret),
    )
    db.add(acct)
    _audit(db, "admin.create", email)
    return acct, secret


def reset_totp(db: Session, email: str) -> str:
    acct = _get(db, email)
    secret = auth.new_totp_secret()
    acct.totp_secret_enc = auth.encrypt_secret(secret)
    acct.totp_last_step = 0
    _audit(db, "admin.reset_totp", email)
    return secret


def _print_totp(email: str, secret: str) -> None:
    print("\nAdd this account to an authenticator app (Google Authenticator, Microsoft Authenticator, Aegis...):")
    print(f"  Secret key : {secret}")
    print(f"  Or open    : {auth.provisioning_uri(email, secret)}")
    print("The secret is shown only once. Log in at /admin with email + password + the 6-digit code.\n")


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="python -m sa_backend.admin.manage")
    sub = p.add_subparsers(dest="cmd", required=True)
    c = sub.add_parser("create")
    c.add_argument("email")
    c.add_argument("--role", default="editor", choices=["owner", "editor"])
    sub.add_parser("list")
    for name in ("disable", "enable", "reset-password", "reset-totp"):
        sub.add_parser(name).add_argument("email")
    args = p.parse_args(argv)

    try:
        with session_scope() as db:
            if args.cmd == "create":
                acct, secret = create(db, args.email, _password(args.email), args.role)
                print(f"Created {acct.role} {acct.email}")
                _print_totp(acct.email, secret)
            elif args.cmd == "list":
                for a in db.scalars(select(AdminAccount).order_by(AdminAccount.email)):
                    state = "disabled" if a.disabled_at else "active"
                    last = f"{a.last_login_at:%Y-%m-%d %H:%M}" if a.last_login_at else "never"
                    print(f"{a.email:40} {a.role:7} {state:9} last login {last}")
            elif args.cmd == "disable":
                _get(db, args.email).disabled_at = datetime.now(UTC)
                _audit(db, "admin.disable", args.email)
                print(f"Disabled {args.email} (their sessions end now)")
            elif args.cmd == "enable":
                acct = _get(db, args.email)
                acct.disabled_at, acct.locked_until, acct.failed_attempts = None, None, 0
                _audit(db, "admin.enable", args.email)
                print(f"Enabled {args.email}")
            elif args.cmd == "reset-password":
                acct = _get(db, args.email)
                acct.password_hash = auth.hash_password(_password(args.email))
                acct.locked_until, acct.failed_attempts = None, 0
                _audit(db, "admin.reset_password", args.email)
                print(f"Password changed for {args.email} (their sessions end now)")
            elif args.cmd == "reset-totp":
                secret = reset_totp(db, args.email)
                _print_totp(args.email, secret)
    except ManageError as e:
        print(f"error: {e}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
