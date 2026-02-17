from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from app.models.schemas import RAGQueryRequest, RAGQueryResponse
from app.graphs.rag_graph import rag_graph
from app.core.logging import get_logger
import json

logger = get_logger(__name__)
router = APIRouter()


@router.post("/query")
async def stream_rag_query(request: RAGQueryRequest):
    """
    Stream RAG query with thinking visualization.
    
    Retrieves relevant documents and generates answer with visible reasoning.
    
    Args:
        request: RAG query request
    
    Returns:
        StreamingResponse: SSE stream with retrieval steps and answer
    """
    logger.info(f"RAG query: {request.query[:50]}...")
    
    async def generate():
        async for chunk in rag_graph.stream_rag_query(
            query=request.query,
            show_thinking=request.show_thinking
        ):
            yield f"data: {json.dumps(chunk.model_dump())}\n\n"
    
    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive"
        }
    )


@router.post("/index")
async def index_document(
    doc_id: str,
    content: str,
    title: str
):
    """
    Index a document for RAG search.
    
    Args:
        doc_id: Document ID
        content: Document content
        title: Document title
    
    Returns:
        Success status
    """
    from app.services.search_service import search_service
    
    success = await search_service.index_document(
        doc_id=doc_id,
        content=content,
        title=title
    )
    
    return {"success": success, "doc_id": doc_id}
