import time
import os
import json
from contextlib import contextmanager
from typing import Optional, Dict, Any, List
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider, ReadableSpan
from opentelemetry.sdk.trace.export import BatchSpanProcessor, SpanProcessor, SpanExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.semconv.resource import ResourceAttributes
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from azure.monitor.opentelemetry.exporter import AzureMonitorTraceExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor
from opentelemetry.trace import Status, StatusCode
from opentelemetry.context import Context
from fastapi import FastAPI
from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)

# Global tracer instance
_tracer: Optional[trace.Tracer] = None


class FilteringSpanProcessor(SpanProcessor):
    """
    Custom span processor that filters out unwanted spans before export.
    
    Filters out low-level ASGI event spans like http.response.body to reduce trace noise.
    """
    
    def __init__(self, wrapped_processor: SpanProcessor):
        self.wrapped_processor = wrapped_processor
    
    def on_start(self, span: ReadableSpan, parent_context: Optional[Context] = None) -> None:
        """Forward span start to wrapped processor."""
        self.wrapped_processor.on_start(span, parent_context)
    
    def on_end(self, span: ReadableSpan) -> None:
        """Filter spans before forwarding to wrapped processor."""
        # Get span attributes
        attributes = span.attributes or {}
        
        # Filter out ASGI response body event spans
        asgi_event_type = attributes.get("asgi.event.type")
        if asgi_event_type == "http.response.body":
            # Skip this span - don't forward to exporter
            return
        
        # Forward all other spans to the wrapped processor
        self.wrapped_processor.on_end(span)
    
    def shutdown(self) -> None:
        """Forward shutdown to wrapped processor."""
        self.wrapped_processor.shutdown()
    
    def force_flush(self, timeout_millis: int = 30000) -> bool:
        """Forward force_flush to wrapped processor."""
        return self.wrapped_processor.force_flush(timeout_millis)


# ---------------------------------------------------------------------------
# GenAI Semantic Conventions — Opt-In Content Capture Helpers
# Ref: https://opentelemetry.io/docs/specs/semconv/gen-ai/azure-ai-inference/
# ---------------------------------------------------------------------------

def _is_content_capture_enabled() -> bool:
    """Return True when opt-in gen_ai content capture is enabled.

    Controlled by the OTEL_GENAI_CAPTURE_MESSAGE_CONTENT env var / config
    setting. Defaults to False because these attributes may contain PII.
    """
    from app.core.config import settings  # lazy import to avoid circular deps
    return getattr(settings, "otel_genai_capture_message_content", False)


def _build_system_instructions_schema(
    messages: List[Dict[str, Any]]
) -> List[Dict[str, Any]]:
    """Extract system / developer messages into gen_ai.system_instructions schema.

    Schema: [{"type": "text", "content": "..."}]
    """
    result: List[Dict[str, Any]] = []
    for msg in messages:
        role = msg.get("role", "")
        if role not in ("system", "developer"):
            continue
        content = msg.get("content", "")
        if isinstance(content, str):
            if content:
                result.append({"type": "text", "content": content})
        elif isinstance(content, list):
            for item in content:
                if isinstance(item, dict) and item.get("type") == "text":
                    result.append({"type": "text", "content": item.get("text", "")})
    return result


