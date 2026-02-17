from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """
    Application settings loaded from environment variables.
    Never hardcode credentials here - always use environment variables.
    """
    # Application settings
    app_name: str = "Vibe Coded Protected API"
    debug: bool = False
    
    # Database settings
    # Format: postgresql://user:password@host:port/database
    database_url: str
    
    # Server settings
    host: str = "0.0.0.0"
    port: int = 8000
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    """
    Get cached settings instance.
    This ensures we only read environment variables once.
    """
    return Settings()
