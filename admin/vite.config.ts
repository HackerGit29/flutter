import react from '@vitejs/plugin-react';
import fs from 'node:fs';
import path from 'node:path';
import { defineConfig } from 'vite';

/**
 * Version affichée par le backoffice.
 *
 * `pubspec.yaml` est la source de vérité du versioning du projet (cf.
 * `AGENTS.md` → Versioning). On la lit ici plutôt que de dupliquer un numéro
 * dans `package.json`, qui finirait par diverger.
 */
function readProjectVersion(): string {
  try {
    const pubspec = fs.readFileSync(path.resolve(__dirname, '..', 'pubspec.yaml'), 'utf8');
    const match = pubspec.match(/^version:\s*(\S+)/m);
    return match ? match[1] : '0.0.0';
  } catch {
    return '0.0.0';
  }
}

export default defineConfig(() => {
  const version = readProjectVersion();

  return {
    plugins: [react()],

    define: {
      __APP_VERSION__: JSON.stringify(version),
    },

    resolve: {
      alias: {
        '@': path.resolve(__dirname, 'src'),
      },
    },

    build: {
      outDir: 'dist',
      sourcemap: false,
      // Le backoffice n'est pas un site public : un chunk unique évite les
      // allers-retours réseau sur une connexion dégradée.
      chunkSizeWarningLimit: 1200,
    },

    server: {
      port: 3000,
      host: '0.0.0.0',
      // HMR désactivé dans AI Studio via DISABLE_HMR — conservé tel quel.
      hmr: process.env.DISABLE_HMR !== 'true',
      watch: process.env.DISABLE_HMR === 'true' ? null : {},
    },
  };
});