def _build_input_messages_schema(
    messages: List[Dict[str, Any]]
) -> List[Dict[str, Any]]:
    """Convert conversation messages (non-system) into gen_ai.input.messages schema.

    Schema: [{"role": "user", "parts": [{"type": "text", "content": "..."}]}]
    Tool call / function_call items from the Responses API multi-round input
    are also included using appropriate part types.
    """
    result: List[Dict[str, Any]] = []
    for msg in messages:
        role = msg.get("role", "")
        msg_type = msg.get("type", "")

        # Skip system / developer messages (captured in system_instructions)
        if role in ("system", "developer"):
            continue

        # Responses-API function_call output item (tool result)
        if msg_type == "function_call_output":
            result.append({
                "role": "tool",
                "parts": [{
                    "type": "tool_call_response",
                    "id": msg.get("call_id", ""),
                    "content": msg.get("output", ""),
                }],
            })
            continue

        # Responses-API function_call item (assistant tool call)
        if msg_type == "function_call":
            try:
                arguments = json.loads(msg.get("arguments", "{}"))
            except (json.JSONDecodeError, TypeError):
                arguments = msg.get("arguments", {})
            result.append({
                "role": "assistant",
                "parts": [{
                    "type": "tool_call",
                    "id": msg.get("call_id", ""),
                    "name": msg.get("name", ""),
                    "arguments": arguments,
                }],
            })
            continue

        # Standard chat message
        content = msg.get("content", "")
        if isinstance(content, str):
            parts: List[Dict[str, Any]] = [{"type": "text", "content": content}]
        elif isinstance(content, list):
            parts = []
            for item in content:
                if isinstance(item, dict):
                    if item.get("type") == "text":
                        parts.append({"type": "text", "content": item.get("text", "")})
                    else:
                        parts.append(item)
                else:
                    parts.append({"type": "text", "content": str(item)})
        else:
            parts = [{"type": "text", "content": str(content)}]

        if role:
            result.append({"role": role, "parts": parts})

    return result


def _build_output_messages_schema(
    content: str,
    finish_reason: str = "stop",
    tool_calls: Optional[List[Dict[str, Any]]] = None,
) -> List[Dict[str, Any]]:
    """Build gen_ai.output.messages schema from model response.

    Schema: [{"role": "assistant", "parts": [...], "finish_reason": "stop"}]
    """
    parts: List[Dict[str, Any]] = []
    if content:
        parts.append({"type": "text", "content": content})
    if tool_calls:
        for tc in tool_calls:
            try:
                arguments = json.loads(tc.get("arguments", "{}"))
            except (json.JSONDecodeError, TypeError):
                arguments = tc.get("arguments", {})
            parts.append({
                "type": "tool_call",
                "id": tc.get("id", ""),
                "name": tc.get("name", ""),
                "arguments": arguments,
            })
    return [{"role": "assistant", "parts": parts, "finish_reason": finish_reason}]


def _build_tool_definitions_schema(
    tools: List[Dict[str, Any]]
) -> List[Dict[str, Any]]:
    """Convert OpenAI/Responses API tool definitions into gen_ai.tool.definitions schema.

    Schema: [{"type": "function", "name": "...", "description": "...", "parameters": {...}}]
    """
    result: List[Dict[str, Any]] = []
    for tool in tools:
        if tool.get("type") == "function":
            fn = tool.get("function", tool)  # some callers put attrs at top level
            result.append({
                "type": "function",
                "name": fn.get("name", tool.get("name", "")),
                "description": fn.get("description", tool.get("description", "")),
                "parameters": fn.get("parameters", tool.get("parameters", {})),
            })
        else:
            result.append(tool)
    return result


