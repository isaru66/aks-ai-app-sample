import { useRef, useCallback, useEffect } from 'react'

/**
 * Adaptive word-by-word buffer renderer.
 *
 * Incoming raw text is split into words and queued.
 * A timer drains the queue one word at a time, adapting speed:
 *   - buffer > FAST_THRESHOLD words  → fast interval (near-instant catch-up)
 *   - buffer <= FAST_THRESHOLD words → slow interval (smooth typewriter effect)
 *
 * This gives the user a smooth typing feel while never falling behind
 * a fast SSE stream.
 */

const SLOW_INTERVAL_MS = 40  // ~25 words/sec – comfortable reading pace
const FAST_INTERVAL_MS = 10  // ~100 words/sec – catch-up speed
const FAST_THRESHOLD = 20    // speed up only when > 20 words buffered

export interface WordBufferControls {
  /** Push raw text (arbitrary chunk size) into the buffer. */
  push: (text: string) => void
  /** Flush all remaining words immediately and return the full text. */
  flush: () => string
  /** Reset buffer and displayed text. */
  reset: () => void
}

/**
 * Creates a word-buffer renderer that calls `onUpdate` with the progressively
 * revealed text every time a new word is emitted.
 *
 * @param onUpdate called each time a word is appended to the visible text
 */
export function useWordBuffer(onUpdate: (visibleText: string) => void): WordBufferControls {
  const queue = useRef<string[]>([])
  const displayed = useRef<string[]>([])
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const onUpdateRef = useRef(onUpdate)
  // Avoid stale closures
  onUpdateRef.current = onUpdate

  // Leftover partial word from a chunk that didn't end on a word boundary
  const partialRef = useRef('')

  const scheduleNext = useCallback(() => {
    if (timerRef.current !== null) return // already scheduled
    drain()
  }, [])

  function drain() {
    if (queue.current.length === 0) {
      timerRef.current = null
      return
    }

    const word = queue.current.shift()!
    displayed.current.push(word)
    onUpdateRef.current(displayed.current.join(''))

    const interval =
      queue.current.length > FAST_THRESHOLD ? FAST_INTERVAL_MS : SLOW_INTERVAL_MS
    timerRef.current = setTimeout(drain, interval)
  }

  const push = useCallback((text: string) => {
    if (!text) return

    // Prepend any leftover partial from the previous chunk
    const combined = partialRef.current + text
    partialRef.current = ''

    // Split on word boundaries, preserving whitespace as part of the following word.
    // e.g. "Hello world foo" → ["Hello", " world", " foo"]
    // A trailing partial (no trailing space) is kept in partialRef.
    const tokens = combined.match(/\S+\s*/g)
    if (!tokens) return

    // If the combined string does NOT end with whitespace, the last token is
    // incomplete – hold it back until more text arrives.
    if (!/\s$/.test(combined)) {
      partialRef.current = tokens.pop() ?? ''
    }

    if (tokens.length > 0) {
      queue.current.push(...tokens)
      scheduleNext()
    }
  }, [scheduleNext])

  const flush = useCallback(() => {
    // Stop timer
    if (timerRef.current !== null) {
      clearTimeout(timerRef.current)
      timerRef.current = null
    }

    // Push any held-back partial word
    if (partialRef.current) {
      queue.current.push(partialRef.current)
      partialRef.current = ''
    }

    // Drain everything
    if (queue.current.length > 0) {
      displayed.current.push(...queue.current)
      queue.current = []
      onUpdateRef.current(displayed.current.join(''))
    }

    return displayed.current.join('')
  }, [])

  const reset = useCallback(() => {
    if (timerRef.current !== null) {
      clearTimeout(timerRef.current)
      timerRef.current = null
    }
    queue.current = []
    displayed.current = []
    partialRef.current = ''
  }, [])

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (timerRef.current !== null) clearTimeout(timerRef.current)
    }
  }, [])

  return { push, flush, reset }
}
