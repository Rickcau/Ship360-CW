import os
from pydantic_settings import BaseSettings
from pydantic import model_validator
from typing import List, Optional, Dict, Any
from functools import lru_cache
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

class Settings(BaseSettings):
    # Project settings
    PROJECT_NAME: str = "Chat API"
    API_PREFIX: str = "/api"
    DEBUG: bool = False
    
    # CORS
    CORS_ORIGINS: List[str] = ["*"]
    
    # Azure OpenAI
    AZURE_OPENAI_API_KEY: str
    AZURE_OPENAI_ENDPOINT: str
    AZURE_OPENAI_API_VERSION: str = "2024-08-01-preview"
    AZURE_OPENAI_CHAT_DEPLOYMENT_NAME: str

    # Ship 360 API
    SP360_TOKEN_URL: str
    SP360_TOKEN_USERNAME: str
    SP360_TOKEN_PASSWORD: str

    # Semantic Kernel agent configurations
    MASTER_AGENT_DEPLOYMENT: str
    INTENT_AGENT_DEPLOYMENT: str
    RATE_AGENT_DEPLOYMENT: str
    LABEL_AGENT_DEPLOYMENT: str
    TRACKING_AGENT_DEPLOYMENT: str
    
    # Optional - Azure AI Search (uncomment if needed)
    # AZURE_SEARCH_SERVICE_ENDPOINT: Optional[str] = None
    # AZURE_SEARCH_INDEX_NAME: Optional[str] = None
    # AZURE_SEARCH_API_KEY: Optional[str] = None
    
    # Optional logging settings
    LOG_LEVEL: str = "INFO"
    
    class Config:
        env_file = ".env"
        case_sensitive = True
        
    @model_validator(mode='after')
    def check_required_fields(self) -> 'Settings':
        for field_name, field in self.model_fields.items():
            if field.is_required() and getattr(self, field_name) is None:
                raise ValueError(f"{field_name} environment variable is required")
        return self

@lru_cache()
def get_settings() -> Settings:
    return Settings()

settings = get_settings()