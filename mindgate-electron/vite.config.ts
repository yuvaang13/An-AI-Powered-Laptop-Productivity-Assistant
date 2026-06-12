import { defineConfig, Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import { readFileSync, writeFileSync } from 'fs';
import { resolve } from 'path';

function stripCrossorigin(): Plugin {
  return {
    name: 'strip-crossorigin',
    closeBundle() {
      const htmlPath = resolve('dist/index.html');
      const html = readFileSync(htmlPath, 'utf-8');
      const cleaned = html.replace(/\s*crossorigin(?:\s*=\s*["'][^"']*["'])?/g, '');
      writeFileSync(htmlPath, cleaned);
    }
  };
}

export default defineConfig({
  plugins: [react(), stripCrossorigin()],
  root: '.',
  base: './',
  build: {
    outDir: 'dist',
    rollupOptions: {
      input: {
        main: './index.html'
      },
      external: ['child_process', 'util', 'fs', 'path']
    }
  },
  server: {
    port: 3000,
    strictPort: true
  },
  optimizeDeps: {
    include: ['react', 'react-dom']
  }
});
