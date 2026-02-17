from abc import ABC, abstractmethod
from typing import Dict, Any, Optional, List


class BaseRepository(ABC):
    """Abstract repository interface for database operations."""
    
    @abstractmethod
    async def create_conversation(
        self,
        user_id: str,
        session_id: str,
        title: str = "New Conversation"
    ) -> Dict[str, Any]:
        """Create a new conversation."""
        pass
    
    @abstractmethod
    async def save_message(
        self,
        conversation_id: str,
        role: str,
        content: str,
        thinking_steps: Optional[List[Dict[str, Any]]] = None
    ) -> Dict[str, Any]:
        """Save a message with optional thinking steps."""
        pass
    
    @abstractmethod
    async def get_conversation_messages(
        self,
        conversation_id: str,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        """Get messages for a conversation."""
        pass
    
    @abstractmethod
    async def get_user_conversations(
        self,
        user_id: str,
        limit: int = 20
    ) -> List[Dict[str, Any]]:
        """Get conversations for a user."""
        pass
    
    @abstractmethod
    async def update_conversation(
        self,
        session_id: str,
        updates: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Update conversation metadata."""
        pass
    
    @abstractmethod
    async def delete_conversation(
        self,
        session_id: str
    ) -> bool:
        """Delete a conversation and all its messages."""
        pass
