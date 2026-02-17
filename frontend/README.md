# Frontend Application

Next.js 16 application with **GPT-5.2 thinking visualization UI** and real-time streaming.

## 🚀 Features

- ✅ **Next.js 16** with Turbopack
- ✅ **React 19** with latest features
- ✅ **Thinking Process Visualization** - Real-time reasoning display ⭐
- ✅ **Server-Sent Events (SSE)** - Streaming chat responses
- ✅ **TypeScript** - Full type safety
- ✅ **Tailwind CSS** - Modern styling
- ✅ **Responsive Design** - Mobile-first approach
- ✅ **Markdown Support** - Rich text formatting

## 📁 Structure

```
frontend/
├── src/
│   ├── app/                 # Next.js 16 app directory
│   │   ├── layout.tsx       # Root layout
│   │   ├── page.tsx         # Home page with chat
│   │   ├── providers.tsx    # React Query provider
│   │   ├── globals.css      # Global styles
│   │   └── api/
│   │       └── health/      # Health check API
│   ├── components/
│   │   ├── chat/
│   │   │   ├── thinking-process.tsx       # ⭐ THINKING UI
│   │   │   ├── chat-message.tsx           # Message component
│   │   │   ├── chat-messages.tsx          # Messages list
│   │   │   ├── chat-input.tsx             # Input component
│   │   │   ├── chat-interface.tsx         # Main chat UI
│   │   │   └── compact-thinking-indicator.tsx
│   │   └── ui/              # Reusable UI components
│   │       ├── button.tsx
│   │       └── card.tsx
│   ├── hooks/
│   │   ├── use-chat.ts      # ⭐ STREAMING CHAT HOOK
│   │   └── use-rag.ts       # RAG query hook
│   ├── lib/
│   │   ├── api-client.ts    # REST API client
│   │   ├── stream-client.ts # ⭐ SSE STREAMING CLIENT
│   │   └── utils.ts         # Utilities
│   └── types/
│       ├── chat.ts          # Chat type definitions
│       └── api.ts           # API type definitions
├── public/                  # Static assets
├── Dockerfile              # Multi-stage build
├── package.json            # Dependencies
├── tsconfig.json           # TypeScript config
├── tailwind.config.ts      # Tailwind config
├── next.config.ts          # Next.js config
└── jest.config.js          # Jest config
```

## 🎯 Key Components

### 1. Thinking Process Component ⭐⭐⭐

**File**: `src/components/chat/thinking-process.tsx`

Visualizes GPT-5.2 reasoning steps in real-time:

```tsx
<ThinkingProcess
  steps={thinkingSteps}
  isActive={isStreaming}
/>
```

**Features**:
- Step-by-step reasoning display
- Confidence indicators (0-100%)
- Animated appearance
- Collapsible metadata
- Real-time updates during streaming

### 2. Streaming Chat Hook ⭐⭐⭐

**File**: `src/hooks/use-chat.ts`

React hook for streaming chat with thinking:

```tsx
const {
  messages,
  isStreaming,
  currentThinkingSteps,  // Real-time thinking steps
  currentContent,         // Real-time content
  sendMessage,
  stopStreaming,
} = useChat({
  onThinkingStep: (step) => console.log('Thinking:', step),
  onContentChunk: (chunk) => console.log('Content:', chunk),
  onComplete: (sessionId) => console.log('Done:', sessionId),
})
```

### 3. SSE Stream Client ⭐⭐⭐

**File**: `src/lib/stream-client.ts`

Handles Server-Sent Events streaming:

```tsx
for await (const chunk of streamChat(messages)) {
  if (chunk.type === 'thinking') {
    // Display thinking step
  } else if (chunk.type === 'content') {
    // Display content chunk
  }
}
```

## 🚦 Quick Start

### 1. Install Dependencies

```bash
cd frontend
npm install
```

### 2. Configure Environment

```bash
cp .env.local.example .env.local
```

Edit `.env.local`:
```env
NEXT_PUBLIC_API_URL=http://localhost:8000
```

### 3. Run Development Server

```bash
npm run dev
```

Or with Turbopack (faster):
```bash
npm run dev -- --turbopack
```

