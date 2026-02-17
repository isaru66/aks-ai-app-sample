export interface APIError {
  error: string
  message: string
  detail?: string
  timestamp: string
}

export interface HealthResponse {
  status: string
  version: string
  environment: string
  timestamp: string
  services?: Record<string, string>
}
