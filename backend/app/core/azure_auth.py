from azure.identity import DefaultAzureCredential, ClientSecretCredential
from typing import Optional
from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)


class AzureAuthManager:
    """Manage Azure authentication using Managed Identity or Service Principal."""
    
    def __init__(self):
        self._credential: Optional[DefaultAzureCredential | ClientSecretCredential] = None
    
    def get_credential(self):
        """Get Azure credential (Managed Identity or Service Principal)."""
        if self._credential:
            return self._credential
        
        try:
            # Try Managed Identity first (recommended for production)
            if not settings.azure_client_secret:
                logger.info("Using DefaultAzureCredential (Managed Identity)")
                self._credential = DefaultAzureCredential()
            else:
                # Fallback to Service Principal (for local development)
                logger.info("Using ClientSecretCredential (Service Principal)")
                self._credential = ClientSecretCredential(
                    tenant_id=settings.azure_tenant_id,
                    client_id=settings.azure_client_id,
                    client_secret=settings.azure_client_secret
                )
            
            return self._credential
        
        except Exception as e:
            logger.error(f"Failed to get Azure credential: {e}")
            raise


# Global instance
azure_auth = AzureAuthManager()
