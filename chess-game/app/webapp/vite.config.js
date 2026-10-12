import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Output goes to build/ (served by @StaticContent("/", /build) in chess.x).
// In dev, API calls are proxied to the running XTC chess server.
export default defineConfig({
  plugins: [react()],
  build: { outDir: 'build', emptyOutDir: true },
  server: {
    proxy: { '/api': 'http://localhost:8080' },
  },
});
