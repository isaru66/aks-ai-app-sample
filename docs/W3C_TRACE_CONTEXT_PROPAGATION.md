# W3C Trace Context Propagation

## Overview

This document explains how W3C Trace Context propagation is implemented in the AI Chat Application to enable distributed tracing across the frontend (Next.js) and backend (FastAPI) services.

## What is W3C Trace Context?

W3C Trace Context is a standard for propagating trace context information across service boundaries using HTTP headers. This enables distributed tracing, where a single user request can be tracked across multiple services, providing a complete view of the request flow.

### Key Headers

1. **`traceparent`**: Contains the trace ID, parent span ID, and sampling decision
   - Format: `00-{trace-id}-{parent-id}-{trace-flags}`
   - Example: `00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01`

2. **`tracestate`**: Vendor-specific trace information (optional)
   - Format: `key1=value1,key2=value2`

## Architecture

```
User Request
    ↓
┌─────────────────────────────────────┐
│  Frontend (Next.js)                 │
│  Service: ai-app-frontend           │
│                                     │
│  1. Receives request                │
│  2. Creates root span               │
│  3. Injects traceparent header  ←── │ W3C Propagation
│  4. Forwards to backend             │
└─────────────────┬───────────────────┘
                  │ HTTP with traceparent header
                  ↓
┌─────────────────────────────────────┐
│  Backend (FastAPI)                  │
│  Service: Azure AI Chat App         │
│                                     │
│  1. Extracts traceparent header ←── │ W3C Propagation
│  2. Creates child span              │
│  3. Executes LangGraph workflow     │
│  4. Returns response                │
└─────────────────────────────────────┘
```

## Implementation Details

### Backend (Python/FastAPI)

**Location**: `backend/app/utils/tracing.py`

#### Default W3C Support

The OpenTelemetry Python SDK includes W3C Trace Context propagation by default. No explicit configuration is required:

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider

# W3C Trace Context is the default propagator
tracer_provider = TracerProvider(resource=resource)
trace.set_tracer_provider(tracer_provider)
```

#### Automatic Propagation

FastAPI instrumentation automatically:
- **Extracts** `traceparent` and `tracestate` headers from incoming requests
- **Creates** child spans linked to the parent trace
- **Responds** with trace headers for client-side continuation

```python
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

# Automatically extracts W3C headers
FastAPIInstrumentor.instrument_app(app)
```

#### Configuration

Environment variables (optional):
```bash
# Explicitly set propagators (default includes tracecontext)
OTEL_PROPAGATORS=tracecontext,baggage
```

### Frontend (TypeScript/Next.js)

**Location**: `frontend/instrumentation.ts`, `frontend/src/app/api/v1/[...path]/route.ts`

#### Global Propagator Setup

```typescript
// frontend/instrumentation.ts
import { propagation } from '@opentelemetry/api';
import { W3CTraceContextPropagator } from '@opentelemetry/core';
import { W3CBaggagePropagator } from '@opentelemetry/core';
import { CompositePropagator } from '@opentelemetry/core';

// Configure W3C propagators globally
propagation.setGlobalPropagator(
  new CompositePropagator({
    propagators: [
      new W3CTraceContextPropagator(),   // traceparent, tracestate
      new W3CBaggagePropagator(),         // baggage
    ],
  })
);
```

#### Header Injection in BFF Proxy

The Backend-for-Frontend (BFF) proxy injects trace headers into requests to the backend:

```typescript
// frontend/src/app/api/v1/[...path]/route.ts
import { propagation, context } from '@opentelemetry/api';

async function proxyToBackend(request: NextRequest) {
  return withTracing('proxy-request', async (span) => {
    // 1. Forward existing W3C headers from client
    const headersToForward = [
      'traceparent',  // W3C Trace Context
      'tracestate',   // W3C Trace Context
      // ... other headers
    ];
    
    // 2. Inject current trace context into headers
    const carrier: Record<string, string> = {};
    propagation.inject(context.active(), carrier);
    
    // 3. Add injected headers to backend request
    Object.entries(carrier).forEach(([key, value]) => {
      if (!headers.has(key)) {
        headers.set(key, value);
      }
    });
    
    // 4. Forward request to backend with trace headers
    const backendResponse = await fetch(backendUrl, {
      method,
      headers,  // Contains traceparent + tracestate
      body,
    });
  });
}
```

## Trace Flow Example

### Step-by-Step Flow

1. **User makes request to Next.js frontend**:
   ```http
   GET http://localhost:3000/api/v1/health
   ```

2. **Frontend creates root span**:
   - Service: `ai-app-frontend`
   - Span: `proxy-request`
   - Trace ID: `4bf92f3577b34da6a3ce929d0e0e4736` (generated)

3. **Frontend injects trace headers**:
   ```http
   GET http://ai-app-backend:8000/api/v1/health
   traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
   ```

4. **Backend extracts trace context**:
   - Extracts trace ID: `4bf92f3577b34da6a3ce929d0e0e4736`
   - Extracts parent span ID: `00f067aa0ba902b7`
   - Creates child span with same trace ID

5. **Backend executes request**:
   - Service: `Azure AI Chat App`
   - Span: `GET /api/v1/health`
   - Parent: `proxy-request` (from frontend)

6. **View in Jaeger**:
   ```
   Trace: 4bf92f3577b34da6a3ce929d0e0e4736
   ├─ ai-app-frontend: proxy-request (35ms)
   │  └─ Azure AI Chat App: GET /api/v1/health (28ms)
   │     └─ database: query (5ms)
   ```

## Verification

### 1. Check Service Logs

**Backend**:
```bash
docker compose logs backend | grep "W3C"
```
Expected output:
```
🔗 W3C Trace Context propagation enabled (default)
```

**Frontend**:
```bash
docker compose logs frontend | grep "W3C"
```
Expected output:
```
🔗 W3C Trace Context propagation enabled
```

### 2. Inspect Network Requests

Use browser DevTools to inspect the frontend → backend request:

```http
Request Headers:
  traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
  tracestate: ...
