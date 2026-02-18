'use client'

import { ChatMessages } from './chat-messages'
import { ChatInput } from './chat-input'
import { MCPServersPanel } from './mcp-servers-panel'
import { useChat } from '@/hooks/use-chat'
import { useMCPServers } from '@/hooks/use-mcp-servers'
import { Settings, Trash2, ChevronDown } from 'lucide-react'
import { useState } from 'react'
import type { ReasoningEffort, Verbosity } from '@/types/chat'

const EFFORT_OPTIONS: { value: ReasoningEffort; label: string; description: string }[] = [
  { value: 'none', label: 'None', description: 'No reasoning' },
  { value: 'minimal', label: 'Minimal', description: 'Fastest responses' },
  { value: 'low', label: 'Low', description: 'Light reasoning' },
  { value: 'medium', label: 'Medium', description: 'Balanced' },
  { value: 'high', label: 'High', description: 'Deep reasoning' },
]

const VERBOSITY_OPTIONS: { value: Verbosity; label: string; description: string }[] = [
  { value: 'low', label: 'Low', description: 'Short responses' },
  { value: 'medium', label: 'Medium', description: 'Default length' },
  { value: 'high', label: 'High', description: 'Verbose responses' },
]

export function ChatInterface() {
  const mcpServersHook = useMCPServers()

  const {
    messages,
    isStreaming,
    currentThinkingSteps,
    currentContent,
    sessionId,
    showThinking,
    setShowThinking,
    reasoningEffort,
    setReasoningEffort,
    verbosity,
    setVerbosity,
    sendMessage,
    stopStreaming,
    clearMessages,
  } = useChat({
    onThinkingStep: (step) => {
      console.log('Thinking step:', step)
    },
    onContentChunk: (chunk) => {
      console.log('Content chunk:', chunk)
    },
    onComplete: (sessionId) => {
      console.log('Chat completed, session:', sessionId)
    },
    onError: (error) => {
      console.error('Chat error:', error)
    },
    mcpServers: mcpServersHook.activeServers.map((s) => ({
      url: s.url,
      transport: s.transport,
      api_key: s.apiKey,
    })),
  })

  const [showSettings, setShowSettings] = useState(false)

  return (
    <div className="flex h-full flex-col">
      {/* Header */}
      <div className="border-b bg-background px-4 py-3">
        <div className="mx-auto flex max-w-4xl items-center justify-between">
          <div>
            <h1 className="text-lg font-semibold">AI Chat</h1>
            {sessionId && (
              <p className="text-xs text-muted-foreground truncate max-w-[20rem]" title={sessionId}>
                Session: {sessionId}
              </p>
            )}
          </div>

          {/* Controls */}
          <div className="flex items-center gap-2">
            {/* Settings Toggle */}
            <button
              onClick={() => setShowSettings(!showSettings)}
              className={`
                flex items-center gap-2 rounded-lg px-3 py-1.5 text-xs font-medium
                transition-colors border
                ${
                  showSettings
                    ? 'bg-primary/10 text-primary border-primary/30'
                    : 'bg-background text-muted-foreground border-border hover:bg-accent'
                }
              `}
              title="Toggle settings"
            >
              <Settings className="h-3 w-3" />
              Settings
            </button>

            {/* Clear Chat */}
            {messages.length > 0 && (
              <button
                onClick={clearMessages}
                disabled={isStreaming}
                className="
                  flex items-center gap-2 rounded-lg px-3 py-1.5 text-xs font-medium
                  bg-destructive/10 text-destructive hover:bg-destructive/20
                  transition-colors border border-destructive/20
                  disabled:opacity-50 disabled:cursor-not-allowed
                "
                title="Clear conversation"
              >
                <Trash2 className="h-3 w-3" />
                Clear
              </button>
            )}
          </div>
        </div>

        {/* Settings Panel */}
        {showSettings && (
          <div className="mx-auto max-w-4xl mt-3 p-3 rounded-lg border bg-muted/30 space-y-3">
            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
              {/* Thinking Level (Reasoning Effort) */}
              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">
                  Thinking Level
                </label>
                <div className="relative">
                  <select
                    value={reasoningEffort}
                    onChange={(e) => setReasoningEffort(e.target.value as ReasoningEffort)}
                    disabled={isStreaming}
                    className="
                      w-full appearance-none rounded-md border border-input bg-background
                      px-3 py-1.5 text-sm pr-8
                      focus:outline-none focus:ring-2 focus:ring-ring
                      disabled:opacity-50 disabled:cursor-not-allowed
                    "
                  >
                    {EFFORT_OPTIONS.map((opt) => (
                      <option key={opt.value} value={opt.value}>
                        {opt.label} — {opt.description}
                      </option>
                    ))}
                  </select>
                  <ChevronDown className="absolute right-2 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground pointer-events-none" />
                </div>
              </div>

              {/* Verbosity */}
              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">
                  Verbosity
                </label>
                <div className="relative">
                  <select
                    value={verbosity}
                    onChange={(e) => setVerbosity(e.target.value as Verbosity)}
                    disabled={isStreaming}
                    className="
                      w-full appearance-none rounded-md border border-input bg-background
                      px-3 py-1.5 text-sm pr-8
                      focus:outline-none focus:ring-2 focus:ring-ring
                      disabled:opacity-50 disabled:cursor-not-allowed
                    "
                  >
                    {VERBOSITY_OPTIONS.map((opt) => (
                      <option key={opt.value} value={opt.value}>
                        {opt.label} — {opt.description}
                      </option>
                    ))}
                  </select>
                  <ChevronDown className="absolute right-2 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-muted-foreground pointer-events-none" />
                </div>
              </div>

              {/* Show Thinking Toggle */}
              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">
                  Reasoning Summary
                </label>
                <button
                  onClick={() => setShowThinking(!showThinking)}
                  disabled={isStreaming}
                  className={`
                    w-full flex items-center justify-center gap-2 rounded-md px-3 py-1.5 text-sm font-medium
                    transition-colors border
                    disabled:opacity-50 disabled:cursor-not-allowed
                    ${
                      showThinking
                        ? 'bg-thinking text-thinking-foreground border-thinking'
                        : 'bg-background text-muted-foreground border-border hover:bg-accent'
                    }
                  `}
                >
                  {showThinking ? 'Visible' : 'Hidden'}
                </button>
              </div>
            </div>

            {/* Current config summary */}
            <div className="text-[11px] text-muted-foreground text-center pt-1 border-t">
              effort: <span className="font-mono font-medium text-foreground">{reasoningEffort}</span>
              {' · '}
              verbosity: <span className="font-mono font-medium text-foreground">{verbosity}</span>
              {' · '}
              reasoning summary: <span className="font-mono font-medium text-foreground">{showThinking ? 'auto' : 'none'}</span>
            </div>

            {/* MCP Servers */}
            <div className="border-t pt-3">
              <MCPServersPanel hook={mcpServersHook} />
            </div>
          </div>
        )}
      </div>

      {/* Messages */}
      <ChatMessages
        messages={messages}
        isStreaming={isStreaming}
        currentThinkingSteps={currentThinkingSteps}
        currentContent={currentContent}
        showThinking={showThinking}
      />

      {/* Input */}
      <ChatInput
        onSend={sendMessage}
        onStop={stopStreaming}
        isStreaming={isStreaming}
      />
    </div>
  )
}
