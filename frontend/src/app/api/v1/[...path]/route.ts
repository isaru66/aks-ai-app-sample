import { NextRequest } from 'next/server'

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
  const url = new URL(`/api/v1/${pathStr}`, BACKEND_URL)
  
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
  ]
  
  headersToForward.forEach((header) => {
    const value = request.headers.get(header)
    if (value) {
      headers.set(header, value)
    }
  })

  // Add X-Forwarded headers
  const clientIp = request.headers.get('x-forwarded-for') || 
                   request.headers.get('x-real-ip') || 
                   'unknown'
  headers.set('x-forwarded-for', clientIp)
  headers.set('x-forwarded-proto', request.nextUrl.protocol.replace(':', ''))
  headers.set('x-forwarded-host', request.nextUrl.host)

  try {
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

    // Handle SSE streams (text/event-stream)
    const contentType = backendResponse.headers.get('content-type')
    if (contentType?.includes('text/event-stream')) {
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