def set_gen_ai_content_attributes(
    span: trace.Span,
    messages: Optional[List[Dict[str, Any]]] = None,
    tools: Optional[List[Dict[str, Any]]] = None,
    output_content: Optional[str] = None,
    output_tool_calls: Optional[List[Dict[str, Any]]] = None,
    finish_reason: str = "stop",
) -> None:
    """Set opt-in gen_ai content attributes on a span.

    Records the four opt-in attributes defined in the Azure AI Inference
    semantic conventions:
      - gen_ai.system_instructions  (extracted from system/developer messages)
      - gen_ai.input.messages       (non-system conversation history)
      - gen_ai.tool.definitions     (tools available to the model)
      - gen_ai.output.messages      (model-generated response)

    Nothing is recorded unless ``otel_genai_capture_message_content=true``
    (env: ``OTEL_GENAI_CAPTURE_MESSAGE_CONTENT``) because these attributes
    may contain sensitive PII data.

    Args:
        span: The active recording span.
        messages: Full message list sent to the model (chat + system roles).
        tools: Tool definitions provided to the model (OpenAI format).
        output_content: Accumulated text generated by the model.
        output_tool_calls: Tool calls requested by the model this round.
        finish_reason: Reason the model stopped ("stop", "tool_calls", etc.).
    """
    if not span or not span.is_recording():
        return
    if not _is_content_capture_enabled():
        return

    if messages:
        system_instructions = _build_system_instructions_schema(messages)
        if system_instructions:
            span.set_attribute(
                "gen_ai.system_instructions", json.dumps(system_instructions)
            )

        input_msgs = _build_input_messages_schema(messages)
        if input_msgs:
            span.set_attribute("gen_ai.input.messages", json.dumps(input_msgs))

    if tools:
        tool_defs = _build_tool_definitions_schema(tools)
        span.set_attribute("gen_ai.tool.definitions", json.dumps(tool_defs))

    if output_content is not None or output_tool_calls:
        output_msgs = _build_output_messages_schema(
            output_content or "", finish_reason, output_tool_calls
        )
        span.set_attribute("gen_ai.output.messages", json.dumps(output_msgs))


