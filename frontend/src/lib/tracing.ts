/**
 * OpenTelemetry Tracing Utilities for Next.js
 * 
 * Helper functions for manual instrumentation of Next.js API routes,
 * server components, and server actions.
 * 
 * Usage in API Route:
 * ```typescript
 * import { withTracing } from '@/lib/tracing';
 * 
 * export async function GET(request: Request) {
 *   return withTracing('api.chat.get', async (span) => {
 *     span?.setAttribute('user.id', userId);
 *     // Your API logic here
 *     return Response.json({ data });
 *   });
 * }
 * ```
 * 
 * Usage in Server Component:
 * ```typescript
 * import { traceServerComponent } from '@/lib/tracing';
 * 
 * export default async function ChatPage() {
 *   return traceServerComponent('page.chat', async (span) => {
 *     // Your server component logic
 *     return <ChatUI />;
 *   });
 * }
 * ```
 */

import { trace, context, Span, SpanStatusCode } from '@opentelemetry/api';

const tracer = trace.getTracer('ai-app-frontend', '1.0.0');

/**
 * Checks if OpenTelemetry is properly initialized
 */
export function isTracingEnabled(): boolean {
  const provider = trace.getTracerProvider();
  // Check if we have a real provider (not NoopTracerProvider)
  return provider && typeof provider.getTracer === 'function';
}

/**
 * Wraps an async function with OpenTelemetry tracing
 * 
 * @param spanName - Name of the span (e.g., 'api.chat.completions')
 * @param fn - Async function to trace
 * @param attributes - Optional attributes to add to the span
 * @returns Result of the wrapped function
 */
export async function withTracing<T>(
  spanName: string,
  fn: (span: Span | undefined) => Promise<T>,
  attributes?: Record<string, string | number | boolean>
): Promise<T> {
  if (!isTracingEnabled()) {
    // If tracing is not enabled, just execute the function
    return fn(undefined);
  }

  return tracer.startActiveSpan(spanName, async (span) => {
    try {
      // Add custom attributes
      if (attributes) {
        Object.entries(attributes).forEach(([key, value]) => {
          span.setAttribute(key, value);
        });
      }

      // Execute the function
      const result = await fn(span);

      // Mark span as successful
      span.setStatus({ code: SpanStatusCode.OK });
      
      return result;
    } catch (error) {
      // Record the error
      span.recordException(error as Error);
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error instanceof Error ? error.message : 'Unknown error',
      });
      
      throw error;
    } finally {
      // End the span
      span.end();
    }
  });
}

/**
 * Traces a Server Component
 * 
 * @param componentName - Name of the component (e.g., 'page.chat')
 * @param fn - Async component function
 * @returns Component result
 */
export async function traceServerComponent<T>(
  componentName: string,
  fn: (span: Span | undefined) => Promise<T>
): Promise<T> {
  return withTracing(`component.${componentName}`, fn, {
    'component.type': 'server',
    'next.runtime': 'nodejs',
  });
}

/**
 * Traces a Server Action
 * 
 * @param actionName - Name of the action (e.g., 'chat.send-message')
 * @param fn - Async action function
 * @returns Action result
 */
export async function traceServerAction<T>(
  actionName: string,
  fn: (span: Span | undefined) => Promise<T>
): Promise<T> {
  return withTracing(`action.${actionName}`, fn, {
    'action.type': 'server',
  });
}

/**
 * Traces an API route handler
 * 
 * @param route - Route path (e.g., '/api/v1/chat/completions')
 * @param method - HTTP method
 * @param fn - Async handler function
 * @returns Handler result
 */
export async function traceAPIRoute<T>(
  route: string,
  method: string,
  fn: (span: Span | undefined) => Promise<T>
): Promise<T> {
  return withTracing(`http.${method.toUpperCase()} ${route}`, fn, {
    'http.method': method.toUpperCase(),
    'http.route': route,
    'http.target': route,
  });
}

/**
 * Creates a child span within the current context
 * 
 * @param spanName - Name of the child span
 * @param fn - Function to execute within the child span
 * @returns Result of the function
 */
export async function withChildSpan<T>(
  spanName: string,
  fn: (span: Span | undefined) => Promise<T>,
  attributes?: Record<string, string | number | boolean>
): Promise<T> {
  if (!isTracingEnabled()) {
    return fn(undefined);
  }

  return tracer.startActiveSpan(spanName, async (span) => {
    try {
      if (attributes) {
        Object.entries(attributes).forEach(([key, value]) => {
          span.setAttribute(key, value);
        });
      }

      const result = await fn(span);
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (error) {
      span.recordException(error as Error);
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error instanceof Error ? error.message : 'Unknown error',
      });
      throw error;
    } finally {
      span.end();
    }
  });
}

/**
 * Adds an attribute to the current active span
 * 
 * @param key - Attribute key
 * @param value - Attribute value
 */
export function addSpanAttribute(
  key: string,
  value: string | number | boolean
): void {
  const span = trace.getActiveSpan();
  if (span) {
    span.setAttribute(key, value);
  }
}

/**
 * Adds an event to the current active span
 * 
 * @param name - Event name
 * @param attributes - Optional event attributes
 */
export function addSpanEvent(
  name: string,
  attributes?: Record<string, string | number | boolean>
): void {
  const span = trace.getActiveSpan();
  if (span) {
    span.addEvent(name, attributes);
  }
}

/**
 * Records an exception in the current active span
 * 
 * @param error - The error to record
 */
export function recordSpanException(error: Error): void {
  const span = trace.getActiveSpan();
  if (span) {
    span.recordException(error);
    span.setStatus({
      code: SpanStatusCode.ERROR,
      message: error.message,
    });
  }
}
