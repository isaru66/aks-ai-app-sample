from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from azure.monitor.opentelemetry.exporter import AzureMonitorTraceExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from fastapi import FastAPI
from app.core.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)


def setup_tracing(app: FastAPI) -> None:
    """
    Configure OpenTelemetry tracing with Application Insights.
    
    Args:
        app: FastAPI application instance
    """
    if not settings.applicationinsights_connection_string:
        logger.warning("Application Insights not configured, skipping tracing setup")
        return
    
    try:
        # Set up tracer provider
        trace.set_tracer_provider(TracerProvider())
        
        # Configure Azure Monitor exporter
        exporter = AzureMonitorTraceExporter(
            connection_string=settings.applicationinsights_connection_string
        )
        
        # Add span processor
        trace.get_tracer_provider().add_span_processor(
            BatchSpanProcessor(exporter)
        )
        
        # Instrument FastAPI
        FastAPIInstrumentor.instrument_app(app)
        
        logger.info("✅ OpenTelemetry tracing configured with Application Insights")
    
    except Exception as e:
        logger.error(f"Error setting up tracing: {e}", exc_info=True)


def trace_thinking_step(step_number: int, reasoning: str) -> None:
    """
    Trace a thinking step as a custom span.
    
    Args:
        step_number: Step number
        reasoning: Reasoning text
    """
    tracer = trace.get_tracer(__name__)
    
    with tracer.start_as_current_span(f"thinking_step_{step_number}") as span:
        span.set_attribute("step.number", step_number)
        span.set_attribute("step.reasoning", reasoning[:100])  # Limit length
        span.set_attribute("step.type", "thinking")