def setup_tracing(app: FastAPI) -> None:
    """
    Configure OpenTelemetry tracing with Jaeger (local) or Application Insights (production).
    Also enables LangSmith OTEL integration for LangGraph/LangChain tracing.
    
    Priority order:
    1. If Jaeger is enabled (local dev), use OTLP exporter → Jaeger
    2. If Application Insights is configured (production), use Azure Monitor exporter
    3. If neither is configured, skip tracing setup
    
    LangSmith Integration:
    - If LANGSMITH_OTEL_ENABLED=true, LangGraph/LangChain traces will be captured
    - Traces are sent to Jaeger (or App Insights) via the shared TracerProvider
    - Set LANGSMITH_OTEL_ONLY=true to prevent traces going to LangSmith cloud
    
    Args:
        app: FastAPI application instance
    """
    global _tracer
    tracer_configured = False
    
    try:
        # Configure LangSmith OTEL environment variables if enabled
        if settings.langsmith_otel_enabled:
            logger.info("🔍 Configuring LangSmith OpenTelemetry integration")
            
            # Enable LangSmith OTEL tracing
            os.environ["LANGSMITH_OTEL_ENABLED"] = "true"
            os.environ["LANGSMITH_TRACING"] = str(settings.langsmith_tracing).lower()
            
            # If OTEL_ONLY is true, traces won't be sent to LangSmith cloud (only Jaeger)
            os.environ["LANGSMITH_OTEL_ONLY"] = str(settings.langsmith_otel_only).lower()
            
            # Optional: Set LangSmith project name (default is "default")
            if settings.langsmith_project:
                os.environ["LANGSMITH_PROJECT"] = settings.langsmith_project
            
            # Optional: Set LangSmith API endpoint (for self-hosted or EU region)
            if settings.langsmith_endpoint:
                os.environ["LANGSMITH_ENDPOINT"] = settings.langsmith_endpoint
            
            # Optional: Set LangSmith API key (only if sending to LangSmith cloud)
            if settings.langsmith_api_key and not settings.langsmith_otel_only:
                os.environ["LANGSMITH_API_KEY"] = settings.langsmith_api_key
            
            logger.info(f"   LANGSMITH_OTEL_ENABLED=true")
            logger.info(f"   LANGSMITH_TRACING={os.environ['LANGSMITH_TRACING']}")
            logger.info(f"   LANGSMITH_OTEL_ONLY={os.environ['LANGSMITH_OTEL_ONLY']}")
            logger.info(f"   LANGSMITH_PROJECT={settings.langsmith_project}")
            
            # Initialize LangSmith client when OTEL_ONLY=false to enable dual export
            if not settings.langsmith_otel_only and settings.langsmith_api_key:
                try:
                    from langsmith import Client
                    ls_client = Client()
                    logger.info(f"✅ LangSmith client initialized for cloud export")
                    logger.info(f"   Project: {settings.langsmith_project}")
                except Exception as e:
                    logger.warning(f"⚠️  Failed to initialize LangSmith client: {e}")
                    logger.warning(f"   Traces will only be sent to OTEL backend")
        
        # Create resource with service identification
        resource = Resource.create({
            ResourceAttributes.SERVICE_NAME: settings.app_name,
            ResourceAttributes.SERVICE_VERSION: "1.0.0",
            ResourceAttributes.DEPLOYMENT_ENVIRONMENT: settings.environment,
        })
        
        # Set up tracer provider with resource attributes
        # This TracerProvider will be used by both FastAPI instrumentation AND LangSmith
        tracer_provider = TracerProvider(resource=resource)
        trace.set_tracer_provider(tracer_provider)
        
        # W3C Trace Context propagation is enabled by default in OpenTelemetry SDK
        # The SDK automatically uses W3C Trace Context (traceparent, tracestate) and Baggage
        logger.info("🔗 W3C Trace Context propagation enabled (default)")
        
        logger.info(f"🎯 OpenTelemetry resource: service={settings.app_name}, env={settings.environment}")
        
        # Configure Jaeger for local development (priority)
        if settings.enable_jaeger_tracing and settings.jaeger_endpoint:
            logger.info(f"🔍 Configuring Jaeger tracing at {settings.jaeger_endpoint}")
            
            otlp_exporter = OTLPSpanExporter(
                endpoint=settings.jaeger_endpoint,
                timeout=10,
            )
            
            # Wrap BatchSpanProcessor with FilteringSpanProcessor to remove noise
            batch_processor = BatchSpanProcessor(otlp_exporter)
            filtering_processor = FilteringSpanProcessor(batch_processor)
            tracer_provider.add_span_processor(filtering_processor)
            
            tracer_configured = True
            logger.info("✅ OpenTelemetry tracing configured with Jaeger (local dev)")
            logger.info("🔇 Filtering out ASGI response body event spans")
            
            if settings.langsmith_otel_enabled:
                if settings.langsmith_otel_only:
                    logger.info("✅ LangSmith OTEL integration enabled - LangGraph/LangChain traces → Jaeger only")
                else:
                    logger.info("✅ LangSmith OTEL integration enabled - LangGraph/LangChain traces → Jaeger + LangSmith cloud")
        
        # Configure Azure Monitor for production (fallback)
        elif settings.applicationinsights_connection_string:
            logger.info("🔍 Configuring Application Insights tracing")
            
            appinsights_exporter = AzureMonitorTraceExporter(
                connection_string=settings.applicationinsights_connection_string
            )
            
            # Wrap BatchSpanProcessor with FilteringSpanProcessor to remove noise
            batch_processor = BatchSpanProcessor(appinsights_exporter)
            filtering_processor = FilteringSpanProcessor(batch_processor)
            tracer_provider.add_span_processor(filtering_processor)
            
            tracer_configured = True
            logger.info("✅ OpenTelemetry tracing configured with Application Insights")
            logger.info("🔇 Filtering out ASGI response body event spans")
            
            if settings.langsmith_otel_enabled:
                if settings.langsmith_otel_only:
                    logger.info("✅ LangSmith OTEL integration enabled - LangGraph/LangChain traces → App Insights only")
                else:
                    logger.info("✅ LangSmith OTEL integration enabled - LangGraph/LangChain traces → App Insights + LangSmith cloud")
        
        else:
            logger.warning(
                "⚠️  No tracing backend configured. "
                "Set JAEGER_ENDPOINT for local dev or APPLICATIONINSIGHTS_CONNECTION_STRING for production."
            )
            return
        
        # Instrument FastAPI and HTTPX (applies to both backends)
        if tracer_configured:
            # Instrument FastAPI for automatic HTTP endpoint tracing
            FastAPIInstrumentor.instrument_app(
                app,
                server_request_hook=_server_request_hook,
                client_request_hook=None
            )
            logger.info("🔧 FastAPI instrumentation enabled")
            
            # Instrument HTTPX for automatic HTTP client tracing
            HTTPXClientInstrumentor().instrument()
            logger.info("🔧 HTTPX instrumentation enabled")
            
            # Initialize global tracer
            _tracer = trace.get_tracer(__name__)
            
            logger.info("✅ Tracing configured and ready")
    
    except Exception as e:
        logger.error(f"❌ Error setting up tracing: {e}", exc_info=True)


