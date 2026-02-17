import { type ClassValue, clsx } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatTimestamp(timestamp: string): string {
  const date = new Date(timestamp)
  return date.toLocaleTimeString('en-US', {
    hour: '2-digit',
    minute: '2-digit',
  })
}

export function formatDate(timestamp: string): string {
  const date = new Date(timestamp)
  return date.toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  })
}

/**
 * Pre-process content so that LaTeX written with bracket delimiters
 * (\[ ... \] and \( ... \)) is converted to dollar-sign delimiters
 * ($$ ... $$ and $ ... $) that remark-math / rehype-katex understand.
 *
 * Also handles bare `[ ... ]` blocks on their own line that the model
 * sometimes emits (without the leading backslash).
 */
export function preprocessLaTeX(content: string): string {
  // \[ ... \]  →  $$ ... $$
  let result = content.replace(
    /\\\[([\s\S]*?)\\\]/g,
    (_match, inner) => `$$${inner}$$`
  )

  // \( ... \)  →  $ ... $
  result = result.replace(
    /\\\(([\s\S]*?)\\\)/g,
    (_match, inner) => `$${inner}$`
  )

  // Stand-alone lines like `[ r = a(1 - e\cos E) ]`
  // (a `[` at line start, content, `]` at line end, not a markdown link)
  result = result.replace(
    /^\[\s*([^\]]*\\[^\]]+)\s*\]$/gm,
    (_match, inner) => `$$${inner}$$`
  )

  return result
}
