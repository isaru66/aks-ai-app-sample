'use client'

import { useState, useCallback } from 'react'
import type { MCPServerConfig, MCPTransport } from '@/types/mcp'

const STORAGE_KEY = 'mcp_servers'

function loadFromStorage(): MCPServerConfig[] {
  if (typeof window === 'undefined') return []
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? (JSON.parse(raw) as MCPServerConfig[]) : []
  } catch {
    return []
  }
}

function saveToStorage(servers: MCPServerConfig[]): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(servers))
  } catch {
    // ignore storage errors
  }
}

let idCounter = 0
function generateId(): string {
  return `mcp-${Date.now()}-${++idCounter}`
}

export function useMCPServers() {
  const [servers, setServers] = useState<MCPServerConfig[]>(loadFromStorage)

  const addServer = useCallback(
    (partial: Omit<MCPServerConfig, 'id'>) => {
      const server: MCPServerConfig = { ...partial, id: generateId() }
      setServers((prev) => {
        const updated = [...prev, server]
        saveToStorage(updated)
        return updated
      })
      return server
    },
    [],
  )

  const updateServer = useCallback(
    (id: string, changes: Partial<Omit<MCPServerConfig, 'id'>>) => {
      setServers((prev) => {
        const updated = prev.map((s) => (s.id === id ? { ...s, ...changes } : s))
        saveToStorage(updated)
        return updated
      })
    },
    [],
  )

  const removeServer = useCallback((id: string) => {
    setServers((prev) => {
      const updated = prev.filter((s) => s.id !== id)
      saveToStorage(updated)
      return updated
    })
  }, [])

  const toggleServer = useCallback((id: string) => {
    setServers((prev) => {
      const updated = prev.map((s) => (s.id === id ? { ...s, enabled: !s.enabled } : s))
      saveToStorage(updated)
      return updated
    })
  }, [])

  /** Only servers that are enabled and have a non-empty URL */
  const activeServers = servers.filter((s) => s.enabled && s.url.trim() !== '')

  return {
    servers,
    activeServers,
    addServer,
    updateServer,
    removeServer,
    toggleServer,
  }
}
