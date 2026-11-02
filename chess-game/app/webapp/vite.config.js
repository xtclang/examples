import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Output goes to build/ (served by @StaticContent("/", /) in chess.x).
//
// In dev, API calls are proxied to wherever the XQIZ.IT platform is hosting chess.examples.org
// (chess.x is @WebApp and has no standalone server of its own). Point `target` at that instance;
// every @WebService in this app is @HttpsRequired, so it must be the HTTPS port. `secure: false`
// skips certificate checks against a self-signed/dev cert on that host.
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
