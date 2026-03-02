# LangSmith OpenTelemetry Tracing with Jaeger

This document explains how LangSmith OpenTelemetry tracing is configured in the backend to capture LangGraph/LangChain execution traces and send them to Jaeger.

## Overview

The application now supports automatic tracing of LangGraph and LangChain operations using OpenTelemetry. All traces are sent to Jaeger for visualization and analysis.

### What Gets Traced

- **LangGraph workflows**: ChatGraph, RAGGraph, AgentGraph execution
- **LangChain operations**: LLM calls, chain executions, tool invocations
- **FastAPI endpoints**: HTTP request/response cycles
- **HTTPX client calls**: External API requests
- **Custom spans**: Thinking steps, database operations

## Architecture

```
LangGraph/LangChain → LangSmith OTEL → OpenTelemetry TracerProvider → Jaeger
                                                ↓
                                    FastAPI/HTTPX instrumentation
```

## Configuration

### Environment Variables

Add these to your `.env` file or `docker-compose.yml`:

```bash
# Jaeger Backend
JAEGER_ENDPOINT=http://jaeger:4318/v1/traces
ENABLE_JAEGER_TRACING=true

# LangSmith OpenTelemetry Integration
LANGSMITH_OTEL_ENABLED=true           # Enable OTEL tracing for LangGraph/LangChain
LANGSMITH_TRACING=true                # Enable LangSmith tracing
LANGSMITH_OTEL_ONLY=true              # Send only to Jaeger, not LangSmith cloud
LANGSMITH_PROJECT=ai-chat-app         # Project name for trace organization

# Optional: For sending to LangSmith cloud (set LANGSMITH_OTEL_ONLY=false)
# LANGSMITH_ENDPOINT=https://api.smith.langchain.com
# LANGSMITH_API_KEY=your-api-key
```

### Docker Compose Configuration

The `docker-compose.yml` already includes:

- **Jaeger All-in-One** service with OTLP receiver
- **Backend** service with LangSmith OTEL environment variables

```yaml
jaeger:
  image: jaegertracing/jaeger:2.15.1
  ports:
    - "16686:16686"  # Jaeger UI
    - "4318:4318"    # OTLP HTTP receiver
    - "4317:4317"    # OTLP gRPC receiver
```

## How It Works

### 1. Initialization (`app/utils/tracing.py`)

When the FastAPI application starts:

1. **LangSmith OTEL environment variables** are set programmatically
2. **OpenTelemetry TracerProvider** is created with service metadata
3. **OTLP Exporter** is configured to send traces to Jaeger
4. **LangSmith detects** the global TracerProvider and uses it automatically
5. **FastAPI and HTTPX** are instrumented for automatic HTTP tracing

### 2. Automatic Tracing

Once configured, traces are automatically captured for:

- **LangGraph workflows**: State transitions, node executions
- **LangChain chains**: Prompts, LLM calls, tool usage
- **OpenAI API calls**: Using the Responses API with thinking
- **Database operations**: PostgreSQL queries (when using custom spans)

### 3. Custom Spans

The application provides helper context managers for custom tracing:

```python
from app.utils.tracing import (
    trace_graph_execution,
    trace_llm_call,
    trace_thinking_process,
    trace_tool_call,
    trace_database_operation
)

# Example: Trace a graph execution
with trace_graph_execution("ChatGraph", conversation_id, model="gpt-5.2"):
    result = await graph.stream_chat(...)

# Example: Trace an LLM call
with trace_llm_call("gpt-5.2", "responses", streaming=True) as span:
    response = await client.responses.create(...)
    span.set_attribute("llm.response_tokens", token_count)
```

## Viewing Traces

### Jaeger UI

1. Open the Jaeger UI: **http://localhost:16686**
2. Select **Service**: `Azure AI Chat App`
3. Click **Find Traces**

### Trace Structure

A typical chat request trace contains:

```
POST /api/v1/chat/completions
├── graph.chatgraph
│   ├── llm.responses
│   │   ├── thinking.step_1
│   │   ├── thinking.step_2
│   │   └── thinking.step_N
│   └── db.save (conversation)
└── http.response
```

### Trace Attributes

Each span includes attributes for filtering and analysis:

