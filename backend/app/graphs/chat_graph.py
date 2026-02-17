from typing import TypedDict, List, Dict, Any, AsyncGenerator
from langgraph.graph import StateGraph, END
from langchain_core.messages import BaseMessage, HumanMessage, AIMessage
from app.core.logging import get_logger
from app.services.openai_service import openai_service
from app.models.schemas import ThinkingStep, StreamChunk, StreamChunkType

logger = get_logger(__name__)


class ChatState(TypedDict):
    """State for chat workflow."""
    messages: List[BaseMessage]
    thinking_steps: List[ThinkingStep]
    context: Dict[str, Any]
    current_response: str


class ChatGraph:
    """LangGraph workflow for chat with GPT-5.2 thinking visualization."""
    
    def __init__(self):
        """Initialize chat graph."""
        self.graph = StateGraph(ChatState)
        
        # Add nodes
        self.graph.add_node("prepare", self.prepare_messages)
        self.graph.add_node("generate", self.generate_response)
        self.graph.add_node("finalize", self.finalize_response)
        
        # Add edges
        self.graph.set_entry_point("prepare")
        self.graph.add_edge("prepare", "generate")
        self.graph.add_edge("generate", "finalize")
        self.graph.add_edge("finalize", END)
        
        # Compile graph
        self.workflow = self.graph.compile()
        
        logger.info("ChatGraph initialized with thinking support")
    
    async def prepare_messages(self, state: ChatState) -> ChatState:
        """Prepare messages for GPT-5.2."""
        logger.info("Preparing messages for chat")
        
        # Add system message if not present
        if not any(isinstance(msg, AIMessage) for msg in state["messages"]):
            state["context"]["system_added"] = True
        
        return state
    
    async def generate_response(self, state: ChatState) -> ChatState:
        """Generate response with thinking process using GPT-5.2."""
        logger.info("Generating response with GPT-5.2 thinking")
        
        # Convert LangChain messages to OpenAI format
        messages = []
        
        # Add system message
        messages.append({
            "role": "system",
            "content": "You are a helpful AI assistant. Think step-by-step and show your reasoning."
        })
        
        # Add conversation messages
        for msg in state["messages"]:
            if isinstance(msg, HumanMessage):
                messages.append({"role": "user", "content": msg.content})
            elif isinstance(msg, AIMessage):
                messages.append({"role": "assistant", "content": msg.content})
        
        # This would be used in streaming endpoint
        # Here we just demonstrate the structure
        state["current_response"] = "Response generated"
        
        return state
    
    async def finalize_response(self, state: ChatState) -> ChatState:
        """Finalize the response."""
        logger.info("Finalizing chat response")
        return state
    
    async def stream_chat(
        self,
        messages: List[Dict[str, str]],
        show_thinking: bool = True,
        reasoning_effort: str = "medium",
        verbosity: str = "medium",
        max_tokens: int = 16000,
    ) -> AsyncGenerator[StreamChunk, None]:
        """
        Stream chat response with thinking visualization.
        
        Args:
            messages: Conversation messages
            show_thinking: Include thinking process
            reasoning_effort: Reasoning effort level
            verbosity: Text output verbosity
            max_tokens: Maximum output tokens
        
        Yields:
            StreamChunk: Thinking and content chunks
        """
        logger.info(f"Starting chat stream (effort={reasoning_effort}, verbosity={verbosity})")
        
        # Use OpenAI service to stream with thinking
        async for chunk in openai_service.stream_chat_with_thinking(
            messages=messages,
            show_thinking=show_thinking,
            reasoning_effort=reasoning_effort,
            verbosity=verbosity,
            max_completion_tokens=max_tokens,
        ):
            yield chunk
    
    async def invoke(self, messages: List[BaseMessage]) -> Dict[str, Any]:
        """
        Invoke the chat workflow (non-streaming).
        
        Args:
            messages: Conversation messages
        
        Returns:
            Workflow result
        """
        initial_state: ChatState = {
            "messages": messages,
            "thinking_steps": [],
            "context": {},
            "current_response": ""
        }
        
        result = await self.workflow.ainvoke(initial_state)
        return result


# Global instance
chat_graph = ChatGraph()
