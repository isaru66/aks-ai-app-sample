from pydantic import BaseModel, Field, HttpUrl
from typing import List, Optional, Dict, Any
from datetime import datetime
from enum import Enum


class MessageRole(str, Enum):
    """Message role enumeration."""
    USER = "user"
    ASSISTANT = "assistant"
    SYSTEM = "system"


class StreamChunkType(str, Enum):
    """Stream chunk type enumeration."""
    THINKING = "thinking"
    CONTENT = "content"
    DONE = "done"
    ERROR = "error"


class ThinkingStep(BaseModel):
    """Model for GPT-5.2 thinking/reasoning steps."""
    reasoning: str = Field(..., description="Reasoning text for this step")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Step timestamp")
    metadata: Optional[Dict[str, Any]] = Field(default=None, description="Additional metadata")


class ChatMessage(BaseModel):
    """Chat message model."""
    role: MessageRole = Field(..., description="Message role")
    content: str = Field(..., description="Message content")
    thinking_steps: Optional[List[ThinkingStep]] = Field(
        default=None,
        description="Thinking steps (only for assistant messages with reasoning)"
    )
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Message timestamp")
    metadata: Optional[Dict[str, Any]] = Field(default=None, description="Additional metadata")


class ReasoningEffort(str, Enum):
    """Reasoning effort levels for GPT-5 series models."""
    NONE = "none"
    MINIMAL = "minimal"
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class Verbosity(str, Enum):
    """Text verbosity levels (GPT-5 series)."""
    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"


class MCPTransport(str, Enum):
    """MCP server transport protocol."""
    STREAMABLE_HTTP = "streamable-http"
    SSE = "sse"


class MCPServerConfig(BaseModel):
    """MCP server configuration forwarded from the frontend."""
    url: str = Field(..., description="MCP server URL")
    transport: MCPTransport = Field(
        default=MCPTransport.STREAMABLE_HTTP,
        description="Transport protocol (streamable-http or sse)"
    )
    api_key: Optional[str] = Field(default=None, description="Optional bearer token")


class ChatRequest(BaseModel):
    """Chat request model."""
    messages: List[ChatMessage] = Field(..., description="Conversation messages")
    session_id: Optional[str] = Field(default=None, description="Session ID for conversation tracking")
    user_id: Optional[str] = Field(default=None, description="User ID")
    show_thinking: bool = Field(default=True, description="Include thinking process in response")
    stream: bool = Field(default=True, description="Enable streaming response")
    reasoning_effort: ReasoningEffort = Field(
        default=ReasoningEffort.LOW,
        description="Reasoning effort level: none, minimal, low, medium, high"
    )
    verbosity: Verbosity = Field(
        default=Verbosity.LOW,
        description="Text output verbosity: low, medium, high (GPT-5 series)"
    )
    max_tokens: Optional[int] = Field(default=16000, gt=0, description="Maximum output tokens")
    mcp_servers: Optional[List[MCPServerConfig]] = Field(
        default=None,
        description="MCP servers to use for tool calling during this request"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "messages": [
                    {"role": "user", "content": "Explain quantum computing"}
                ],
                "session_id": "session-123",
                "show_thinking": True,
                "stream": True,
                "reasoning_effort": "medium",
                "verbosity": "medium"
            }
        }


class StreamChunk(BaseModel):
    """Streaming response chunk."""
    type: StreamChunkType = Field(..., description="Chunk type")
    content: str = Field(..., description="Chunk content")
    metadata: Optional[Dict[str, Any]] = Field(default=None, description="Additional metadata")
    
    class Config:
        json_schema_extra = {
            "example": {
                "type": "thinking",
                "content": "First, I need to break down quantum computing into basic concepts...",
                "metadata": {"step_number": 1, "confidence": 0.95}
            }
        }


class ChatResponse(BaseModel):
    """Non-streaming chat response."""
    message: ChatMessage = Field(..., description="Assistant message")
    session_id: str = Field(..., description="Session ID")
    usage: Optional[Dict[str, int]] = Field(default=None, description="Token usage statistics")
    
    class Config:
        json_schema_extra = {
            "example": {
                "message": {
                    "role": "assistant",
                    "content": "Quantum computing uses quantum bits...",
                    "thinking_steps": [
                        {
                            "step_number": 1,
                            "reasoning": "Need to explain quantum bits first",
                            "confidence": 0.95
                        }
                    ]
                },
                "session_id": "session-123",
                "usage": {"prompt_tokens": 10, "completion_tokens": 50, "total_tokens": 60}
            }
        }


class ConversationSession(BaseModel):
    """Conversation session model."""
    id: str = Field(..., description="Session ID")
    user_id: str = Field(..., description="User ID")
    title: Optional[str] = Field(default="New Conversation", description="Conversation title")
    message_count: int = Field(default=0, description="Number of messages")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="Creation timestamp")
    updated_at: datetime = Field(default_factory=datetime.utcnow, description="Last update timestamp")
    metadata: Optional[Dict[str, Any]] = Field(default=None, description="Additional metadata")


class HealthResponse(BaseModel):
    """Health check response."""
    status: str = Field(..., description="Service status")
    version: str = Field(..., description="API version")
    environment: str = Field(..., description="Environment name")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Check timestamp")
    services: Optional[Dict[str, str]] = Field(default=None, description="Service statuses")


class ErrorResponse(BaseModel):
    """Error response model."""
    error: str = Field(..., description="Error type")
    message: str = Field(..., description="Error message")
    detail: Optional[str] = Field(default=None, description="Detailed error information")
    timestamp: datetime = Field(default_factory=datetime.utcnow, description="Error timestamp")


class RAGQueryRequest(BaseModel):
    """RAG query request."""
    query: str = Field(..., description="Search query")
    top_k: int = Field(default=5, ge=1, le=20, description="Number of documents to retrieve")
    session_id: Optional[str] = Field(default=None, description="Session ID")
    show_thinking: bool = Field(default=True, description="Show reasoning process")


class RAGQueryResponse(BaseModel):
    """RAG query response."""
    answer: str = Field(..., description="Generated answer")
    sources: List[Dict[str, Any]] = Field(..., description="Source documents")
    thinking_steps: Optional[List[ThinkingStep]] = Field(default=None, description="Reasoning steps")
    session_id: str = Field(..., description="Session ID")


class AgentRequest(BaseModel):
    """Agent execution request."""
    task: str = Field(..., description="Task description")
    agent_type: str = Field(default="general", description="Agent type")
    session_id: Optional[str] = Field(default=None, description="Session ID")
    show_thinking: bool = Field(default=True, description="Show agent reasoning")


class AgentResponse(BaseModel):
    """Agent execution response."""
    task_id: str = Field(..., description="Task ID")
    status: str = Field(..., description="Task status")
    result: Optional[str] = Field(default=None, description="Task result")
    thinking_steps: Optional[List[ThinkingStep]] = Field(default=None, description="Agent reasoning")
    metadata: Optional[Dict[str, Any]] = Field(default=None, description="Additional metadata")
