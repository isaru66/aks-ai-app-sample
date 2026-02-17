from azure.search.documents.aio import SearchClient
from azure.search.documents.models import VectorizedQuery
from azure.core.credentials import AzureKeyCredential
from typing import List, Dict, Any, Optional
from app.core.config import settings
from app.core.logging import get_logger
from app.services.openai_service import openai_service

logger = get_logger(__name__)


class SearchService:
    """Azure AI Search service for RAG (Retrieval Augmented Generation)."""
    
    def __init__(self):
        """Initialize Azure AI Search client."""
        self.client = SearchClient(
            endpoint=settings.azure_search_endpoint,
            index_name=settings.azure_search_index_name,
            credential=AzureKeyCredential(settings.azure_search_api_key)
        )
        
        logger.info(f"Search Service initialized with index: {settings.azure_search_index_name}")
    
    async def vector_search(
        self,
        query: str,
        top_k: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Perform vector search for RAG.
        
        Args:
            query: Search query
            top_k: Number of results to return
        
        Returns:
            List of search results
        """
        try:
            # Create embedding for the query
            query_embedding = await openai_service.create_embedding(query)
            
            # Create vector query
            vector_query = VectorizedQuery(
                vector=query_embedding,
                k_nearest_neighbors=top_k,
                fields="contentVector"
            )
            
            # Perform search
            results = await self.client.search(
                search_text=query,
                vector_queries=[vector_query],
                select=["id", "content", "title", "metadata"],
                top=top_k
            )
            
            documents = []
            async for result in results:
                documents.append({
                    "id": result.get("id"),
                    "content": result.get("content"),
                    "title": result.get("title"),
                    "score": result.get("@search.score"),
                    "metadata": result.get("metadata", {})
                })
            
            logger.info(f"Vector search returned {len(documents)} results")
            return documents
        
        except Exception as e:
            logger.error(f"Error in vector search: {e}", exc_info=True)
            return []
    
    async def hybrid_search(
        self,
        query: str,
        top_k: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Perform hybrid search (keyword + semantic + vector).
        
        Args:
            query: Search query
            top_k: Number of results
        
        Returns:
            Search results
        """
        try:
            # Create embedding
            query_embedding = await openai_service.create_embedding(query)
            
            # Vector query
            vector_query = VectorizedQuery(
                vector=query_embedding,
                k_nearest_neighbors=top_k,
                fields="contentVector"
            )
            
            # Hybrid search with semantic ranking
            results = await self.client.search(
                search_text=query,
                vector_queries=[vector_query],
                select=["id", "content", "title", "metadata"],
                query_type="semantic",
                semantic_configuration_name="default",
                top=top_k
            )
            
            documents = []
            async for result in results:
                documents.append({
                    "id": result.get("id"),
                    "content": result.get("content"),
                    "title": result.get("title"),
                    "score": result.get("@search.score"),
                    "reranker_score": result.get("@search.rerankerScore"),
                    "metadata": result.get("metadata", {})
                })
            
            logger.info(f"Hybrid search returned {len(documents)} results")
            return documents
        
        except Exception as e:
            logger.error(f"Error in hybrid search: {e}", exc_info=True)
            return []
    
    async def index_document(
        self,
        doc_id: str,
        content: str,
        title: str,
        metadata: Optional[Dict[str, Any]] = None
    ) -> bool:
        """
        Index a document for search.
        
        Args:
            doc_id: Document ID
            content: Document content
            title: Document title
            metadata: Additional metadata
        
        Returns:
            Success status
        """
        try:
            # Create embedding for content
            content_embedding = await openai_service.create_embedding(content)
            
            document = {
                "id": doc_id,
                "content": content,
                "title": title,
                "contentVector": content_embedding,
                "metadata": metadata or {}
            }
            
            result = await self.client.upload_documents(documents=[document])
            
            logger.info(f"Indexed document: {doc_id}")
            return result[0].succeeded
        
        except Exception as e:
            logger.error(f"Error indexing document {doc_id}: {e}", exc_info=True)
            return False


# Global instance
search_service = SearchService()
