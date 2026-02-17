import { EventSourceParserStream } from 'eventsource-parser/stream'
import type { StreamChunk, ChatMessage, ReasoningEffort, Verbosity } from '@/types/chat'

export interface StreamOptions {
  onThinking?: (step: StreamChunk) => void
  onContent?: (chunk: StreamChunk) => void
  onDone?: (metadata: any) => void
  onError?: (error: string) => void
}

export interface StreamChatParams {
  showThinking?: boolean
  reasoningEffort?: ReasoningEffort
  verbosity?: Verbosity
}

export async function* streamChat(
  messages: ChatMessage[],
  options: StreamOptions = {},
  signal?: AbortSignal,
  params: StreamChatParams = {},
): AsyncGenerator<StreamChunk> {
  // Use relative URL - proxied through Next.js API route
  const url = '/api/v1/chat/completions'

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'text/event-stream',
    },
    body: JSON.stringify({
      messages,
      show_thinking: params.showThinking ?? true,
      stream: true,
      reasoning_effort: params.reasoningEffort ?? 'medium',
      verbosity: params.verbosity ?? 'medium',
    }),
    signal,
  })

  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`)
  }

  if (!response.body) {
    throw new Error('No response body')
  }

  // Parse SSE stream
  const stream = response.body
    .pipeThrough(new TextDecoderStream())
    .pipeThrough(new EventSourceParserStream())

  const reader = stream.getReader()

  try {
    while (true) {
      const { done, value } = await reader.read()

      if (done) {
        break
      }

      if (value.data) {
        try {
          const chunk: StreamChunk = JSON.parse(value.data)

          // Call appropriate callback
          switch (chunk.type) {
            case 'thinking':
              options.onThinking?.(chunk)
              break
            case 'content':
              options.onContent?.(chunk)
              break
            case 'done':
              options.onDone?.(chunk.metadata)
              break
            case 'error':
              options.onError?.(chunk.content)
              break
          }

          yield chunk
        } catch (e) {
          console.error('Error parsing SSE data:', e)
        }
      }
    }
  } catch (error: any) {
    // Check if this is an abort error (user clicked stop)
    if (error.name === 'AbortError' || error instanceof DOMException) {
      // Gracefully handle abort - this is expected behavior
      return
    }
    // Re-throw other errors
    throw error
  } finally {
    reader.releaseLock()
  }
}

export async function* streamRAGQuery(
  query: string,
  options: StreamOptions = {}
): AsyncGenerator<StreamChunk> {
  // Use relative URL - proxied through Next.js API route
  const url = '/api/v1/rag/query'

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'text/event-stream',
    },
    body: JSON.stringify({
      query,
      show_thinking: true,
    }),
  })

  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`)
  }

  if (!response.body) {
    throw new Error('No response body')
  }

  const stream = response.body
    .pipeThrough(new TextDecoderStream())
    .pipeThrough(new EventSourceParserStream())

  const reader = stream.getReader()

  try {
    while (true) {
      const { done, value } = await reader.read()

      if (done) {
        break
      }

      if (value.data) {
        try {
          const chunk: StreamChunk = JSON.parse(value.data)

          switch (chunk.type) {
            case 'thinking':
              options.onThinking?.(chunk)
              break
            case 'content':
              options.onContent?.(chunk)
              break
            case 'done':
              options.onDone?.(chunk.metadata)
              break
            case 'error':
              options.onError?.(chunk.content)
              break
          }

          yield chunk
        } catch (e) {
          console.error('Error parsing SSE data:', e)
        }
      }
    }
  } catch (error: any) {
    // Check if this is an abort error (user clicked stop)
    if (error.name === 'AbortError' || error instanceof DOMException) {
      // Gracefully handle abort - this is expected behavior
      return
    }
    // Re-throw other errors
    throw error
  } finally {
    reader.releaseLock()
  }
}
