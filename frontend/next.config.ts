import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  // React strict mode
  reactStrictMode: true,
  
  // Standalone output for Docker
  output: 'standalone',
  
  // Environment variables exposed to browser
  env: {
    NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL,
    NEXT_PUBLIC_WS_URL: process.env.NEXT_PUBLIC_WS_URL,
  },
  
  // Image optimization
  images: {
    domains: [],
  },
  
  // Headers for SSE streaming
  async headers() {
    return [
      {
        source: '/api/:path*',
        headers: [
          { key: 'Cache-Control', value: 'no-cache, no-store, must-revalidate' },
          { key: 'Connection', value: 'keep-alive' },
        ],
      },
    ]
  },
}

export default nextConfig
