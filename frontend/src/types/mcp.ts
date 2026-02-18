// MCP (Model Context Protocol) server types

export type MCPTransport = 'streamable-http' | 'sse'

export interface MCPServerConfig {
  id: string
  name: string
  url: string
  transport: MCPTransport
  /** Optional bearer token for authentication */
  apiKey?: string
  enabled: boolean
}

export interface MCPTool {
  name: string
  description?: string
  inputSchema?: Record<string, any>
}

export interface MCPServerStatus {
  id: string
  connected: boolean
  tools: MCPTool[]
  error?: string
}
