'use client'

import { Brain, Loader2 } from 'lucide-react'
import type { ThinkingStep } from '@/types/chat'
import { cn } from '@/lib/utils'

interface ThinkingProcessProps {
  steps: ThinkingStep[]
  isActive?: boolean
  className?: string
}

export function ThinkingProcess({ steps, isActive = false, className }: ThinkingProcessProps) {
  if (steps.length === 0 && !isActive) {
    return null
  }

  // Combine all reasoning text into a single block
  const combinedReasoning = steps.map((s) => s.reasoning).join('')

  return (
    <div className={cn('rounded-lg border border-thinking bg-thinking/5 p-4 space-y-3', className)}>
      {/* Header */}
      <div className="flex items-center gap-2 text-sm font-medium text-foreground">
        <Brain className="h-4 w-4 text-foreground" />
        <span>Thinking Process</span>
        {isActive && (
          <Loader2 className="h-3 w-3 animate-spin ml-auto text-thinking-foreground" />
        )}
      </div>

      {/* Combined reasoning content */}
      <div className="text-sm text-foreground leading-relaxed whitespace-pre-wrap">
        {combinedReasoning}
        {isActive && steps.length === 0 && (
          <span className="text-muted-foreground animate-thinking-pulse">
            Analyzing your question...
          </span>
        )}
      </div>
    </div>
  )
}
