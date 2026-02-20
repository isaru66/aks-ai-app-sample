import { useState, useCallback, useRef } from 'react'
import { streamChat } from '@/lib/stream-client'
import { useWordBuffer } from '@/hooks/use-word-buffer'
import type { ChatMessage, ThinkingStep, StreamChunk, MessageRole, ReasoningEffort, Verbosity, MCPServerPayload, ModelId } from '@/types/chat'

export interface UseChatOptions {
  onThinkingStep?: (step: ThinkingStep) => void
  onContentChunk?: (content: string) => void
  onComplete?: (sessionId: string) => void
  onError?: (error: string) => void
  /** Active MCP server configurations to forward to the backend */
  mcpServers?: MCPServerPayload[]
}

export function useChat(options: UseChatOptions = {}) {
  const [messages, setMessages] = useState<ChatMessage[]>([])
  const [isStreaming, setIsStreaming] = useState(false)
  const [currentThinkingSteps, setCurrentThinkingSteps] = useState<ThinkingStep[]>([])
  const [currentContent, setCurrentContent] = useState('')
  const [sessionId, setSessionId] = useState<string>()
  const [reasoningEffort, setReasoningEffort] = useState<ReasoningEffort>('low')
  const [verbosity, setVerbosity] = useState<Verbosity>('low')
  const [showThinking, setShowThinking] = useState(true)
  const [model, setModel] = useState<ModelId>('gpt-5-mini')
  const abortControllerRef = useRef<AbortController | null>(null)

  // Refs for collecting the full raw content (for storage) and thinking steps
  const rawContentRef = useRef<string[]>([])
  const thinkingStepsRef = useRef<ThinkingStep[]>([])
  const rafIdRef = useRef<number | null>(null)

  // Adaptive word-by-word buffer drives the visible currentContent
  const wordBuffer = useWordBuffer((visibleText) => {
    setCurrentContent(visibleText)
  })

  const sendMessage = useCallback(
    async (content: string) => {
      if (isStreaming) {
        console.warn('Already streaming, ignoring new message')
        return
      }

      // Add user message
      const userMessage: ChatMessage = {
        role: 'user' as MessageRole,
        content,
        timestamp: new Date().toISOString(),
      }

      setMessages((prev) => [...prev, userMessage])
      setIsStreaming(true)
      setCurrentThinkingSteps([])
      setCurrentContent('')

      // Create abort controller
      abortControllerRef.current = new AbortController()

      // Reset refs and word buffer for this stream
      rawContentRef.current = []
      thinkingStepsRef.current = []
      if (rafIdRef.current) cancelAnimationFrame(rafIdRef.current)
      rafIdRef.current = null
      wordBuffer.reset()

      // Schedule a batched React state update for thinking steps (at most once per frame)
      const scheduleThinkingFlush = () => {
        if (rafIdRef.current !== null) return
        rafIdRef.current = requestAnimationFrame(() => {
          rafIdRef.current = null
          setCurrentThinkingSteps([...thinkingStepsRef.current])
        })
      }

      try {
        // Stream chat response
        for await (const chunk of streamChat([...messages, userMessage], {
          onThinking: (step) => {
            const thinkingStep: ThinkingStep = {
              reasoning: step.content,
              timestamp: step.timestamp,
              metadata: step.metadata,
            }

            thinkingStepsRef.current.push(thinkingStep)
            scheduleThinkingFlush()
            options.onThinkingStep?.(thinkingStep)
          },

          onContent: (chunk) => {
            // Accumulate raw content for final message storage
            rawContentRef.current.push(chunk.content)
            // Feed the adaptive word buffer (renders word-by-word)
            wordBuffer.push(chunk.content)
            options.onContentChunk?.(chunk.content)
          },

          onDone: (metadata) => {
            // Flush any pending thinking RAF
            if (rafIdRef.current) {
              cancelAnimationFrame(rafIdRef.current)
              rafIdRef.current = null
            }

            // Flush remaining buffered words instantly
            const finalContent = wordBuffer.flush()

            const assistantMessage: ChatMessage = {
              role: 'assistant' as MessageRole,
              content: finalContent || rawContentRef.current.join(''),
              thinking_steps: thinkingStepsRef.current.length > 0 ? [...thinkingStepsRef.current] : undefined,
              timestamp: new Date().toISOString(),
            }

            setMessages((prev) => [...prev, assistantMessage])
            setCurrentThinkingSteps([])
            setCurrentContent('')
            setIsStreaming(false)

            const newSessionId = metadata?.session_id
            if (newSessionId) {
              setSessionId(newSessionId)
              options.onComplete?.(newSessionId)
            }
          },

          onError: (error) => {
            console.error('Stream error:', error)
            setIsStreaming(false)
            setCurrentThinkingSteps([])
            setCurrentContent('')
            options.onError?.(error)
          },
        }, abortControllerRef.current?.signal, {
          showThinking,
          reasoningEffort,
          verbosity,
          mcpServers: options.mcpServers,
          model,
        })) {
          // Stream is being processed through callbacks
        }
      } catch (error: any) {
        // Ignore abort errors - this is expected when user clicks stop
        if (error.name === 'AbortError' || error instanceof DOMException) {
          console.log('Stream aborted by user')
          return
        }
        
        console.error('Error in sendMessage:', error)
        setIsStreaming(false)
        setCurrentThinkingSteps([])
        setCurrentContent('')
        options.onError?.(error instanceof Error ? error.message : 'Unknown error')
      }
    },
    [messages, isStreaming, options, showThinking, reasoningEffort, verbosity, model]
  )

  const stopStreaming = useCallback(() => {
    if (abortControllerRef.current) {
      abortControllerRef.current.abort()
      abortControllerRef.current = null
    }
    if (rafIdRef.current) {
      cancelAnimationFrame(rafIdRef.current)
      rafIdRef.current = null
    }
    wordBuffer.reset()
    setIsStreaming(false)
    setCurrentThinkingSteps([])
    setCurrentContent('')
  }, [])

  const clearMessages = useCallback(() => {
    setMessages([])
    setCurrentThinkingSteps([])
    setCurrentContent('')
    setSessionId(undefined)
  }, [])

  return {
    messages,
    isStreaming,
    currentThinkingSteps,
    currentContent,
    sessionId,
    showThinking,
    setShowThinking,
    reasoningEffort,
    setReasoningEffort,
    verbosity,
    setVerbosity,
    model,
    setModel,
    sendMessage,
    stopStreaming,
    clearMessages,
  }
}
