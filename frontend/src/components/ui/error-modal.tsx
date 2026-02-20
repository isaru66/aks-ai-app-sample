'use client'

import { useEffect } from 'react'
import { AlertTriangle, X } from 'lucide-react'

export interface ErrorModalProps {
  message: string
  onClose: () => void
}

export function ErrorModal({ message, onClose }: ErrorModalProps) {
  // Close on Escape key
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose()
    }
    document.addEventListener('keydown', handleKeyDown)
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [onClose])

  return (
    /* Backdrop */
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm"
      onClick={onClose}
      aria-modal="true"
      role="alertdialog"
      aria-labelledby="error-modal-title"
      aria-describedby="error-modal-desc"
    >
      {/* Modal box */}
      <div
        className="relative mx-4 w-full max-w-md rounded-xl border border-destructive/30 bg-background p-6 shadow-lg"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Close button */}
        <button
          onClick={onClose}
          className="absolute right-3 top-3 rounded-sm p-1 text-muted-foreground hover:text-foreground transition-colors"
          aria-label="Close error dialog"
        >
          <X className="h-4 w-4" />
        </button>

        {/* Icon + title */}
        <div className="flex items-center gap-3 mb-3">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-destructive/10">
            <AlertTriangle className="h-5 w-5 text-destructive" />
          </span>
          <h2 id="error-modal-title" className="text-base font-semibold text-foreground">
            Something went wrong
          </h2>
        </div>

        {/* Error message */}
        <p id="error-modal-desc" className="text-sm text-muted-foreground break-words">
          {message}
        </p>

        {/* Dismiss button */}
        <div className="mt-5 flex justify-end">
          <button
            onClick={onClose}
            className="rounded-lg bg-destructive px-4 py-2 text-sm font-medium text-destructive-foreground hover:bg-destructive/90 transition-colors"
          >
            Dismiss
          </button>
        </div>
      </div>
    </div>
  )
}
