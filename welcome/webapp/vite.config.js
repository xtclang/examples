import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Emit to build/ (not Vite's default dist/): welcome.x serves @StaticContent("/", /build)
// and webapp-conventions declares webapp/build as the buildWebapp output.
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'build',
  },
});
