import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import 'katex/dist/katex.min.css'
import './globals.css'
import { Providers } from './providers'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'Azure AI Chat App - GPT-5.2 with Thinking Visualization',
  description: 'AI chat application with visible thinking process powered by GPT-5.2',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className={inter.className}>
        <Providers>{children}</Providers>
      </body>
    </html>
  )
}
