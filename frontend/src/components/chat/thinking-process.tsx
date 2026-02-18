'use client'

import { useEffect, useRef, useState } from 'react'
import { Brain, ChevronDown, ChevronUp, Loader2 } from 'lucide-react'
import type { ThinkingStep } from '@/types/chat'
import { cn } from '@/lib/utils'

/** Delay (ms) after thinking stops before the box auto-collapses. */
const AUTO_COLLAPSE_DELAY = 3000

interface ThinkingProcessProps {
  steps: ThinkingStep[]
  isActive?: boolean
  className?: string
}

export function ThinkingProcess({ steps, isActive = false, className }: ThinkingProcessProps) {
  // Start expanded while active; collapse after thinking finishes
  const [expanded, setExpanded] = useState(true)
  const collapseTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)

  // When thinking transitions from active → done, schedule auto-collapse
  useEffect(() => {
    if (!isActive && steps.length > 0) {
      collapseTimerRef.current = setTimeout(() => {
        setExpanded(false)
      }, AUTO_COLLAPSE_DELAY)
    }

    // If thinking becomes active again, cancel any pending collapse and re-expand
    if (isActive) {
      if (collapseTimerRef.current) {
        clearTimeout(collapseTimerRef.current)
        collapseTimerRef.current = null
      }
      setExpanded(true)
    }

    return () => {
      if (collapseTimerRef.current) {
        clearTimeout(collapseTimerRef.current)
      }
    }
  }, [isActive, steps.length])

  if (steps.length === 0 && !isActive) {
    return null
  }

  const combinedReasoning = steps.map((s) => s.reasoning).join('')

  return (
    <div className={cn('rounded-lg border border-thinking bg-thinking/5', className)}>
      {/* ── Clickable header ─────────────────────────────────────── */}
      <button
        type="button"
        onClick={() => {
          // User manually toggling — cancel any pending auto-collapse
          if (collapseTimerRef.current) {
            clearTimeout(collapseTimerRef.current)
            collapseTimerRef.current = null
          }
          setExpanded((v) => !v)
        }}
        className="flex w-full items-center gap-2 px-4 py-3 text-sm font-medium text-foreground hover:bg-thinking/10 transition-colors rounded-lg"
        aria-expanded={expanded}
      >
        <Brain className="h-4 w-4 shrink-0 text-foreground" />
        <span className="flex-1 text-left">Thinking Process</span>

        {isActive ? (
          <Loader2 className="h-3 w-3 animate-spin text-thinking-foreground" />
        ) : (
          expanded
            ? <ChevronUp className="h-3.5 w-3.5 text-muted-foreground" />
            : <ChevronDown className="h-3.5 w-3.5 text-muted-foreground" />
        )}
      </button>

      {/* ── Collapsible body ─────────────────────────────────────── */}
      {expanded && (
        <div className="px-4 pb-4 text-sm text-foreground leading-relaxed whitespace-pre-wrap border-t border-thinking/30 pt-3">
          {combinedReasoning}
          {isActive && steps.length === 0 && (
            <span className="text-muted-foreground animate-thinking-pulse">
              Analyzing your question...
            </span>
          )}
        </div>
      )}
    </div>
  )
}
