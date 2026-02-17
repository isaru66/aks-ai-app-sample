'use client'

import { useRef, useEffect } from 'react'
import { ChatMessage } from './chat-message'
import { ThinkingProcess } from './thinking-process'
import type { ChatMessage as ChatMessageType, ThinkingStep } from '@/types/chat'
import { Loader2 } from 'lucide-react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import remarkMath from 'remark-math'
import rehypeKatex from 'rehype-katex'
import { preprocessLaTeX } from '@/lib/utils'

interface ChatMessagesProps {
  messages: ChatMessageType[]
  isStreaming?: boolean
  currentThinkingSteps?: ThinkingStep[]
  currentContent?: string
  showThinking?: boolean
}

export function ChatMessages({
  messages,
  isStreaming = false,
  currentThinkingSteps = [],
  currentContent = '',
  showThinking = true,
}: ChatMessagesProps) {
  const scrollRef = useRef<HTMLDivElement>(null)

  // Auto-scroll to bottom
  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [messages, currentThinkingSteps, currentContent])

  return (
    <div
      ref={scrollRef}
      className="flex-1 overflow-y-auto scroll-smooth"
      style={{ scrollBehavior: 'smooth' }}
    >
      <div className="mx-auto max-w-4xl">
        {/* Existing messages */}
        {messages.map((message, index) => (
          <ChatMessage
            key={index}
            message={message}
            showThinking={showThinking}
          />
        ))}

        {/* Streaming message (in progress) */}
        {isStreaming && (
          <div className="group flex gap-4 px-4 py-6 bg-muted/30">
          {/* Bot Avatar */}
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-accent text-accent-foreground">
            <Loader2 className="h-4 w-4 animate-spin" />
          </div>

          {/* Streaming Content */}
          <div className="flex-1 space-y-4 overflow-hidden">
            {/* Current Thinking Steps */}
            {showThinking && currentThinkingSteps.length > 0 && (
              <ThinkingProcess
                steps={currentThinkingSteps}
                isActive={true}
              />
            )}

            {/* Current Content (streaming) */}
            {currentContent && (
              <div className="prose prose-sm max-w-none dark:prose-invert">
                <ReactMarkdown remarkPlugins={[remarkGfm, remarkMath]} rehypePlugins={[rehypeKatex]}>
                  {preprocessLaTeX(currentContent)}
                </ReactMarkdown>
              </div>
            )}

            {/* Waiting indicator */}
            {!currentContent && currentThinkingSteps.length === 0 && (
              <div className="flex items-center gap-2 text-sm text-muted-foreground">
                <Loader2 className="h-3 w-3 animate-spin" />
                <span>Processing your message...</span>
              </div>
            )}
          </div>
        </div>
      )}
      </div>

      {/* Empty state */}
      {messages.length === 0 && !isStreaming && (
        <div className="flex h-full items-center justify-center text-center px-4">
          <div className="space-y-4 max-w-md">
            <div className="text-6xl">🤖</div>
            <h3 className="text-xl font-semibold">Start a Conversation</h3>
            <p className="text-sm text-muted-foreground">
              Ask me anything! I'll show you my thinking process as I work through your question.
            </p>
          </div>
        </div>
      )}
    </div>
  )
}
