import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Output goes to build/ (served by @StaticContent("/", /build) in chess.x).
//
// In dev, API calls are proxied to the running XTC chess server. They go to the HTTPS port:
// every @WebService in this app is @HttpsRequired, so the HTTP port answers an API request with
// 403 and a Location header rather than the data. The server generates its own certificate on
// first run, so the proxy is told not to check it.
export default defineConfig({
  plugins: [react()],
  build: { outDir: 'build', emptyOutDir: true },
  server: {
    proxy: {
      '/api': {
        target: 'https://localhost:8090',
        changeOrigin: true,
        secure: false,
      },
    },
  },
});
