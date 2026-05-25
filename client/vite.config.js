import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import fs from 'fs';
import path from 'path';

export default defineConfig({
  base: '/',
  plugins: [
    react(),
    {
      name: 'update-version',
      generateBundle() {
        // Update version meta tag during build
        const htmlPath = path.resolve(__dirname, 'index.html');
        let html = fs.readFileSync(htmlPath, 'utf-8');
        const timestamp = new Date().toISOString();
        html = html.replace(
          /content="[^"]*"/,
          `content="${timestamp}"`
        );
        this.emitFile({
          type: 'asset',
          fileName: 'index.html',
          source: html
        });
      }
    }
  ],
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:4000'
    }
  },
  build: {
    // Force unique filenames with hash for cache busting
    rollupOptions: {
      output: {
        entryFileNames: 'assets/[name].[hash].js',
        chunkFileNames: 'assets/[name].[hash].js',
        assetFileNames: 'assets/[name].[hash][extname]'
      }
    },
    // Disable minify to catch build changes better
    minify: 'terser'
  }
});
