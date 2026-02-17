from app.repositories.base_repository import BaseRepository
from app.repositories.postgresql_repository import PostgreSQLRepository
from app.core.logging import get_logger

logger = get_logger(__name__)

_repository_instance: BaseRepository = None


def get_repository() -> BaseRepository:
    """
    Get repository instance (PostgreSQL only).
    
    Returns singleton PostgreSQL repository instance.
    """
    global _repository_instance
    
    if _repository_instance is None:
        logger.info("🐘 Using PostgreSQL repository")
        _repository_instance = PostgreSQLRepository()
    
    return _repository_instance