```

### 3. View Traces in Jaeger UI

1. Open Jaeger UI: [http://localhost:16686](http://localhost:16686)
2. Select service: `ai-app-frontend`
3. Click **Find Traces**
4. Look for traces with spans from both services:
   - `ai-app-frontend` (root span)
   - `Azure AI Chat App` (child span)

#### Expected Result

A single trace should contain spans from both services, showing the complete request flow:

```
┌────────────────────────────────────────────────────────────┐
│ Trace: 4bf92f3577b34da6a3ce929d0e0e4736                    │
├────────────────────────────────────────────────────────────┤
│ ai-app-frontend                                            │
│   ├─ proxy-request (35ms)                                  │
│   │                                                         │
│ Azure AI Chat App                                          │
│   └─ GET /api/v1/health (28ms)                             │
│       ├─ database: connection pool (2ms)                   │
│       └─ database: query (5ms)                             │
└────────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Traces Not Linked

**Symptom**: Separate traces for frontend and backend

**Causes**:
1. Propagation not configured correctly
2. Headers not forwarded in proxy
3. Different trace IDs generated

**Solution**:
```bash
# 1. Verify propagators are set
docker compose logs frontend | grep "propagation enabled"
docker compose logs backend | grep "propagation enabled"

# 2. Check request headers contain traceparent
# Use browser DevTools Network tab

# 3. Restart both services
docker compose restart frontend backend
```

### Missing Spans

**Symptom**: Only frontend or backend spans visible

**Causes**:
1. Service not sending traces to Jaeger
2. OTLP endpoint misconfigured

**Solution**:
```bash
# 1. Verify OTLP endpoints
docker compose logs backend | grep "Jaeger"
docker compose logs frontend | grep "OTLP"

# 2. Check Jaeger is accessible
curl http://localhost:16686
```

### No Traces in Jaeger

**Causes**:
1. Jaeger not running
2. Sampling rate too low

**Solution**:
```bash
# 1. Verify Jaeger is running
docker compose ps jaeger

# 2. Check Jaeger logs
docker compose logs jaeger

# 3. Set sampling to always sample (development)
# In backend/app/utils/tracing.py:
# sampling_rate=1.0  # Always sample
```

## Configuration Reference

### Backend Environment Variables

```bash
# LangSmith OTEL (includes automatic W3C propagation)
LANGSMITH_OTEL_ENABLED=true
LANGSMITH_TRACING=true
LANGSMITH_OTEL_ONLY=true
LANGSMITH_PROJECT=ai-chat-app

# Jaeger OTLP endpoint
JAEGER_ENDPOINT=http://jaeger:4318/v1/traces
ENABLE_JAEGER_TRACING=true

# Optional: Explicit propagator configuration
OTEL_PROPAGATORS=tracecontext,baggage
```

### Frontend Environment Variables

```bash
# OTEL Configuration
ENABLE_OTEL_TRACING=true
OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4318/v1/traces
OTEL_SERVICE_NAME=ai-app-frontend

# Optional: Explicit propagator configuration
OTEL_PROPAGATORS=tracecontext,baggage
```

## Best Practices

### 1. Always Forward Trace Headers

When implementing proxies or middleware, always forward W3C trace headers:

```typescript
const w3cHeaders = ['traceparent', 'tracestate', 'baggage'];
w3cHeaders.forEach(header => {
  const value = request.headers.get(header);
  if (value) backendHeaders.set(header, value);
});
```

### 2. Use Consistent Service Names

Service names appear in Jaeger UI. Use descriptive, consistent names:
- Frontend: `ai-app-frontend`
- Backend: `Azure AI Chat App`
- Database: `postgresql`

### 3. Add Contextual Attributes

Add relevant attributes to spans for better debugging:

```typescript
span.setAttribute('http.method', 'GET');
span.setAttribute('http.url', request.url);
span.setAttribute('user.id', userId);
```

### 4. Sample Appropriately

Configure sampling based on environment:
- **Development**: 100% sampling (`sampling_rate=1.0`)
- **Staging**: 50% sampling (`sampling_rate=0.5`)
- **Production**: 1-10% sampling (`sampling_rate=0.01`)

## Resources

- [W3C Trace Context Specification](https://www.w3.org/TR/trace-context/)
- [OpenTelemetry Python SDK](https://opentelemetry-python.readthedocs.io/)
- [OpenTelemetry JavaScript SDK](https://opentelemetry.io/docs/instrumentation/js/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [LangSmith OTEL Integration](https://docs.langchain.com/langsmith/trace-with-opentelemetry)

## Related Documentation

- [Backend OTEL Tracing](./LANGSMITH_OTEL_TRACING.md) - LangSmith and LangGraph tracing
- [Frontend OTEL Tracing](./FRONTEND_OTEL_TRACING.md) - Next.js instrumentation
- [Copilot Instructions](../.github/copilot-instructions.md) - Architecture overview