| Attribute | Description | Example |
|-----------|-------------|---------|
| `service.name` | Service identifier | `Azure AI Chat App` |
| `deployment.environment` | Environment | `dev`, `production` |
| `graph.name` | LangGraph workflow | `ChatGraph`, `RAGGraph` |
| `llm.model` | Model name | `gpt-5.2`, `gpt-5-mini` |
| `conversation.id` | Conversation ID | `conv_abc123` |
| `thinking.effort` | Reasoning effort | `low`, `medium`, `high` |
| `http.method` | HTTP method | `POST` |
| `http.status_code` | HTTP status | `200`, `500` |

## LangSmith Integration Details

### What is LANGSMITH_OTEL_ONLY?

- **`true`** (default): Traces are **only** sent to Jaeger via OTLP. LangSmith SDK will not attempt to send traces to LangSmith cloud.
- **`false`**: Traces are sent to **both** Jaeger and LangSmith cloud (requires `LANGSMITH_API_KEY`).

### Supported Attributes

LangSmith automatically maps standard OpenTelemetry attributes to LangSmith fields:

- **GenAI attributes**: `gen_ai.system`, `gen_ai.request.model`, `gen_ai.usage.total_tokens`
- **LangSmith attributes**: `langsmith.span.kind`, `langsmith.trace.name`, `langsmith.metadata.*`
- **Custom metadata**: Any attribute prefixed with `langsmith.metadata.` becomes metadata in LangSmith

See the [LangChain OpenTelemetry documentation](https://docs.langchain.com/langsmith/trace-with-opentelemetry) for full attribute mapping.

## Troubleshooting

### Traces Not Appearing

1. **Check Jaeger is running**:
   ```bash
   docker compose ps jaeger
   ```

2. **Verify environment variables**:
   ```bash
   docker compose exec backend env | grep LANGSMITH
   ```

3. **Check backend logs**:
   ```bash
   docker compose logs backend | grep -i "otel\|tracing\|langsmith"
   ```

   You should see:
   ```
   🔍 Configuring LangSmith OpenTelemetry integration
   LANGSMITH_OTEL_ENABLED=true
   ✅ LangSmith OTEL integration enabled - LangGraph/LangChain traces → Jaeger
   ```

4. **Test with a simple request**:
   ```bash
   curl -X POST http://localhost:8000/api/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{"messages": [{"role": "user", "content": "Hello"}]}'
   ```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| No traces in Jaeger | `LANGSMITH_OTEL_ENABLED=false` | Set to `true` and restart backend |
| Missing LangGraph traces | Package not installed | Run `pip install "langsmith[otel]>=0.4.25"` |
| Connection refused | Jaeger not running | Start Jaeger: `docker compose up -d jaeger` |
| ASGI noise spans | No filtering | Already filtered by `FilteringSpanProcessor` |

## Performance Considerations

- **Sampling**: By default, all traces are captured. For production, consider implementing sampling.
- **Batch processing**: Spans are batched before export to reduce overhead.
- **Filtering**: ASGI response body events are filtered out to reduce noise.
- **Async export**: Span export happens asynchronously and doesn't block requests.

## Switching to LangSmith Cloud

To send traces to LangSmith cloud instead of (or in addition to) Jaeger:

1. Create a LangSmith account at [smith.langchain.com](https://smith.langchain.com)
2. Get your API key from the settings page
3. Update environment variables:
   ```bash
   LANGSMITH_OTEL_ENABLED=true
   LANGSMITH_TRACING=true
   LANGSMITH_OTEL_ONLY=false            # Enable LangSmith cloud
   LANGSMITH_ENDPOINT=https://api.smith.langchain.com
   LANGSMITH_API_KEY=your-api-key-here
   LANGSMITH_PROJECT=ai-chat-app
   ```
4. Restart the backend

**Note**: With `LANGSMITH_OTEL_ONLY=false`, traces will be sent to **both** Jaeger and LangSmith.

## References

- [LangChain OpenTelemetry Documentation](https://docs.langchain.com/langsmith/trace-with-opentelemetry)
- [OpenTelemetry Python SDK](https://opentelemetry.io/docs/instrumentation/python/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/latest/)
- [LangSmith Documentation](https://docs.smith.langchain.com/)

## Next Steps

1. **Explore Jaeger UI**: http://localhost:16686
2. **Test with chat requests**: Make API calls and watch traces appear
3. **Add custom spans**: Use the provided context managers in your code
4. **Set up alerts**: Configure Jaeger alerts for error conditions
5. **Optimize sampling**: Implement sampling for high-traffic production environments
