"""All configuration comes from environment variables (prefix SA_) or a local .env file. No secrets in code."""

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

REPO_ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="SA_", env_file=(REPO_ROOT / ".env", ".env"), extra="ignore")

    env: str = "dev"
    database_url: str = "postgresql+psycopg://postgres@127.0.0.1:5432/seafarer"
    data_dir: Path = Path("data")  # PDF cache, local state

    # Scraper politeness
    scraper_user_agent: str = "SeafarerAssistantBot/0.1 (+set SA_SCRAPER_CONTACT)"
    scraper_contact: str = ""
    scraper_min_interval_s: float = 5.0
    scraper_timeout_s: float = 60.0
    scraper_max_pdf_mb: float = 25.0

    # Auth
    jwt_secret: str = "dev-only-change-me"
    admin_token: str = ""  # bearer token for /v1/admin/* until the admin UI with TOTP lands (Phase 3)
    cors_origins: list[str] = []
    access_token_minutes: int = 30
    refresh_token_days: int = 60
    login_code_minutes: int = 15

    # Outbound channels (all optional; unset = channel disabled)
    smtp_host: str = ""
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = ""
    admin_alert_email: str = ""
    admin_alert_slack_webhook: str = ""
    fcm_credentials_file: str = ""

    # Optional LLM upgrade (decision D12). Empty = rules/extractive pipeline only.
    anthropic_api_key: str = ""

    @property
    def user_agent(self) -> str:
        if self.scraper_contact:
            return f"SeafarerAssistantBot/0.1 (+contact: {self.scraper_contact})"
        return self.scraper_user_agent


@lru_cache
def get_settings() -> Settings:
    return Settings()
