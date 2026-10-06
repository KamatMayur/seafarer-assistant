"""Load scraper source definitions from YAML (scraper/sources/*.yaml)."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo

import yaml

IST = ZoneInfo("Asia/Kolkata")
DEFAULT_SOURCES_DIR = Path(__file__).resolve().parents[1] / "sources"


@dataclass(frozen=True)
class Layout:
    table: str
    columns: dict[str, list[str]]
    required: list[str]
    skip_row_if_cells_lt: int = 0
    date_format: str = "%d-%b-%Y"
    pagination: dict[str, Any] | None = None


@dataclass(frozen=True)
class SourceConfig:
    id: str
    url_template: str
    base_url: str
    layout: Layout
    poll_minutes: int = 180
    hints: dict[str, Any] = field(default_factory=dict)
    text_policy: str = "full"  # 'full' | 'metadata_only'
    enabled: bool = True

    def url(self, year: int | None = None) -> str:
        year = year or datetime.now(IST).year
        path = self.url_template.replace("{year}", str(year))
        return path if path.startswith("http") else self.base_url.rstrip("/") + path

    @property
    def is_yearly(self) -> bool:
        return "{year}" in self.url_template


def load_sources(directory: Path = DEFAULT_SOURCES_DIR) -> dict[str, SourceConfig]:
    out: dict[str, SourceConfig] = {}
    for path in sorted(directory.glob("*.yaml")):
        doc = yaml.safe_load(path.read_text(encoding="utf-8"))
        defaults = doc.get("defaults", {})
        layouts = {name: Layout(**spec) for name, spec in (doc.get("layouts") or {}).items()}
        for raw in doc.get("sources", []):
            merged = {**defaults, **raw}
            layout_name = merged.get("layout")
            if layout_name not in layouts:
                raise ValueError(f"{path.name}: source {raw.get('id')} uses unknown layout {layout_name!r}")
            if merged["id"] in out:
                raise ValueError(f"duplicate source id {merged['id']!r}")
            out[merged["id"]] = SourceConfig(
                id=merged["id"],
                url_template=merged["url"],
                base_url=merged.get("base_url", ""),
                layout=layouts[layout_name],
                poll_minutes=int(merged.get("poll_minutes", 180)),
                hints=merged.get("hints") or {},
                text_policy=merged.get("text_policy", "full"),
                enabled=bool(merged.get("enabled", True)),
            )
    return out
