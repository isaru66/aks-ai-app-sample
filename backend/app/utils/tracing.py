import time
import os
from contextlib import contextmanager
from typing import Optional, Dict, Any
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
                logger.info("✅ LangSmith OTEL integration enabled - LangGraph/LangChain traces → Jaeger")
        
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
                logger.info("✅ LangSmith OTEL integration enabled - LangGraph/LangChain traces → App Insights")
        
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
    
    Args:
        model: Model name (e.g., "gpt-5.2", "gpt-5-mini")
        operation: Type of operation ("completion", "embedding", "responses")
        **attributes: Additional attributes
    
    Example:
        with trace_llm_call("gpt-5.2", "responses", streaming=True) as span:
            response = await client.responses.create(...)
            span.set_attribute("llm.response_tokens", token_count)
    """
    if _tracer is None:
        yield None
        return
    
    with _tracer.start_as_current_span(f"llm.{operation}") as span:
        if span.is_recording():
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
