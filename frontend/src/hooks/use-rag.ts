import { useState, useCallback } from 'react'
import { streamRAGQuery } from '@/lib/stream-client'
import type { ThinkingStep, StreamChunk, RAGSource } from '@/types/chat'

export interface UseRAGOptions {
  onThinkingStep?: (step: ThinkingStep) => void
  onContentChunk?: (content: string) => void
  onComplete?: () => void
  onError?: (error: string) => void
}

export function useRAG(options: UseRAGOptions = {}) {
  const [isQuerying, setIsQuerying] = useState(false)
  const [thinkingSteps, setThinkingSteps] = useState<ThinkingStep[]>([])
  const [answer, setAnswer] = useState('')
  const [sources, setSources] = useState<RAGSource[]>([])

  const query = useCallback(
    async (queryText: string) => {
      if (isQuerying) return

      setIsQuerying(true)
      setThinkingSteps([])
      setAnswer('')
      setSources([])

      const steps: ThinkingStep[] = []
      const contentParts: string[] = []

      try {
        for await (const chunk of streamRAGQuery(queryText, {
          onThinking: (step) => {
            const thinkingStep: ThinkingStep = {
              step_number: step.metadata?.step_number || steps.length + 1,
              reasoning: step.content,
              confidence: step.metadata?.confidence || 0.9,
              timestamp: step.timestamp,
              metadata: step.metadata,
            }

            steps.push(thinkingStep)
            setThinkingSteps([...steps])
            options.onThinkingStep?.(thinkingStep)
          },

          onContent: (chunk) => {
            contentParts.push(chunk.content)
            const fullContent = contentParts.join('')
            setAnswer(fullContent)
            options.onContentChunk?.(chunk.content)
          },

          onDone: (metadata) => {
            setIsQuerying(false)
            options.onComplete?.()
          },

          onError: (error) => {
            setIsQuerying(false)
            options.onError?.(error)
          },
        })) {
          // Processing through callbacks
        }
      } catch (error) {
        console.error('RAG query error:', error)
        setIsQuerying(false)
        options.onError?.(error instanceof Error ? error.message : 'Unknown error')
      }
    },
    [isQuerying, options]
  )

  return {
    isQuerying,
    thinkingSteps,
    answer,
    sources,
    query,
  }
}
