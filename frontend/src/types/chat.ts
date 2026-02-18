// Chat types matching backend Pydantic models

export enum MessageRole {
  USER = 'user',
  ASSISTANT = 'assistant',
  SYSTEM = 'system',
}

export enum StreamChunkType {
  THINKING = 'thinking',
  CONTENT = 'content',
  DONE = 'done',
  ERROR = 'error',
}

export interface ThinkingStep {
  reasoning: string
  timestamp: string
  metadata?: Record<string, any>
}

export interface ChatMessage {
  role: MessageRole
  content: string
  thinking_steps?: ThinkingStep[]
  timestamp: string
  metadata?: Record<string, any>
}

export interface StreamChunk {
  type: StreamChunkType
  content: string
  metadata?: Record<string, any>
  timestamp: string
}

export type ReasoningEffort = 'none' | 'minimal' | 'low' | 'medium' | 'high'
export type Verbosity = 'low' | 'medium' | 'high'

export interface MCPServerPayload {
  url: string
  transport: 'streamable-http' | 'sse'
  api_key?: string
}

export interface ChatRequest {
  messages: ChatMessage[]
  session_id?: string
  user_id?: string
  show_thinking?: boolean
  stream?: boolean
  reasoning_effort?: ReasoningEffort
  verbosity?: Verbosity
  max_tokens?: number
  /** Active MCP servers for tool calling */
  mcp_servers?: MCPServerPayload[]
}

export interface ChatResponse {
  message: ChatMessage
  session_id: string
  usage?: {
    prompt_tokens: number
    completion_tokens: number
    total_tokens: number
  }
}

export interface ConversationSession {
  id: string
  user_id: string
  title: string
  message_count: number
  created_at: string
  updated_at: string
  metadata?: Record<string, any>
}

export interface RAGQueryRequest {
  query: string
  top_k?: number
  session_id?: string
  show_thinking?: boolean
}

export interface RAGSource {
  id: string
  content: string
  title: string
  score: number
  metadata?: Record<string, any>
}

export interface RAGQueryResponse {
  answer: string
  sources: RAGSource[]
  thinking_steps?: ThinkingStep[]
  session_id: string
}
