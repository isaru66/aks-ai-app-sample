'use client'

import { User, Bot } from 'lucide-react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import remarkMath from 'remark-math'
import rehypeKatex from 'rehype-katex'
import type { ChatMessage as ChatMessageType } from '@/types/chat'
import { ThinkingProcess } from './thinking-process'
import { CodeBlock } from './code-block'
import { cn } from '@/lib/utils'
import { formatTimestamp, preprocessLaTeX } from '@/lib/utils'

interface ChatMessageProps {
  message: ChatMessageType
  showThinking?: boolean
}

export function ChatMessage({ message, showThinking = true }: ChatMessageProps) {
  const isUser = message.role === 'user'
  const isAssistant = message.role === 'assistant'

  return (
    <div
      className={cn(
        'group flex gap-4 px-4 py-6 transition-colors',
        isAssistant && 'bg-muted/30'
      )}
    >
      {/* Avatar */}
      <div
        className={cn(
          'flex h-8 w-8 shrink-0 select-none items-center justify-center rounded-full',
          isUser && 'bg-primary text-primary-foreground',
          isAssistant && 'bg-accent text-accent-foreground'
        )}
      >
        {isUser ? <User className="h-4 w-4" /> : <Bot className="h-4 w-4" />}
      </div>

      {/* Content */}
      <div className="flex-1 space-y-4 overflow-hidden">
        {/* Thinking Steps (only for assistant with thinking) */}
        {isAssistant && showThinking && message.thinking_steps && message.thinking_steps.length > 0 && (
          <ThinkingProcess steps={message.thinking_steps} />
        )}

        {/* Message Content */}
        <div className="prose prose-sm max-w-none dark:prose-invert">
          <ReactMarkdown
            remarkPlugins={[remarkGfm, remarkMath]}
            rehypePlugins={[rehypeKatex]}
            components={{ code: (props) => <CodeBlock {...props} /> }}
          >
            {preprocessLaTeX(message.content)}
          </ReactMarkdown>
        </div>

        {/* Timestamp */}
        <div className="text-xs text-muted-foreground opacity-0 group-hover:opacity-100 transition-opacity">
          {formatTimestamp(message.timestamp)}
        </div>
      </div>
    </div>
  )
}
