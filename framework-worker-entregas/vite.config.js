import react from '@vitejs/plugin-react'
import { defineConfig, loadEnv } from 'vite'

export default defineConfig(({ mode, command, isPreview }) => {
  const env = loadEnv(mode, process.cwd(), 'API_PROXY_')
  return {
    plugins: [react()],
    ...((command === 'serve' && !isPreview) && {
      server: { proxy: { '/api': { target: env.API_PROXY_TARGET || 'http://localhost:8080', changeOrigin: true } } },
    }),
  }
})
