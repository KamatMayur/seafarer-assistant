"""FastAPI application. Run: uvicorn sa_backend.api.app:app --reload"""

from __future__ import annotations

import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles

from sa_backend import reference
from sa_backend.admin import auth as admin_auth
from sa_backend.admin import routes as admin_routes
from sa_backend.api import routes_auth, routes_documents, routes_feedback, routes_me, routes_misc, routes_sync
from sa_backend.db.session import session_scope
from sa_backend.services.admin_events import raise_event
from sa_backend.settings import get_settings

log = logging.getLogger(__name__)


def create_app() -> FastAPI:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    app = FastAPI(
        title="Seafarer Compliance Assistant API",
        version="0.1.0",
        description=reference.UNOFFICIAL,
    )
    app.add_middleware(GZipMiddleware, minimum_size=800)  # slow ship internet
    if get_settings().cors_origins:
        app.add_middleware(
            CORSMiddleware, allow_origins=get_settings().cors_origins, allow_methods=["*"], allow_headers=["*"]
        )
    for r in (routes_auth.router, routes_me.router, routes_documents.router, routes_sync.router):
        app.include_router(r, prefix="/v1")
    app.include_router(routes_misc.router)
    app.include_router(routes_feedback.router)

    app.include_router(admin_routes.router)
    app.mount("/admin/static", StaticFiles(directory=admin_routes.HERE / "static"), name="admin-static")

    @app.exception_handler(admin_auth.LoginRequired)
    def _to_login(request: Request, exc: admin_auth.LoginRequired) -> RedirectResponse:
        return RedirectResponse("/admin/login", status_code=303)

    @app.exception_handler(Exception)
    def _unexpected(request: Request, exc: Exception) -> JSONResponse:
        # Logged with the stack; the admin sees it on the dashboard (once per 12 h per error type and path).
        log.exception("unhandled error on %s %s", request.method, request.url.path)
        try:
            with session_scope() as s:
                raise_event(
                    s,
                    "error",
                    f"API error {type(exc).__name__} on {request.method} {request.url.path}: {str(exc)[:300]}",
                )
        except Exception:  # the database itself may be the problem
            log.exception("could not record admin event")
        return JSONResponse({"detail": "Something went wrong on the server. It has been reported."}, status_code=500)

    return app


app = create_app()
