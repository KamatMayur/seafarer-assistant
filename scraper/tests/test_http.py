import httpx
import pytest

from sa_scraper.http import DisallowedByRobots, FetchError, PoliteClient


class FakeClock:
    def __init__(self):
        self.t = 1000.0
        self.slept: list[float] = []

    def now(self) -> float:
        return self.t

    def sleep(self, s: float) -> None:
        self.slept.append(round(s, 2))
        self.t += s


def make(handler, clock, **kw):
    return PoliteClient("TestBot/1.0", transport=httpx.MockTransport(handler), sleep=clock.sleep, clock=clock.now, **kw)


def test_waits_between_requests_to_same_host():
    clock = FakeClock()

    def handler(req):
        return httpx.Response(200, text="User-agent: *\nDisallow:" if req.url.path == "/robots.txt" else "ok")

    with make(handler, clock, min_interval_s=5) as c:
        c.get("https://dgma.gov.in/a")
        c.get("https://dgma.gov.in/b")
    assert clock.slept == [5.0, 5.0]  # robots -> a, a -> b


def test_robots_disallow_is_honoured():
    clock = FakeClock()

    def handler(req):
        if req.url.path == "/robots.txt":
            return httpx.Response(200, text="User-agent: *\nDisallow: /private")
        return httpx.Response(200, text="ok")

    with make(handler, clock, min_interval_s=0) as c, pytest.raises(DisallowedByRobots):
        c.get("https://dgma.gov.in/private/x")


def test_retries_transient_errors_with_backoff():
    clock = FakeClock()
    calls = {"n": 0}

    def handler(req):
        if req.url.path == "/robots.txt":
            return httpx.Response(404)
        calls["n"] += 1
        return httpx.Response(503) if calls["n"] < 3 else httpx.Response(200, text="ok")

    with make(handler, clock, min_interval_s=0, backoff_s=5) as c:
        assert c.get("https://dgma.gov.in/x").status == 200
    assert calls["n"] == 3
    assert 5.0 in clock.slept and 15.0 in clock.slept


def test_gives_up_after_retries():
    clock = FakeClock()

    def handler(req):
        return httpx.Response(404) if req.url.path == "/robots.txt" else httpx.Response(502)

    with make(handler, clock, min_interval_s=0, retries=2) as c, pytest.raises(FetchError):
        c.get("https://dgma.gov.in/x")


def test_size_cap():
    clock = FakeClock()

    def handler(req):
        return httpx.Response(404) if req.url.path == "/robots.txt" else httpx.Response(200, content=b"x" * 2000)

    with make(handler, clock, min_interval_s=0, max_bytes=1000) as c, pytest.raises(FetchError, match="too large"):
        c.get("https://dgma.gov.in/big.pdf")
