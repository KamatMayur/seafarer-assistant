"""Tester feedback ('Report a problem'), crash reports, and the privacy notice."""

from __future__ import annotations

import html
import re
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Literal

from fastapi import APIRouter, HTTPException
from fastapi.responses import HTMLResponse
from pydantic import BaseModel, Field
from sqlalchemy import func, select

from sa_backend.api.deps import DB, CurrentUser
from sa_backend.db.models import UserFeedback
from sa_backend.settings import get_settings

router = APIRouter()
MAX_PER_DAY = 30  # problem reports + crash reports per user per day
PRIVACY_VERSION = "test-1"
_NOTICE = Path(__file__).resolve().parents[1] / "legal" / "privacy_notice.md"


class FeedbackIn(BaseModel):
    kind: Literal["problem", "idea", "crash"]
    message: str = Field(min_length=1, max_length=8000)
    app_version: str | None = Field(default=None, max_length=40)
    platform: str | None = Field(default=None, max_length=40)
    context: dict = Field(default_factory=dict)


@router.post("/v1/feedback", status_code=201, tags=["feedback"])
def send_feedback(body: FeedbackIn, user: CurrentUser, db: DB) -> dict:
    today = db.scalar(
        select(func.count())
        .select_from(UserFeedback)
        .where(UserFeedback.user_id == user.id, UserFeedback.created_at > datetime.now(UTC) - timedelta(days=1))
    )
    if today >= MAX_PER_DAY:
        raise HTTPException(429, "too many reports today; thank you, we have enough to look at")
    ctx = {k: str(v)[:500] for k, v in list(body.context.items())[:20]}  # bounded, strings only
    db.add(
        UserFeedback(
            user_id=user.id,
            kind=body.kind,
            message=body.message,
            app_version=body.app_version,
            platform=body.platform,
            context=ctx,
        )
    )
    return {"status": "received"}


def privacy_markdown() -> str:
    s = get_settings()
    return (
        _NOTICE.read_text(encoding="utf-8")
        .replace("{version}", PRIVACY_VERSION)
        .replace("{operator}", s.operator_name or "[operator name not set]")
        .replace("{contact}", s.privacy_contact or "[contact email not set]")
        .replace("{hosting}", s.hosting_description)
    )


@router.get("/v1/legal/privacy", tags=["meta"])
def privacy_json() -> dict:
    return {"version": PRIVACY_VERSION, "markdown": privacy_markdown()}


def _md_to_html(md: str) -> str:
    """Tiny renderer for the notice's own Markdown (headings, lists, tables, bold, italics). Escapes everything."""
    out, in_list, in_table = [], False, False

    def inline(t: str) -> str:
        t = html.escape(t)
        t = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", t)
        return re.sub(r"\*(.+?)\*", r"<em>\1</em>", t)

    for line in md.splitlines():
        if in_list and not line.startswith("- "):
            out.append("</ul>")
            in_list = False
        if in_table and not line.startswith("|"):
            out.append("</table>")
            in_table = False
        if line.startswith("# "):
            out.append(f"<h1>{inline(line[2:])}</h1>")
        elif line.startswith("## "):
            out.append(f"<h2>{inline(line[3:])}</h2>")
        elif line.startswith("- "):
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append(f"<li>{inline(line[2:])}</li>")
        elif line.startswith("|"):
            cells = [c.strip() for c in line.strip("|").split("|")]
            if all(set(c) <= {"-", ":"} for c in cells):
                continue
            tag = "th" if not in_table else "td"
            if not in_table:
                out.append("<table>")
                in_table = True
            out.append("<tr>" + "".join(f"<{tag}>{inline(c)}</{tag}>" for c in cells) + "</tr>")
        elif line.strip():
            out.append(f"<p>{inline(line)}</p>")
    if in_list:
        out.append("</ul>")
    if in_table:
        out.append("</table>")
    return "\n".join(out)


@router.get("/privacy", response_class=HTMLResponse, include_in_schema=False)
def privacy_page() -> HTMLResponse:
    body = _md_to_html(privacy_markdown())
    return HTMLResponse(
        "<!doctype html><html lang='en'><head><meta charset='utf-8'><meta name='viewport' "
        "content='width=device-width,initial-scale=1'><title>Privacy notice – Seafarer Assistant</title><style>"
        "body{font:16px/1.55 system-ui,sans-serif;max-width:760px;margin:2rem auto;padding:0 16px;color:#1d1d1b}"
        "table{border-collapse:collapse;width:100%}td,th{border:1px solid #ddd;padding:6px;text-align:left;"
        "vertical-align:top}@media(prefers-color-scheme:dark){body{background:#151614;color:#e8e8e3}"
        "td,th{border-color:#444}}</style></head><body>" + body + "</body></html>"
    )
