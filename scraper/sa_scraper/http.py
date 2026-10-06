"""Polite HTTP client: identifies itself, honours robots.txt, keeps >= N seconds between requests to a host,
retries transient failures with backoff, and caps download size."""

from __future__ import annotations

import logging
import time
import urllib.robotparser
from collections.abc import Callable
from dataclasses import dataclass
from urllib.parse import urlsplit

import httpx

log = logging.getLogger(__name__)

RETRY_STATUSES = {429, 500, 502, 503, 504}


class FetchError(Exception):
    def __init__(self, url: str, message: str, status: int | None = None):
        super().__init__(f"{url}: {message}")
        self.url = url
        self.status = status


class DisallowedByRobots(FetchError):
    pass


@dataclass
class FetchResult:
    url: str
    status: int
    content: bytes
    content_type: str


class PoliteClient:
    def __init__(
        self,
        user_agent: str,
        min_interval_s: float = 5.0,
        timeout_s: float = 60.0,
        max_bytes: int = 25 * 1024 * 1024,
        retries: int = 3,
        backoff_s: float = 5.0,
        transport: httpx.BaseTransport | None = None,
        sleep: Callable[[float], None] = time.sleep,
        clock: Callable[[], float] = time.monotonic,
    ):
        self.user_agent = user_agent
        self.min_interval_s = min_interval_s
        self.max_bytes = max_bytes
        self.retries = retries
        self.backoff_s = backoff_s
        self._sleep = sleep
        self._clock = clock
        self._last_request: dict[str, float] = {}
        self._robots: dict[str, urllib.robotparser.RobotFileParser] = {}
        self._client = httpx.Client(
            headers={"User-Agent": user_agent, "Accept-Language": "en-IN,en;q=0.8"},
            timeout=timeout_s,
            follow_redirects=True,
            transport=transport,
        )

    def close(self) -> None:
        self._client.close()

    def __enter__(self) -> PoliteClient:
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()

    # -- politeness -------------------------------------------------------------------------------
    def _wait_turn(self, host: str) -> None:
        last = self._last_request.get(host)
        if last is not None:
            remaining = self.min_interval_s - (self._clock() - last)
            if remaining > 0:
                self._sleep(remaining)
        self._last_request[host] = self._clock()

    def _allowed(self, url: str) -> bool:
        parts = urlsplit(url)
        host = parts.netloc
        if host not in self._robots:
            rp = urllib.robotparser.RobotFileParser()
            robots_url = f"{parts.scheme}://{host}/robots.txt"
            try:
                self._wait_turn(host)
                resp = self._client.get(robots_url)
                if resp.status_code >= 400:
                    rp.parse([])  # no robots.txt -> everything allowed
                else:
                    rp.parse(resp.text.splitlines())
            except httpx.HTTPError as e:
                log.warning("robots.txt unavailable for %s (%s); treating as allow-all", host, e)
                rp.parse([])
            self._robots[host] = rp
        return self._robots[host].can_fetch(self.user_agent, url)

    # -- public -----------------------------------------------------------------------------------
    def get(self, url: str) -> FetchResult:
        if not self._allowed(url):
            raise DisallowedByRobots(url, "disallowed by robots.txt")
        host = urlsplit(url).netloc
        last_error: FetchError | None = None
        for attempt in range(self.retries + 1):
            if attempt:
                self._sleep(self.backoff_s * (3 ** (attempt - 1)))
            self._wait_turn(host)
            try:
                with self._client.stream("GET", url) as resp:
                    declared = int(resp.headers.get("content-length") or 0)
                    if declared > self.max_bytes:
                        raise FetchError(url, f"too large ({declared} bytes)", resp.status_code)
                    chunks, size = [], 0
                    for chunk in resp.iter_bytes():
                        size += len(chunk)
                        if size > self.max_bytes:
                            raise FetchError(url, f"too large (> {self.max_bytes} bytes)", resp.status_code)
                        chunks.append(chunk)
                    if resp.status_code in RETRY_STATUSES:
                        last_error = FetchError(url, f"HTTP {resp.status_code}", resp.status_code)
                        continue
                    return FetchResult(
                        url=str(resp.url),
                        status=resp.status_code,
                        content=b"".join(chunks),
                        content_type=resp.headers.get("content-type", ""),
                    )
            except httpx.TransportError as e:
                last_error = FetchError(url, f"{type(e).__name__}: {e}")
        assert last_error is not None
        raise last_error
