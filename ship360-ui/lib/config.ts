export const config = {
  apiBaseUrl: process.env.NEXT_PUBLIC_API_BASE_URL?.replace(/\/$/, '') || 'http://localhost:8000',
  apiConfigured: true,
  testUser: process.env.NEXT_PUBLIC_TEST_USER || 'testuser@myapp.com',
  apiKey: process.env.NEXT_PUBLIC_API_KEY || '1234',
  endpoints: {
    chat: 'api/chat/sync'
  }
} as const 