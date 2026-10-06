"""FastAPI application. Run: uvicorn sa_backend.api.app:app --reload"""

from __future__ import annotations

import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

from sa_backend import reference
from sa_backend.api import routes_auth, routes_documents, routes_me, routes_misc, routes_sync
from sa_backend.settings import get_settings


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
    return app


app = create_app()
