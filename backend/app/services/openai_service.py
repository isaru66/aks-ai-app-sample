from openai import AsyncAzureOpenAI
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from typing import AsyncGenerator, List, Dict, Any, Optional
from app.core.config import settings
from app.core.logging import get_logger
from app.models.schemas import ThinkingStep, StreamChunk, StreamChunkType

logger = get_logger(__name__)


class OpenAIService:
    """Azure OpenAI Service using the Responses API for newer model support."""
    
    def __init__(self):
        """Initialize Azure OpenAI client with managed identity."""
        # Use DefaultAzureCredential for authentication
        credential = DefaultAzureCredential()
        token_provider = get_bearer_token_provider(
            credential, 
            "https://cognitiveservices.azure.com/.default"
        )
        
        azure_endpoint = settings.azure_openai_endpoint.rstrip('/')
        
        self.client = AsyncAzureOpenAI(
            azure_endpoint=settings.azure_openai_endpoint,
            azure_ad_token_provider=token_provider,
            api_version=settings.azure_openai_api_version
        )
        
        self.deployment_name = settings.azure_openai_deployment_name
        self.model = settings.azure_openai_model
        
        logger.info(f"OpenAI Service initialized (Responses API) with managed identity, model: {self.model}")
        logger.info(f"Endpoint: {azure_endpoint}, API Version: {settings.azure_openai_api_version}")

    def _messages_to_response_input(
        self, messages: List[Dict[str, str]]
    ) -> List[Dict[str, Any]]:
        """
        Convert chat-style messages to Responses API input items.

        The Responses API accepts an ``input`` list where each item has a
        ``role`` (``user``, ``assistant``, ``system`` / ``developer``) and
        ``content``.  System messages are mapped to the ``developer`` role.
        """
        items: List[Dict[str, Any]] = []
        for msg in messages:
            role = msg["role"]
            if role == "system":
                role = "developer"
            items.append({"role": role, "content": msg["content"]})
        return items

    # ------------------------------------------------------------------
    # Streaming (Responses API)
    # ------------------------------------------------------------------

    async def stream_chat_with_thinking(
        self,
        messages: List[Dict[str, str]],
        show_thinking: bool = True,
        reasoning_effort: str = "medium",
        verbosity: str = "medium",
        max_completion_tokens: int = 16000
    ) -> AsyncGenerator[StreamChunk, None]:
        """
        Stream responses with visible thinking/reasoning using the Responses API.

        Args:
            messages: Conversation messages
            show_thinking: Include reasoning steps in stream
            reasoning_effort: Reasoning effort level (none/minimal/low/medium/high)
            verbosity: Text output verbosity (low/medium/high)
            max_completion_tokens: Maximum tokens to generate

        Yields:
            StreamChunk: Chunks of type 'thinking', 'content', 'done', or 'error'
        """
        try:
            logger.info(f"Starting Responses API stream with thinking={show_thinking}, "
                        f"effort={reasoning_effort}, verbosity={verbosity}")

            input_items = self._messages_to_response_input(messages)

            # Build reasoning config from user selection
            reasoning: Dict[str, Any] = {"effort": reasoning_effort}
            if show_thinking:
                reasoning["summary"] = "auto"
            else:
                reasoning["summary"] = "none"

            stream = await self.client.responses.create(
                model=self.deployment_name,
                input=input_items,
                stream=True,
                max_output_tokens=max_completion_tokens,
                reasoning=reasoning,
                text={"verbosity": verbosity},
            )

            step_number = 0

            async for event in stream:
                event_type = event.type

                # Reasoning / thinking tokens
                if event_type == "response.reasoning_summary_text.delta":
                    step_number += 1
                    yield StreamChunk(
                        type=StreamChunkType.THINKING,
                        content=event.delta
                    )

                # Output text tokens
                elif event_type == "response.output_text.delta":
                    yield StreamChunk(
                        type=StreamChunkType.CONTENT,
                        content=event.delta,
                    )

                # Stream complete
                elif event_type == "response.completed":
                    break

        except Exception as e:
            logger.error(f"Error in Responses API streaming: {e}", exc_info=True)
            yield StreamChunk(
                type=StreamChunkType.ERROR,
                content=str(e),
                metadata={"error_type": type(e).__name__}
            )

    # ------------------------------------------------------------------
    # Non-streaming (Responses API)
    # ------------------------------------------------------------------

    async def create_completion(
        self,
        messages: List[Dict[str, str]],
        reasoning_effort: str = "medium",
        verbosity: str = "medium",
        max_completion_tokens: int = 16000
    ) -> Dict[str, Any]:
        """
        Non-streaming completion via the Responses API.

        Args:
            messages: Conversation messages
            reasoning_effort: Reasoning effort level
            verbosity: Text output verbosity
            max_completion_tokens: Maximum tokens

        Returns:
            Completion response with content and usage
        """
        try:
            input_items = self._messages_to_response_input(messages)

            response = await self.client.responses.create(
                model=self.deployment_name,
                input=input_items,
                max_output_tokens=max_completion_tokens,
                stream=False,
                reasoning={"effort": reasoning_effort, "summary": "auto"},
                text={"verbosity": verbosity},
            )

            # Extract the first output message text
            content = ""
            for output_item in response.output:
                if output_item.type == "message":
                    for part in output_item.content:
                        if part.type == "output_text":
                            content += part.text

            return {
                "content": content,
                "finish_reason": response.status,  # e.g. "completed"
                "usage": {
                    "prompt_tokens": response.usage.input_tokens,
                    "completion_tokens": response.usage.output_tokens,
                    "total_tokens": response.usage.input_tokens + response.usage.output_tokens
                }
            }

        except Exception as e:
            logger.error(f"Error in Responses API completion: {e}", exc_info=True)
            raise

    # ------------------------------------------------------------------
    # Embeddings (unchanged — no Responses API equivalent)
    # ------------------------------------------------------------------

    async def create_embedding(self, text: str) -> List[float]:
        """
        Create embedding vector for text (for RAG).

        Args:
            text: Text to embed

        Returns:
            Embedding vector
        """
        try:
            response = await self.client.embeddings.create(
                model=settings.azure_openai_embedding_deployment,
                input=text
            )

            return response.data[0].embedding

        except Exception as e:
            logger.error(f"Error creating embedding: {e}", exc_info=True)
            raise


# Global instance
openai_service = OpenAIService()
