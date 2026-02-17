from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import QueuePool
from contextlib import contextmanager
from typing import Generator
from app.core.config import settings
from app.core.logging import get_logger
from app.models.db_models import Base

logger = get_logger(__name__)


class DatabaseEngine:
    """PostgreSQL database engine manager."""
    
    def __init__(self):
        self.engine = None
        self.SessionLocal = None
    
    def initialize(self):
        """Initialize database engine and session factory."""
        if self.engine is not None:
            return
        
        if not settings.postgresql_url:
            logger.warning("PostgreSQL URL not configured, skipping initialization")
            return
        
        self.engine = create_engine(
            settings.postgresql_url,
            poolclass=QueuePool,
            pool_size=10,
            max_overflow=20,
            pool_pre_ping=True,
            echo=settings.debug,
        )
        
        self.SessionLocal = sessionmaker(
            autocommit=False,
            autoflush=False,
            bind=self.engine
        )
        
        logger.info("✅ PostgreSQL engine initialized")
    
    def create_tables(self):
        """Create all tables (for development only)."""
        if self.engine is None:
            self.initialize()
        
        Base.metadata.create_all(bind=self.engine)
        logger.info("✅ Database tables created")
    
    @contextmanager
    def get_session(self) -> Generator[Session, None, None]:
        """
        Get database session with automatic cleanup.
        
        Usage:
            with db_engine.get_session() as session:
                session.query(Conversation).all()
        """
        if self.SessionLocal is None:
            self.initialize()
        
        session = self.SessionLocal()
        try:
            yield session
            session.commit()
        except Exception as e:
            session.rollback()
            logger.error(f"Database session error: {e}")
            raise
        finally:
            session.close()


db_engine = DatabaseEngine()
