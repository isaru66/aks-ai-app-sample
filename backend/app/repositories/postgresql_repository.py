from typing import Dict, Any, Optional, List
from datetime import datetime
import uuid
from app.repositories.base_repository import BaseRepository
from app.models.db_engine import db_engine
from app.models.db_models import Conversation, Message
from app.core.logging import get_logger

logger = get_logger(__name__)


class PostgreSQLRepository(BaseRepository):
    """PostgreSQL implementation of repository using SQLAlchemy ORM."""
    
    def __init__(self):
        db_engine.initialize()
    
    async def create_conversation(
        self,
        user_id: str,
        session_id: str,
        title: str = "New Conversation"
    ) -> Dict[str, Any]:
        """Create a new conversation or return existing one."""
        with db_engine.get_session() as session:
            # Check if conversation already exists
            existing = session.query(Conversation).filter_by(
                id=session_id
            ).first()
            
            if existing:
                logger.info(f"Conversation already exists: {session_id}")
                return existing.to_dict()
            
            # Create new conversation
            conversation = Conversation(
                id=session_id,
                user_id=user_id,
                session_id=session_id,
                title=title,
                message_count=0,
                created_at=datetime.utcnow(),
                updated_at=datetime.utcnow()
            )
            
            session.add(conversation)
            session.commit()
            session.refresh(conversation)
            
            logger.info(f"Created conversation: {session_id}")
            return conversation.to_dict()
    
    async def save_message(
        self,
        conversation_id: str,
        role: str,
        content: str,
        thinking_steps: Optional[List[Dict[str, Any]]] = None
    ) -> Dict[str, Any]:
        """Save a message with optional thinking steps."""
        with db_engine.get_session() as session:
            # Check if conversation exists
            conversation = session.query(Conversation).filter_by(
                id=conversation_id
            ).first()
            
            if not conversation:
                raise ValueError(
                    f"Conversation not found: {conversation_id}. "
                    "Please create conversation first using create_conversation()."
                )
            
            # Create message
            message = Message(
                id=str(uuid.uuid4()),
                conversation_id=conversation_id,
                role=role,
                content=content,
                thinking_steps=thinking_steps,
                timestamp=datetime.utcnow()
            )
            
            session.add(message)
            
            # Update conversation metadata
            conversation.message_count += 1
            conversation.updated_at = datetime.utcnow()
            
            session.commit()
            session.refresh(message)
            
            logger.info(f"Saved message for conversation: {conversation_id}")
            return message.to_dict()
    
    async def get_conversation_messages(
        self,
        conversation_id: str,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """Get messages for a conversation."""
        with db_engine.get_session() as session:
            messages = session.query(Message).filter_by(
                conversation_id=conversation_id
            ).order_by(
                Message.timestamp.desc()
            ).limit(limit).all()
            
            return [msg.to_dict() for msg in messages]
    
    async def get_user_conversations(
        self,
        user_id: str,
        limit: int = 20
    ) -> List[Dict[str, Any]]:
        """Get conversations for a user."""
        with db_engine.get_session() as session:
            conversations = session.query(Conversation).filter_by(
                user_id=user_id
            ).order_by(
                Conversation.updated_at.desc()
            ).limit(limit).all()
            
            return [conv.to_dict() for conv in conversations]
    
    async def update_conversation(
        self,
        session_id: str,
        updates: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Update conversation metadata."""
        with db_engine.get_session() as session:
            conversation = session.query(Conversation).filter_by(
                session_id=session_id
            ).first()
            
            if not conversation:
                raise ValueError(f"Conversation not found: {session_id}")
            
            for key, value in updates.items():
                snake_key = key.replace("userId", "user_id").replace(
                    "sessionId", "session_id"
                ).replace("messageCount", "message_count")
                
                if hasattr(conversation, snake_key):
                    setattr(conversation, snake_key, value)
            
            conversation.updated_at = datetime.utcnow()
            
            session.commit()
            session.refresh(conversation)
            
            return conversation.to_dict()
    
    async def delete_conversation(
        self,
        session_id: str
    ) -> bool:
        """Delete a conversation and all its messages."""
        with db_engine.get_session() as session:
            conversation = session.query(Conversation).filter_by(
                session_id=session_id
            ).first()
            
            if not conversation:
                logger.warning(f"Conversation not found for deletion: {session_id}")
                return False
            
            # Delete conversation (CASCADE will delete messages automatically)
            session.delete(conversation)
            session.commit()
            
            logger.info(f"Deleted conversation: {session_id}")
            return True