def _server_request_hook(span: trace.Span, scope: Dict[str, Any]) -> None:
    """Hook to add custom attributes to FastAPI request spans."""
    if span and span.is_recording():
        # Add custom attributes
        span.set_attribute("http.route", scope.get("path", ""))
        span.set_attribute("app.name", settings.app_name)


def _server_request_hook(span: trace.Span, scope: Dict[str, Any]) -> None:
    """Hook to add custom attributes to FastAPI request spans."""
    if span and span.is_recording():
        # Add custom attributes
        span.set_attribute("http.route", scope.get("path", ""))
        span.set_attribute("app.name", settings.app_name)


@contextmanager
def trace_graph_execution(graph_name: str, conversation_id: str, **attributes):
    """
    Context manager for tracing LangGraph execution.
    
    Args:
        graph_name: Name of the graph (ChatGraph, RAGGraph, AgentGraph)
        conversation_id: Conversation ID
        **attributes: Additional attributes to add to the span
    
    Example:
        with trace_graph_execution("ChatGraph", conv_id, model="gpt-5.2"):
            result = await graph.stream_chat(...)
    """
    if _tracer is None:
        yield None
        return
    
    with _tracer.start_as_current_span(f"graph.{graph_name.lower()}") as span:
        if span.is_recording():
            span.set_attribute("graph.name", graph_name)
            span.set_attribute("conversation.id", conversation_id)
            span.set_attribute("graph.type", "langgraph")
            
            for key, value in attributes.items():
                span.set_attribute(f"graph.{key}", str(value))
        
        try:
            yield span
        except Exception as e:
            if span.is_recording():
                span.set_status(Status(StatusCode.ERROR, str(e)))
                span.record_exception(e)
            raise


@contextmanager
def trace_thinking_process(step_number: int, effort: str = "unknown"):
    """
    Context manager for tracing thinking process steps.
    
    Args:
        step_number: Thinking step number
        effort: Reasoning effort level
    
    Example:
        with trace_thinking_process(step_num, effort="low") as span:
            # Process thinking step
            span.set_attribute("thinking.reasoning", reasoning_text[:200])
    """
    if _tracer is None:
        yield None
        return
    
    with _tracer.start_as_current_span(f"thinking.step_{step_number}") as span:
        if span.is_recording():
            span.set_attribute("thinking.step_number", step_number)
            span.set_attribute("thinking.effort", effort)
            span.set_attribute("operation.type", "thinking")
        
        try:
            yield span
        except Exception as e:
            if span.is_recording():
                span.set_status(Status(StatusCode.ERROR, str(e)))
                span.record_exception(e)
            raise


@contextmanager
def trace_tool_call(tool_name: str, **arguments):
    """
    Context manager for tracing tool/function calls.
    
    Args:
        tool_name: Name of the tool being called
        **arguments: Tool arguments
    
    Example:
        with trace_tool_call("web_search", query="weather") as span:
            result = await tool.execute()
            span.set_attribute("tool.result_count", len(results))
    """
    if _tracer is None:
        yield None
        return
    
    with _tracer.start_as_current_span(f"tool.{tool_name}") as span:
        if span.is_recording():
            span.set_attribute("tool.name", tool_name)
            span.set_attribute("operation.type", "tool_call")
            
            # Add sanitized arguments (limit size)
            for key, value in arguments.items():
                str_value = str(value)
                if len(str_value) > 200:
                    str_value = str_value[:200] + "..."
                span.set_attribute(f"tool.arg.{key}", str_value)
        
        try:
            yield span
        except Exception as e:
            if span.is_recording():
                span.set_status(Status(StatusCode.ERROR, str(e)))
                span.record_exception(e)
            raise


