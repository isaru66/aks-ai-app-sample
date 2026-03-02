# Next.js Frontend OpenTelemetry Tracing

This document explains the OpenTelemetry tracing setup for the Next.js frontend application.

## Overview

The Next.js frontend now supports OpenTelemetry tracing for server-side operations:
- **API Route Proxies** (BFF pattern)
- **Server Components** (when manually instrumented)
- **Server Actions** (when manually instrumented)

All traces are sent to Jaeger and appear alongside backend traces for full distributed tracing.

## Configuration

### Environment Variables

Set these in `.env` or `docker-compose.yml`:

```bash
ENABLE_OTEL_TRACING=true
OTEL_EXPORTER_OTLP_ENDPOINT=http://jaeger:4318/v1/traces
OTEL_SERVICE_NAME=ai-app-frontend
ENVIRONMENT=development
```

### Files

1. **[instrumentation.ts](../frontend/instrumentation.ts)** - Next.js instrumentation hook (auto-loaded)
2. **[lib/tracing.ts](../frontend/src/lib/tracing.ts)** - Helper utilities for manual instrumentation
3. **[next.config.ts](../frontend/next.config.ts)** - Next.js configuration (instrumentation enabled by default in v15+)

## What Gets Traced

### Automatic Tracing

The API proxy at `/api/v1/[...path]` is automatically traced with:
- HTTP method and route
- Backend URL
- Response status
- Stream detection (SSE)
- Error handling

### Manual Tracing

Use the helper functions from `@/lib/tracing`:

#### API Route Example

```typescript
import { withTracing } from '@/lib/tracing';

export async function GET(request: Request) {
  return withTracing('api.custom.get', async (span) => {
    span?.setAttribute('user.id', userId);
    // Your logic here
    return Response.json({ data });
  });
}
```

#### Server Component Example

```typescript
import { traceServerComponent } from '@/lib/tracing';

export default async function MyPage() {
  return traceServerComponent('page.my-page', async (span) => {
    span?.setAttribute('page.loaded', true);
    const data = await fetchData();
    return <UI data={data} />;
  });
}
```

#### Server Action Example

```typescript
import { traceServerAction } from '@/lib/tracing';

export async function submitForm(formData: FormData) {
  'use server';
  
  return traceServerAction('form.submit', async (span) => {
    span?.setAttribute('form.fields', formData.keys().length);
    // Process form
  });
}
```

## Viewing Traces

Open Jaeger UI at **http://localhost:16686**

### Frontend Traces Show

- **Service**: `ai-app-frontend`
- **Operations**: 
  - `proxy.POST /api/v1/chat/completions`
  - `proxy.GET /api/v1/conversations`
  - Custom instrumented operations

### Distributed Tracing

Frontend and backend traces are linked in Jaeger:

```
Frontend: proxy.POST /api/v1/chat/completions
    └── Backend: POST /api/v1/chat/completions
            └── graph.chatgraph
                ├── llm.responses
                │   ├── thinking.step_1
                │   └── thinking.step_2
                └── db.save
```

## Helper Functions

### `withTracing(spanName, fn, attributes?)`
General-purpose tracing wrapper for any async function.

### `traceServerComponent(name, fn)`
Specifically for Next.js Server Components.

### `traceServerAction(name, fn)`
Specifically for Server Actions.

### `traceAPIRoute(route, method, fn)`
Specifically for API route handlers.

### `addSpanAttribute(key, value)`
Add attribute to current active span.

### `addSpanEvent(name, attributes?)`
Add event to current active span.

### `recordSpanException(error)`
Record an exception in the current span.

## Client-Side Tracing

**Note**: OpenTelemetry currently only runs server-side in this setup. Client-side React components are not traced. For client-side observability, consider:

- Browser-specific OTEL instrumentations
- Real User Monitoring (RUM) tools
- Custom client-side logging

## Architecture

```
Browser → Next.js Frontend (Server) → Backend (FastAPI)
          ↓ (OTEL traces)              ↓ (OTEL traces)
          Jaeger ←─────────────────── Jaeger
```

Both services send traces to the same Jaeger instance, creating unified distributed traces.

## Performance Impact

- **Minimal overhead**: OTEL uses async batch export
- **No client impact**: Only server-side operations are traced
- **Selective tracing**: Instrument only critical paths

## Troubleshooting

### No Frontend Traces in Jaeger

1. **Check env vars**:
   ```bash
   docker compose exec frontend env | grep OTEL
   ```

2. **Check logs**:
   ```bash
   docker compose logs frontend | grep -i "opentelemetry\|otel"
   ```

   You should see:
   ```
   🎯 OpenTelemetry resource: { service: 'ai-app-frontend', ... }
   🔍 Configuring OTLP exporter: http://jaeger:4318/v1/traces
   ✅ OpenTelemetry instrumentation initialized
   ```

3. **Verify instrumentation.ts loads**:
   - Next.js 15+ automatically loads `instrumentation.ts`
   - Check for any module import errors in logs

### Traces Not Linking Frontend → Backend

- Ensure both services send to the same Jaeger instance
- Check that trace context is propagated in HTTP headers
- Verify no middleware strips trace headers

## Differences from Backend Tracing

| Feature | Backend (Python) | Frontend (Node.js) |
|---------|-----------------|-------------------|
| Auto-instrumentation | ✅ FastAPI, HTTPX, LangGraph | ⚠️ Manual only |
| LangSmith OTEL | ✅ Yes | ❌ N/A |
| Client-side | ❌ N/A | ❌ Not implemented |
| SSE Streaming | ✅ Fully traced | ✅ Proxy traced |

## Next Steps

1. **Test the setup**: Make API calls through the frontend
2. **View in Jaeger**: Check traces at http://localhost:16686
3. **Add custom spans**: Instrument critical components
4. **Monitor performance**: Use traces to identify bottlenecks

## References

- [Next.js Instrumentation](https://nextjs.org/docs/app/building-your-application/optimizing/instrumentation)
- [OpenTelemetry JavaScript](https://opentelemetry.io/docs/instrumentation/js/)
- [Backend Tracing Guide](./LANGSMITH_OTEL_TRACING.md)
