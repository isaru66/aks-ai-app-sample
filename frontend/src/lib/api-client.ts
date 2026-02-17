import axios, { AxiosInstance } from 'axios'

// Use relative URLs - requests are proxied through Next.js API routes to backend
const API_BASE_URL = '/api/v1'

class APIClient {
  private client: AxiosInstance

  constructor() {
    this.client = axios.create({
      baseURL: API_BASE_URL,
      headers: {
        'Content-Type': 'application/json',
      },
      timeout: 30000,
    })

    // Request interceptor
    this.client.interceptors.request.use(
      (config) => {
        // Add auth token if available
        const token = localStorage.getItem('auth_token')
        if (token) {
          config.headers.Authorization = `Bearer ${token}`
        }
        return config
      },
      (error) => Promise.reject(error)
    )

    // Response interceptor
    this.client.interceptors.response.use(
      (response) => response,
      (error) => {
        console.error('API Error:', error)
        return Promise.reject(error)
      }
    )
  }

  // Health check
  async healthCheck() {
    const response = await this.client.get('/health/')
    return response.data
  }

  // Get chat history
  async getChatHistory(sessionId: string) {
    const response = await this.client.get(`/chat/history/${sessionId}`)
    return response.data
  }

  // Delete conversation
  async deleteConversation(sessionId: string) {
    const response = await this.client.delete(`/chat/${sessionId}`)
    return response.data
  }

  // Non-streaming chat (legacy)
  async sendChatMessage(request: any) {
    const response = await this.client.post('/chat/completions/sync', request)
    return response.data
  }

  // RAG index document
  async indexDocument(docId: string, content: string, title: string) {
    const response = await this.client.post('/rag/index', {
      doc_id: docId,
      content,
      title,
    })
    return response.data
  }

  // Execute agent
  async executeAgent(request: any) {
    const response = await this.client.post('/agents/execute', request)
    return response.data
  }

  // Get the base URL for SSE streaming (now uses relative URL)
  getStreamURL(endpoint: string): string {
    return `${API_BASE_URL}${endpoint}`
  }
}

export const apiClient = new APIClient()
