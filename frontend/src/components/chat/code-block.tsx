'use client'

import { useState } from 'react'
import { Check, Copy } from 'lucide-react'
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter'
import { oneDark } from 'react-syntax-highlighter/dist/esm/styles/prism'
import type { ComponentPropsWithoutRef } from 'react'

type CodeProps = ComponentPropsWithoutRef<'code'> & {
  inline?: boolean
}

export function CodeBlock({ inline, className, children, ...props }: CodeProps) {
  const [copied, setCopied] = useState(false)

  // Extract language from className like "language-python"
  const match = /language-(\w+)/.exec(className || '')
  const language = match ? match[1] : ''
  const code = String(children).replace(/\n$/, '')

  const handleCopy = () => {
    navigator.clipboard.writeText(code)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  // Inline code — no highlighting
  if (inline || !language) {
    return (
      <code
        className="bg-zinc-100 dark:bg-zinc-700 text-zinc-900 dark:text-zinc-100 px-1.5 py-0.5 rounded text-sm font-mono"
        {...props}
      >
        {children}
      </code>
    )
  }

  return (
    <div className="relative group my-4 rounded-lg overflow-hidden border border-zinc-700 dark:border-zinc-600">
      {/* Header bar */}
      <div className="flex items-center justify-between px-4 py-2 bg-zinc-800 dark:bg-zinc-900 border-b border-zinc-700 dark:border-zinc-600">
        <span className="text-xs font-medium text-zinc-400 uppercase tracking-wider">
          {language}
        </span>
        <button
          onClick={handleCopy}
          className="flex items-center gap-1.5 text-xs text-zinc-400 hover:text-zinc-200 transition-colors"
          aria-label="Copy code"
        >
          {copied ? (
            <>
              <Check className="h-3.5 w-3.5 text-green-400" />
              <span className="text-green-400">Copied!</span>
            </>
          ) : (
            <>
              <Copy className="h-3.5 w-3.5" />
              <span>Copy</span>
            </>
          )}
        </button>
      </div>

      {/* Highlighted code */}
      <SyntaxHighlighter
        language={language}
        style={oneDark}
        customStyle={{
          margin: 0,
          borderRadius: 0,
          padding: '1rem',
          fontSize: '0.875rem',
          lineHeight: '1.6',
          background: '#1c1c1e',
        }}
        codeTagProps={{ style: { fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace' } }}
        showLineNumbers={code.split('\n').length > 5}
        lineNumberStyle={{ color: '#4b5563', minWidth: '2.5em', paddingRight: '1em', userSelect: 'none' }}
      >
        {code}
      </SyntaxHighlighter>
    </div>
  )
}
