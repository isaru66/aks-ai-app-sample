from fastapi import APIRouter, HTTPException, status, BackgroundTasks
from fastapi.responses import StreamingResponse
from typing import AsyncGenerator
import asyncio
import uuid
from app.models.schemas import (
    ChatRequest,
    ChatResponse,
    StreamChunk,
    ChatMessage,
    MessageRole,
    ThinkingStep
)
from app.graphs.chat_graph import chat_graph
from app.repositories.factory import get_repository
from app.core.logging import get_logger

logger = get_logger(__name__)
router = APIRouter()

repository = get_repository()


async def _save_conversation(
    session_id: str,
    user_content: str,
    assistant_content: str,
    thinking_steps: list | None = None
) -> None:
    """Save conversation messages to database in background."""
    try:
        await repository.save_message(
            conversation_id=session_id,
            role="user",
            content=user_content
        )
        await repository.save_message(
            conversation_id=session_id,
            role="assistant",
            content=assistant_content,
            thinking_steps=thinking_steps
        )
        logger.info(f"Saved conversation to database: {session_id}")
    except Exception as e:
        logger.error(f"Error saving to database: {e}", exc_info=True)


async def chat_stream_generator(
    request: ChatRequest
) -> AsyncGenerator[str, None]:
    """
    Generate Server-Sent Events (SSE) stream for chat with thinking.
    
    Args:
        request: Chat request
    
    Yields:
        SSE formatted strings with thinking and content chunks
    """
    try:
        # Generate session ID if not provided
        session_id = request.session_id or str(uuid.uuid4())
        
        logger.info(f"Starting chat stream for session: {session_id}")
        
        # Ensure conversation exists (idempotent - won't fail if exists)
        await repository.create_conversation(
            user_id="default-user",  # TODO: Replace with actual user_id from auth
            session_id=session_id,
            title="New Conversation"
        )
        
        # Convert ChatMessage to dict format for OpenAI
        messages = [
            {"role": msg.role.value, "content": msg.content}
            for msg in request.messages
        ]
        
        # Collect thinking steps and content for storage
        thinking_steps_list = []
        content_parts = []
        
        # Stream response with thinking (+ optional MCP tool calling)
        async for chunk in chat_graph.stream_chat(
            messages=messages,
            show_thinking=request.show_thinking,
            reasoning_effort=request.reasoning_effort.value,
            verbosity=request.verbosity.value,
            max_tokens=request.max_tokens or 16000,
            mcp_servers=request.mcp_servers or [],
        ):
            # Format as SSE — single-pass JSON serialization
            yield f"data: {chunk.model_dump_json()}\n\n"
            
            # Collect data for storage
            if chunk.type == "thinking":
                thinking_steps_list.append({
                    "step_number": chunk.metadata.get("step_number", 0) if chunk.metadata else 0,
                    "reasoning": chunk.content
                })
            elif chunk.type == "content":
                content_parts.append(chunk.content)
        
        # Send final done event BEFORE database writes so client gets response faster
        done_chunk = StreamChunk(
            type="done",
            content="",
            metadata={
                "session_id": session_id,
                "total_thinking_steps": len(thinking_steps_list),
                "content_length": len("".join(content_parts))
            }
        )
        yield f"data: {done_chunk.model_dump_json()}\n\n"
        
        # Save conversation to database in background (non-blocking)
        asyncio.create_task(_save_conversation(
            session_id=session_id,
            user_content=request.messages[-1].content,
            assistant_content="".join(content_parts),
            thinking_steps=thinking_steps_list if request.show_thinking else None
        ))
    
    except Exception as e:
        logger.error(f"Error in chat stream: {e}", exc_info=True)
        
        error_chunk = StreamChunk(
            type="error",
            content=str(e),
            metadata={"error_type": type(e).__name__}
        )
        yield f"data: {error_chunk.model_dump_json()}\n\n"


@router.post("/completions", response_class=StreamingResponse)
async def stream_chat_completion(request: ChatRequest):
    """
    Stream chat completion with GPT-5.2 thinking process.
    
    This endpoint streams responses using Server-Sent Events (SSE).
    
    **Features**:
    - Real-time streaming responses
    - Visible thinking/reasoning steps
    - Auto-saves conversation to PostgreSQL
    
    **Stream Format**:
    ```
    data: {"type": "thinking", "content": "First, I need to...", "metadata": {...}}
    
    data: {"type": "content", "content": "The answer is...", "metadata": {...}}
    
    data: {"type": "done", "content": "", "metadata": {"session_id": "..."}}
    ```
    
    Args:
        request: Chat request with messages and options
    
    Returns:
        StreamingResponse: SSE stream with thinking and content
    """
    if not request.stream:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This endpoint only supports streaming. Set stream=true"
        )
    
    return StreamingResponse(
        chat_stream_generator(request),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no"  # Disable nginx buffering
        }
    )


@router.post("/completions/sync", response_model=ChatResponse)
async def create_chat_completion(request: ChatRequest):
    """
    Non-streaming chat completion (legacy support).
    
    For streaming with thinking visualization, use POST /completions instead.
    
    Args:
        request: Chat request
    
    Returns:
        ChatResponse: Complete response with thinking steps
    """
    try:
        session_id = request.session_id or str(uuid.uuid4())
        
        logger.info(f"Creating non-streaming chat completion for session: {session_id}")
        
        # Convert to dict format
        messages = [
            {"role": msg.role.value, "content": msg.content}
            for msg in request.messages
        ]
        
        # Get completion
        result = await chat_graph.invoke(messages)
        
        # Build response
        response = ChatResponse(
            message=ChatMessage(
                role=MessageRole.ASSISTANT,
                content=result.get("current_response", ""),
                thinking_steps=None  # Non-streaming doesn't capture thinking steps easily
            ),
            session_id=session_id,
            usage=None
        )
        
        return response
    
    except Exception as e:
        logger.error(f"Error in chat completion: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.get("/history/{session_id}")
async def get_chat_history(session_id: str):
    """
    Get chat history for a session.
    
    Args:
        session_id: Session ID
    
    Returns:
        List of messages with thinking steps
    """
    try:
        messages = await repository.get_conversation_messages(session_id)
        return {"session_id": session_id, "messages": messages}
    
    except Exception as e:
        logger.error(f"Error getting chat history: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )


@router.delete("/{session_id}")
async def delete_conversation(session_id: str):
    """
    Delete a conversation session.
    
    Args:
        session_id: Session ID to delete
    
    Returns:
        Success message
    """
    try:
        # Delete conversation using repository
        await repository.delete_conversation(session_id)
        logger.info(f"Deleting conversation: {session_id}")
        return {"message": f"Conversation {session_id} deleted"}
    
    except Exception as e:
        logger.error(f"Error deleting conversation: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )
