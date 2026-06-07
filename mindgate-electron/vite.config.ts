import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  root: '.',
  base: './',
  build: {
    outDir: 'dist',
    rollupOptions: {
      input: {
        main: './public/index.html'
      },
      external: ['child_process', 'util', 'fs', 'path']
    }
  },
  server: {
    port: 3000,
    strictPort: true
  },
  optimizeDeps: {
    include: ['react', 'react-dom', 'framer-motion']
  }
});