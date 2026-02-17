from sqlalchemy import Column, String, Integer, DateTime, Text, JSON, Index
from sqlalchemy.orm import declarative_base, relationship
from sqlalchemy import ForeignKey
from datetime import datetime

Base = declarative_base()


class Conversation(Base):
    """SQLAlchemy model for conversations."""
    __tablename__ = "conversations"
    
    id = Column(String(255), primary_key=True)
    user_id = Column(String(255), nullable=False, index=True)
    session_id = Column(String(255), nullable=False, unique=True, index=True)
    title = Column(String(500), default="New Conversation")
    message_count = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    messages = relationship("Message", back_populates="conversation", cascade="all, delete-orphan")
    
    __table_args__ = (
        Index('ix_conversations_user_updated', 'user_id', 'updated_at'),
    )
    
    def to_dict(self):
        """Convert model to dictionary matching CosmosDB format."""
        return {
            "id": self.id,
            "userId": self.user_id,
            "sessionId": self.session_id,
            "title": self.title,
            "messageCount": self.message_count,
            "createdAt": self.created_at.isoformat(),
            "updatedAt": self.updated_at.isoformat()
        }


class Message(Base):
    """SQLAlchemy model for messages."""
    __tablename__ = "messages"
    
    id = Column(String(255), primary_key=True)
    conversation_id = Column(String(255), ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False, index=True)
    role = Column(String(50), nullable=False)
    content = Column(Text, nullable=False)
    thinking_steps = Column(JSON, nullable=True)
    timestamp = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
    
    conversation = relationship("Conversation", back_populates="messages")
    
    __table_args__ = (
        Index('ix_messages_conversation_timestamp', 'conversation_id', 'timestamp'),
    )
    
    def to_dict(self):
        """Convert model to dictionary matching CosmosDB format."""
        return {
            "id": self.id,
            "conversationId": self.conversation_id,
            "role": self.role,
            "content": self.content,
            "thinkingSteps": self.thinking_steps or [],
            "timestamp": self.timestamp.isoformat()
        }


class User(Base):
    """SQLAlchemy model for users."""
    __tablename__ = "users"
    
    id = Column(String(255), primary_key=True)
    email = Column(String(255), unique=True, nullable=True, index=True)
    name = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False)
    
    def to_dict(self):
        """Convert model to dictionary."""
        return {
            "id": self.id,
            "email": self.email,
            "name": self.name,
            "createdAt": self.created_at.isoformat(),
            "updatedAt": self.updated_at.isoformat()
        }
