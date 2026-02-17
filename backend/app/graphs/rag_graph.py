from typing import TypedDict, List, Dict, Any, AsyncGenerator
from langgraph.graph import StateGraph, END
from langchain_core.messages import BaseMessage
from app.core.logging import get_logger
from app.services.search_service import search_service
from app.services.openai_service import openai_service
from app.models.schemas import StreamChunk, StreamChunkType

logger = get_logger(__name__)


class RAGState(TypedDict):
    """State for RAG workflow."""
    query: str
    retrieved_docs: List[Dict[str, Any]]
    context: str
    response: str
    thinking_steps: List[Dict[str, Any]]


class RAGGraph:
    """LangGraph workflow for Retrieval Augmented Generation."""
    
    def __init__(self):
        """Initialize RAG graph."""
        self.graph = StateGraph(RAGState)
        
        # Add nodes
        self.graph.add_node("retrieve", self.retrieve_documents)
        self.graph.add_node("rank", self.rank_documents)
        self.graph.add_node("generate", self.generate_answer)
        
        # Add edges
        self.graph.set_entry_point("retrieve")
        self.graph.add_edge("retrieve", "rank")
        self.graph.add_edge("rank", "generate")
        self.graph.add_edge("generate", END)
        
        # Compile graph
        self.workflow = self.graph.compile()
        
        logger.info("RAGGraph initialized")
    
    async def retrieve_documents(self, state: RAGState) -> RAGState:
        """Retrieve relevant documents."""
        logger.info(f"Retrieving documents for query: {state['query'][:50]}...")
        
        # Perform hybrid search
        documents = await search_service.hybrid_search(
            query=state["query"],
            top_k=5
        )
        
        state["retrieved_docs"] = documents
        logger.info(f"Retrieved {len(documents)} documents")
        
        return state
    
    async def rank_documents(self, state: RAGState) -> RAGState:
        """Rank and filter documents."""
        logger.info("Ranking retrieved documents")
        
        # Already ranked by search service
        # Additional ranking logic can be added here
        
        # Build context from top documents
        context_parts = []
        for i, doc in enumerate(state["retrieved_docs"][:5], 1):
            context_parts.append(
                f"Document {i} (Score: {doc.get('score', 0):.2f}):\n{doc.get('content', '')}"
            )
        
        state["context"] = "\n\n".join(context_parts)
        
        return state
    
    async def generate_answer(self, state: RAGState) -> RAGState:
        """Generate answer using retrieved context."""
        logger.info("Generating answer with RAG context")
        
        # Prepare messages with context
        messages = [
            {
                "role": "system",
                "content": "You are a helpful assistant. Answer the question using the provided context. Show your reasoning."
            },
            {
                "role": "user",
                "content": f"Context:\n{state['context']}\n\nQuestion: {state['query']}"
            }
        ]
        
        # Generate response (non-streaming for workflow)
        result = await openai_service.create_completion(messages=messages)
        state["response"] = result["content"]
        
        return state
    
    async def stream_rag_query(
        self,
        query: str,
        show_thinking: bool = True
    ) -> AsyncGenerator[StreamChunk, None]:
        """
        Stream RAG query with thinking visualization.
        
        Args:
            query: User query
            show_thinking: Include thinking process
        
        Yields:
            StreamChunk: Thinking, content, and metadata chunks
        """
        logger.info(f"Starting RAG stream for query: {query[:50]}...")
        
        # Step 1: Retrieve documents
        yield StreamChunk(
            type=StreamChunkType.THINKING,
            content="Searching for relevant documents...",
            metadata={"step": "retrieve", "step_number": 1}
        )
        
        documents = await search_service.hybrid_search(query=query, top_k=5)
        
        yield StreamChunk(
            type=StreamChunkType.THINKING,
            content=f"Found {len(documents)} relevant documents. Ranking results...",
            metadata={"step": "rank", "step_number": 2, "doc_count": len(documents)}
        )
        
        # Build context
        context_parts = []
        for i, doc in enumerate(documents[:5], 1):
            context_parts.append(
                f"Document {i}: {doc.get('title', 'Untitled')} (Score: {doc.get('score', 0):.2f})"
            )
        
        yield StreamChunk(
            type=StreamChunkType.THINKING,
            content=f"Using top documents:\n" + "\n".join(context_parts),
            metadata={"step": "context", "step_number": 3}
        )
        
        # Prepare messages
        context = "\n\n".join([doc.get("content", "") for doc in documents[:5]])
        messages = [
            {
                "role": "system",
                "content": "Answer using the provided context. Cite sources and show reasoning."
            },
            {
                "role": "user",
                "content": f"Context:\n{context}\n\nQuestion: {query}"
            }
        ]
        
        yield StreamChunk(
            type=StreamChunkType.THINKING,
            content="Generating answer based on retrieved context...",
            metadata={"step": "generate", "step_number": 4}
        )
        
        # Stream the actual GPT-5.2 response with thinking
        async for chunk in openai_service.stream_chat_with_thinking(
            messages=messages,
            show_thinking=show_thinking
        ):
            yield chunk


# Global instance
rag_graph = RAGGraph()
