'use client'

import { useState } from 'react'
import { Plus, Trash2, Plug, PlugZap, ChevronDown, ChevronUp } from 'lucide-react'
import { Button } from '@/components/ui/button'
import type { MCPServerConfig, MCPTransport } from '@/types/mcp'
import { useMCPServers } from '@/hooks/use-mcp-servers'

// ── Small reusable primitives (no extra shadcn deps) ──────────────────────────

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="grid gap-1">
      <label className="text-xs font-medium text-muted-foreground">{label}</label>
      {children}
    </div>
  )
}

function TextInput({
  value,
  onChange,
  placeholder,
  type = 'text',
  className = '',
}: {
  value: string
  onChange: (val: string) => void
  placeholder?: string
  type?: string
  className?: string
}) {
  return (
    <input
      type={type}
      value={value}
      onChange={(e: React.ChangeEvent<HTMLInputElement>) => onChange(e.target.value)}
      placeholder={placeholder}
      className={`w-full rounded-md border border-input bg-background px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-ring ${className}`}
    />
  )
}

// ── Per-server row ─────────────────────────────────────────────────────────────

interface MCPServerRowProps {
  server: MCPServerConfig
  onUpdate: (id: string, changes: Partial<Omit<MCPServerConfig, 'id'>>) => void
  onRemove: (id: string) => void
  onToggle: (id: string) => void
}

function MCPServerRow({ server, onUpdate, onRemove, onToggle }: MCPServerRowProps) {
  const [expanded, setExpanded] = useState(false)

  return (
    <div className="rounded-lg border border-border bg-card p-3 space-y-2">
      {/* Header row */}
      <div className="flex items-center gap-2">
        {/* Enable/disable toggle */}
        <button
          role="switch"
          aria-checked={server.enabled}
          onClick={() => onToggle(server.id)}
          className={`relative inline-flex h-5 w-9 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors ${
            server.enabled ? 'bg-primary' : 'bg-muted'
          }`}
        >
          <span
            className={`pointer-events-none inline-block h-4 w-4 rounded-full bg-background shadow transition-transform ${
              server.enabled ? 'translate-x-4' : 'translate-x-0'
            }`}
          />
        </button>

        <span className="flex-1 truncate text-sm font-medium">
          {server.name || server.url || 'Unnamed server'}
        </span>

        <span className="shrink-0 rounded-full border border-border px-2 py-0.5 text-[10px] text-muted-foreground">
          {server.transport}
        </span>

        <button
          className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md hover:bg-accent"
          onClick={() => setExpanded((v) => !v)}
          aria-label={expanded ? 'Collapse' : 'Expand'}
        >
          {expanded ? <ChevronUp className="h-4 w-4" /> : <ChevronDown className="h-4 w-4" />}
        </button>

        <button
          className="flex h-7 w-7 shrink-0 items-center justify-center rounded-md text-destructive hover:bg-destructive/10"
          onClick={() => onRemove(server.id)}
          aria-label="Remove server"
        >
          <Trash2 className="h-4 w-4" />
        </button>
      </div>

      {/* Expanded form */}
      {expanded && (
        <div className="grid gap-3 pt-1">
          <Field label="Name">
            <TextInput
              value={server.name}
              onChange={(v) => onUpdate(server.id, { name: v })}
              placeholder="My MCP Server"
            />
          </Field>
          <Field label="URL">
            <TextInput
              value={server.url}
              onChange={(v) => onUpdate(server.id, { url: v })}
              placeholder="https://my-mcp-server.example.com/mcp"
              className="font-mono"
            />
          </Field>
          <Field label="Transport">
            <select
              value={server.transport}
              onChange={(e: React.ChangeEvent<HTMLSelectElement>) =>
                onUpdate(server.id, { transport: e.target.value as MCPTransport })
              }
              className="w-full rounded-md border border-input bg-background px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-ring"
            >
              <option value="streamable-http">Streamable HTTP (recommended)</option>
              <option value="sse">SSE (legacy)</option>
            </select>
          </Field>
          <Field label="API Key (optional)">
            <TextInput
              type="password"
              value={server.apiKey ?? ''}
              onChange={(v) => onUpdate(server.id, { apiKey: v || undefined })}
              placeholder="Bearer token for authentication"
            />
          </Field>
        </div>
      )}
    </div>
  )
}

// ── Panel ──────────────────────────────────────────────────────────────────────

interface MCPServersPanelProps {
  hook: ReturnType<typeof useMCPServers>
}

export function MCPServersPanel({ hook }: MCPServersPanelProps) {
  const { servers, addServer, updateServer, removeServer, toggleServer } = hook

  const handleAdd = () => {
    addServer({
      name: '',
      url: '',
      transport: 'streamable-http',
      enabled: true,
    })
  }

  return (
    <div className="space-y-3">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <PlugZap className="h-4 w-4 text-muted-foreground" />
          <span className="text-sm font-semibold">MCP Servers</span>
          {servers.length > 0 && (
            <span className="rounded-full border border-border px-2 py-0.5 text-[10px] text-muted-foreground">
              {servers.filter((s) => s.enabled).length}/{servers.length} active
            </span>
          )}
        </div>
        <Button variant="outline" size="sm" onClick={handleAdd} className="h-7 gap-1 text-xs">
          <Plus className="h-3 w-3" />
          Add Server
        </Button>
      </div>

      {servers.length === 0 ? (
        <div className="flex flex-col items-center gap-2 rounded-lg border border-dashed border-border py-6 text-center">
          <Plug className="h-8 w-8 text-muted-foreground/50" />
          <p className="text-xs text-muted-foreground">
            No MCP servers configured.
            <br />
            Add a server to enable tool calling.
          </p>
        </div>
      ) : (
        <div className="space-y-2">
          {servers.map((server) => (
            <MCPServerRow
              key={server.id}
              server={server}
              onUpdate={updateServer}
              onRemove={removeServer}
              onToggle={toggleServer}
            />
          ))}
        </div>
      )}
    </div>
  )
}
