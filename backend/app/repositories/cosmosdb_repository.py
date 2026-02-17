from typing import Dict, Any, Optional, List
from app.repositories.base_repository import BaseRepository
from app.models.database import CosmosDBClient


class CosmosDBRepository(BaseRepository):
    """CosmosDB implementation of repository (wrapper for legacy code)."""
    
    def __init__(self):
        self.client = CosmosDBClient()
    
    async def create_conversation(
        self,
        user_id: str,
        session_id: str,
        title: str = "New Conversation"
    ) -> Dict[str, Any]:
        return await self.client.create_conversation(user_id, session_id, title)
    
    async def save_message(
        self,
        conversation_id: str,
        role: str,
        content: str,
        thinking_steps: Optional[List[Dict[str, Any]]] = None
    ) -> Dict[str, Any]:
        return await self.client.save_message(
            conversation_id, role, content, thinking_steps
        )
    
    async def get_conversation_messages(
        self,
        conversation_id: str,
        limit: int = 50
    ) -> List[Dict[str, Any]]:
        return await self.client.get_conversation_messages(conversation_id, limit)
    
    async def get_user_conversations(
        self,
        user_id: str,
        limit: int = 20
    ) -> List[Dict[str, Any]]:
        return await self.client.get_user_conversations(user_id, limit)
    
    async def update_conversation(
        self,
        session_id: str,
        updates: Dict[str, Any]
    ) -> Dict[str, Any]:
        return await self.client.update_conversation(session_id, updates)
    
    async def delete_conversation(
        self,
        session_id: str
    ) -> bool:
        # CosmosDB client needs this method implemented
        # For now, return True (implement when needed)
        return True
