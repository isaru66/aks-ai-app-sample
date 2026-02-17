'use client'

import { Brain, Loader2 } from 'lucide-react'
import type { ThinkingStep } from '@/types/chat'
import { cn } from '@/lib/utils'

interface CompactThinkingIndicatorProps {
  steps: ThinkingStep[]
  isActive?: boolean
  onClick?: () => void
  className?: string
}

export function CompactThinkingIndicator({
  steps,
  isActive = false,
  onClick,
  className,
}: CompactThinkingIndicatorProps) {
  if (steps.length === 0 && !isActive) {
    return null
  }

  const avgConfidence = steps.length > 0
    ? steps.reduce((acc, step) => acc + step.confidence, 0) / steps.length
    : 0

  return (
    <button
      onClick={onClick}
      className={cn(
        'inline-flex items-center gap-2 rounded-full px-3 py-1 text-xs',
        'bg-thinking/10 text-thinking-foreground border border-thinking/30',
        'hover:bg-thinking/20 transition-colors',
        'cursor-pointer',
        className
      )}
    >
      {isActive ? (
        <Loader2 className="h-3 w-3 animate-spin" />
      ) : (
        <Brain className="h-3 w-3" />
      )}
      
      <span className="font-medium">
        {isActive ? 'Thinking...' : `${steps.length} steps`}
      </span>

      {!isActive && steps.length > 0 && (
        <span className="text-muted-foreground">
          ({Math.round(avgConfidence * 100)}%)
        </span>
      )}
    </button>
  )
}
