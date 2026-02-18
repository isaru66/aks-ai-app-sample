from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional
from pathlib import Path

# Root directory of the project (3 levels up from this file: backend/app/core/config.py -> root)
ROOT_DIR = Path(__file__).parent.parent.parent.parent
ENV_FILE = ROOT_DIR / ".env"


class Settings(BaseSettings):
    """Application settings with environment variable support."""
    
    model_config = SettingsConfigDict(
        env_file=str(ENV_FILE),
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore"  # Ignore extra fields from .env
    )
    
    # Application
    app_name: str = "Azure AI Chat App"
    environment: str = "dev"
    debug: bool = False
    api_version: str = "v1"
    
    # Server
    backend_host: str = "0.0.0.0"
    backend_port: int = 8000
    
    # CORS
    cors_origins: str = "http://localhost:3000,http://localhost:8000"
    
    @property
    def cors_origins_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",")]
    
    # Logging
    log_level: str = "INFO"
    
    # Azure Configuration
    azure_subscription_id: Optional[str] = None
    azure_tenant_id: Optional[str] = None
    azure_client_id: Optional[str] = None
    azure_client_secret: Optional[str] = None
    
    # Azure AI Foundry
    azure_ai_foundry_endpoint: Optional[str] = None
    azure_ai_foundry_project_id: Optional[str] = None
    azure_ai_foundry_api_key: Optional[str] = None
    
    # Azure OpenAI (GPT-5.2)
    azure_openai_endpoint: Optional[str] = None
    azure_openai_api_key: Optional[str] = None
    azure_openai_deployment_name: str = "gpt-5.2"
    azure_openai_model: str = "gpt-5.2"
    azure_openai_api_version: str = "2025-03-01-preview"
    azure_openai_embedding_deployment: str = "text-embedding-ada-002"
    # GPT-5-mini deployment (lighter/faster model)
    azure_openai_mini_deployment_name: str = "gpt-5-mini"
    azure_openai_mini_model: str = "gpt-5-mini"
    
    # Azure AI Search
    azure_search_endpoint: Optional[str] = None
    azure_search_api_key: Optional[str] = None
    azure_search_index_name: str = "documents"
    
    # PostgreSQL Configuration
    postgresql_host: Optional[str] = None
    postgresql_port: int = 5432
    postgresql_database: str = "chatdb"
    postgresql_user: Optional[str] = None
    postgresql_password: Optional[str] = None
    postgresql_ssl_mode: str = "require"
    
    @property
    def postgresql_url(self) -> str:
        """Build PostgreSQL connection URL."""
        if not self.postgresql_host or not self.postgresql_user:
            return ""
        
        return (
            f"postgresql://{self.postgresql_user}:{self.postgresql_password}"
            f"@{self.postgresql_host}:{self.postgresql_port}"
            f"/{self.postgresql_database}?sslmode={self.postgresql_ssl_mode}"
        )
    
    # Database Selection (PostgreSQL only)
    database_type: str = "postgresql"
    
    # Azure Storage
    azure_storage_account_name: Optional[str] = None
    azure_storage_account_key: Optional[str] = None
    azure_storage_container_name: str = "documents"
    
    # Azure Key Vault
    azure_key_vault_url: Optional[str] = None
    
    # Application Insights
    applicationinsights_connection_string: Optional[str] = None
    
    # Feature Flags
    enable_streaming: bool = True
    enable_thinking_process: bool = True
    enable_rag: bool = True
    enable_agents: bool = True
    
    # Authentication
    jwt_secret_key: str = "change-this-secret-key-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expiration_minutes: int = 60
    
    # GPT-5.2 Specific Settings
    gpt_max_tokens: int = 8000
    gpt_temperature: float = 0.7
    gpt_thinking_effort: str = "high"  # low, medium, high
    gpt_include_reasoning: bool = True
    
    # Rate Limiting
    rate_limit_per_minute: int = 60
    rate_limit_burst: int = 100


# Global settings instance
settings = Settings()
