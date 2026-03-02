import { NextRequest } from 'next/server'
import { withTracing, addSpanAttribute, addSpanEvent, recordSpanException } from '@/lib/tracing'
import { propagation, context } from '@opentelemetry/api'

// Backend service URL - uses Kubernetes internal DNS in production
const BACKEND_URL = 
  process.env.BACKEND_SERVICE_URL || 
  process.env.NEXT_PUBLIC_API_URL || 
  'http://localhost:8000'

/**
 * Proxy all API requests to the backend service
 * This implements the Backend-for-Frontend (BFF) pattern
 */
async function proxyToBackend(
  request: NextRequest,
  path: string[],
  method: string
) {
  const pathStr = path.join('/')
  const route = `/api/v1/${pathStr}`
  
  return withTracing(
    `proxy.${method.toUpperCase()} /api/v1/${pathStr}`,
    async (span) => {
      const url = new URL(route, BACKEND_URL)
      
      // Add trace attributes
      span?.setAttribute('http.method', method)
      span?.setAttribute('http.route', route)
      span?.setAttribute('http.target', url.toString())
      span?.setAttribute('backend.url', BACKEND_URL)
      
      // Copy query parameters
      const searchParams = request.nextUrl.searchParams
      searchParams.forEach((value, key) => {
        url.searchParams.append(key, value)
      })

      // Prepare headers
      const headers = new Headers()
      
      // Copy relevant headers from the original request
      const headersToForward = [
        'content-type',
        'authorization',
        'accept',
        'user-agent',
        'x-request-id',
        'traceparent',  // W3C Trace Context
        'tracestate',   // W3C Trace Context
      ]
      
      headersToForward.forEach((header) => {
        const value = request.headers.get(header)
        if (value) {
          headers.set(header, value)
        }
      })

      // Inject current trace context into headers for distributed tracing
      // This ensures the backend trace is linked to the frontend trace
      const carrier: Record<string, string> = {};
      propagation.inject(context.active(), carrier);
      
      // Add injected trace headers to the request
      Object.entries(carrier).forEach(([key, value]) => {
        if (!headers.has(key)) {  // Don't override if already forwarded
          headers.set(key, value);
        }
      });

      // Add X-Forwarded headers
      const clientIp = request.headers.get('x-forwarded-for') || 
                       request.headers.get('x-real-ip') || 
                       'unknown'
      headers.set('x-forwarded-for', clientIp)
      headers.set('x-forwarded-proto', request.nextUrl.protocol.replace(':', ''))
      headers.set('x-forwarded-host', request.nextUrl.host)

      try {
        addSpanEvent('proxy.request.start', { backend_url: url.toString() })
        
        // Forward the request to backend
        const backendResponse = await fetch(url.toString(), {
          method,
          headers,
          body: method !== 'GET' && method !== 'HEAD' 
            ? await request.text() 
            : undefined,
          // Don't set redirect: 'manual' for SSE streams
          // @ts-ignore - Next.js typing doesn't include duplex
          duplex: 'half',
        })

        // Add response status to trace
        addSpanAttribute('http.status_code', backendResponse.status)
        addSpanEvent('proxy.response.received', { 
          status: backendResponse.status,
          content_type: backendResponse.headers.get('content-type') || 'unknown'
        })

        // Handle SSE streams (text/event-stream)
        const contentType = backendResponse.headers.get('content-type')
        if (contentType?.includes('text/event-stream')) {
          addSpanAttribute('response.type', 'stream')
          addSpanEvent('proxy.stream.start')
          
          return new Response(backendResponse.body, {
            status: backendResponse.status,
            statusText: backendResponse.statusText,
            headers: {
              'Content-Type': 'text/event-stream',
              'Cache-Control': 'no-cache',
              'Connection': 'keep-alive',
              'X-Accel-Buffering': 'no', // Disable buffering for SSE
            },
          })
        }

        // Handle regular responses
        addSpanAttribute('response.type', 'json')
        const responseHeaders = new Headers()
        
        // Copy relevant response headers
        const responseHeadersToForward = [
          'content-type',
          'content-length',
          'cache-control',
          'etag',
          'last-modified',
        ]
        
        responseHeadersToForward.forEach((header) => {
          const value = backendResponse.headers.get(header)
          if (value) {
            responseHeaders.set(header, value)
          }
        })

    return new Response(backendResponse.body, {
      status: backendResponse.status,
      statusText: backendResponse.statusText,
      headers: responseHeaders,
    })
  } catch (error) {
    console.error('Backend proxy error:', error)
    recordSpanException(error as Error)
    addSpanAttribute('error', true)
    addSpanAttribute('error.type', 'proxy_error')
    
    return new Response(
      JSON.stringify({
        error: 'Backend service unavailable',
        message: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 502,
        headers: { 'Content-Type': 'application/json' },
      }
    )
  }
    },
    {
      'proxy.type': 'bff',
      'proxy.pattern': 'backend-for-frontend',
    }
  )
}

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const { path } = await params
  return proxyToBackend(request, path, 'GET')
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const { path } = await params
  return proxyToBackend(request, path, 'POST')
}

export async function PUT(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const { path } = await params
  return proxyToBackend(request, path, 'PUT')
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const { path } = await params
  return proxyToBackend(request, path, 'DELETE')
}

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const { path } = await params
  return proxyToBackend(request, path, 'PATCH')
}

// Configure route segment config
export const dynamic = 'force-dynamic'
export const runtime = 'nodejs'