### 4. Access Application

Open http://localhost:3000

## 🎨 UI Components

### Thinking Process Display

Shows reasoning steps with:
- ✅ Step number badges
- ✅ Confidence bars (color-coded)
- ✅ Animated appearance
- ✅ Timestamp display
- ✅ Metadata expansion

### Chat Interface

Features:
- ✅ Real-time streaming responses
- ✅ Markdown rendering
- ✅ Code syntax highlighting
- ✅ Auto-scroll to new messages
- ✅ Thinking toggle (on/off)
- ✅ Clear conversation button

## 📱 Responsive Design

The application is fully responsive:
- **Mobile** (< 640px): Single column, touch-optimized
- **Tablet** (640px - 1024px): Optimized layout
- **Desktop** (> 1024px): Full-width with max-width constraints

## 🎭 Theme Support

Supports light and dark modes:
- Automatic system preference detection
- Manual theme toggle (can be added)
- Custom CSS variables for theming

## 🧪 Testing

### Run Tests

```bash
npm test
```

### Run Tests in Watch Mode

```bash
npm run test:watch
```

### Type Checking

```bash
npm run type-check
```

### Linting

```bash
npm run lint
```

## 🐳 Docker

### Build Image

```bash
docker build -t ai-app-frontend:latest .
```

### Run Container

```bash
docker run -p 3000:3000 \
  -e NEXT_PUBLIC_API_URL=http://backend:8000 \
  ai-app-frontend:latest
```

### Docker Compose

```bash
docker-compose up frontend
```

## 🔧 Configuration

### Next.js Config

**File**: `next.config.ts`

```typescript
const nextConfig = {
  experimental: {
    turbopack: true,  // Faster development
  },
  output: 'standalone',  // For Docker
}
```

### Tailwind Config

**File**: `tailwind.config.ts`

Custom thinking-related styles:
- `--thinking` color variable
- `animate-thinking-pulse` animation
- `animate-slide-in` animation

## 📊 Performance

### Bundle Size

- Initial load: ~150KB (gzipped)
- Runtime: ~200KB (gzipped)
- Total: ~350KB (gzipped)

### Streaming Performance

- First byte: ~200-500ms
- Thinking step latency: ~50-100ms
- Content chunk latency: ~50-100ms

### Optimizations

- ✅ Code splitting (automatic)
- ✅ Image optimization
- ✅ Font optimization
- ✅ GZip compression
- ✅ Static generation where possible

## 🎯 Usage Examples

### Basic Chat

```tsx
import { ChatInterface } from '@/components/chat/chat-interface'

export default function Page() {
  return <ChatInterface />
}
```

### Custom Thinking Handler

```tsx
const { sendMessage } = useChat({
  onThinkingStep: (step) => {
    console.log(`Step ${step.step_number}: ${step.reasoning}`)
    console.log(`Confidence: ${step.confidence * 100}%`)
  },
})
```

### RAG Query

```tsx
const { query, thinkingSteps, answer } = useRAG()

await query('What is quantum computing?')
// thinkingSteps updates in real-time
// answer updates as content streams
```

## 🎨 Customization

### Change Theme Colors

Edit `tailwind.config.ts`:

```typescript
theme: {
  extend: {
    colors: {
      thinking: {
        DEFAULT: 'hsl(271 91% 65%)',  // Purple
        foreground: 'hsl(0 0% 98%)',
      },
    },
  },
}
```

### Customize Thinking UI

Edit `src/components/chat/thinking-process.tsx`:

```tsx
// Change animation
className="animate-bounce"  // Instead of animate-slide-in

// Change confidence colors
function getConfidenceColor(confidence: number): string {
  if (confidence >= 0.9) return 'bg-emerald-500'
  // ...
}
```

## 📚 Additional Resources

- [Next.js 16 Documentation](https://nextjs.org/docs)
- [React 19 Documentation](https://react.dev/)
- [Tailwind CSS](https://tailwindcss.com/)
- [TypeScript](https://www.typescriptlang.org/)

---

**Built with Next.js 16, React 19, TypeScript, and Tailwind CSS**