@contextmanager
def trace_llm_call(model: str, operation: str = "completion", **attributes):
    """
    Context manager for tracing LLM API calls.

    Sets standard gen_ai semantic convention attributes on the span in addition
    to legacy ``llm.*`` attributes for backward compatibility.
    Call :func:`set_gen_ai_content_attributes` on the yielded span to record
    the four opt-in content attributes (input/output messages, system
    instructions, tool definitions).

    Args:
        model: Model name (e.g., "gpt-5.2", "gpt-5-mini")
        operation: Type of operation ("completion", "embedding", "responses")
        **attributes: Additional attributes

    Example:
        with trace_llm_call("gpt-5.2", "responses", streaming=True) as span:
            response = await client.responses.create(...)
            set_gen_ai_content_attributes(span, messages=..., output_content=...)
    """
    if _tracer is None:
        yield None
        return

    # Map operation to gen_ai.operation.name well-known values
    _op_name_map = {"completion": "chat", "responses": "chat", "embedding": "embeddings"}
    gen_ai_op = _op_name_map.get(operation, operation)

    with _tracer.start_as_current_span(f"{gen_ai_op} {model}") as span:
        if span.is_recording():
            # Standard gen_ai semantic convention attributes
            span.set_attribute("gen_ai.operation.name", gen_ai_op)
            span.set_attribute("gen_ai.request.model", model)
            span.set_attribute("gen_ai.provider.name", "azure.ai.inference")
            span.set_attribute("azure.resource_provider.namespace", "Microsoft.CognitiveServices")

            # Legacy attributes (kept for backward compatibility)
            span.set_attribute("llm.model", model)
            span.set_attribute("llm.operation", operation)
            span.set_attribute("operation.type", "llm_call")

            for key, value in attributes.items():
                span.set_attribute(f"llm.{key}", str(value))

        try:
            yield span
        except Exception as e:
            if span.is_recording():
                span.set_status(Status(StatusCode.ERROR, str(e)))
                span.record_exception(e)
            raise


@contextmanager
def trace_database_operation(operation: str, table: str = "", **attributes):
    """
    Context manager for tracing database operations.
    
    Args:
        operation: Database operation (save, load, update, delete)
        table: Table/collection name
        **attributes: Additional attributes
    
    Example:
        with trace_database_operation("save", "conversations") as span:
            await repo.save_conversation(conv)
            span.set_attribute("db.record_id", conv.id)
    """
    if _tracer is None:
        yield None
        return
    
    with _tracer.start_as_current_span(f"db.{operation}") as span:
        if span.is_recording():
            span.set_attribute("db.operation", operation)
            if table:
                span.set_attribute("db.table", table)
            span.set_attribute("operation.type", "database")
            
            for key, value in attributes.items():
                span.set_attribute(f"db.{key}", str(value))
        
        try:
            yield span
        except Exception as e:
            if span.is_recording():
                span.set_status(Status(StatusCode.ERROR, str(e)))
                span.record_exception(e)
            raise


def trace_thinking_step(step_number: int, reasoning: str) -> None:
    """
    Legacy function: Trace a thinking step as a custom span.
    Deprecated: Use trace_thinking_process() context manager instead.
    
    Args:
        step_number: Step number
        reasoning: Reasoning text
    """
    if _tracer is None:
        return
    
    with _tracer.start_as_current_span(f"thinking_step_{step_number}") as span:
        if span.is_recording():
            span.set_attribute("step.number", step_number)
            span.set_attribute("step.reasoning", reasoning[:100])  # Limit length
            span.set_attribute("step.type", "thinking")
