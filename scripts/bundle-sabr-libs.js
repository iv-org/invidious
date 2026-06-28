#!/usr/bin/env node

/**
 * Bundle SABR libraries (googlevideo, youtubei.js, bgutils-js) using esbuild
 * This creates properly bundled files with all necessary exports
 */

import * as esbuild from 'esbuild';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const nodeModules = path.join(__dirname, '../node_modules');
const outputDir = path.join(__dirname, '../assets/js/sabr');

// Ensure output directories exist
fs.mkdirSync(path.join(outputDir, 'googlevideo'), { recursive: true });
fs.mkdirSync(path.join(outputDir, 'youtubei.js'), { recursive: true });
fs.mkdirSync(path.join(outputDir, 'bgutils-js'), { recursive: true });

// Create a custom entry point that exposes the googlevideo namespaces the
// SABR scheme plugin / manifest parser need (ump, utils, protos) as a single
// `googlevideo` object, so sabr_loader.js can do window.googlevideo = googlevideo.
// sabr-streaming-adapter is no longer used (we ported FreeTube's sabr: scheme plugin).
const googlevideoEntryContent = `
import * as utils from 'googlevideo/utils';
import * as ump from 'googlevideo/ump';
import * as protos from 'googlevideo/protos';

export const googlevideo = { utils, ump, protos };
// Also re-export flat for convenience / debugging on window.
export { utils, ump, protos };
`;

const googlevideoEntryPath = path.join(__dirname, 'temp-googlevideo-entry.js');
fs.writeFileSync(googlevideoEntryPath, googlevideoEntryContent);

const commonEsbuildOptions = {
  bundle: true,
  format: 'esm',
  minify: true,
  sourcemap: false,
  external: [],
  nodePaths: [nodeModules],
  platform: 'browser',
  define: {
    'process.env.NODE_ENV': '"production"',
    'process.env.SUPPORTS_LOCAL_API': 'true'
  }
};

// Bundle googlevideo with all exports
esbuild.build({
  ...commonEsbuildOptions,
  entryPoints: [googlevideoEntryPath],
  outfile: path.join(outputDir, 'googlevideo/googlevideo.bundle.min.js'),
  banner: { js: '// googlevideo library - bundled with esbuild' }
}).then(() => {
  console.log('✓ googlevideo bundled successfully');
  fs.unlinkSync(googlevideoEntryPath);
}).catch((err) => {
  console.error('✗ googlevideo bundling failed:', err);
  try { fs.unlinkSync(googlevideoEntryPath); } catch (e) {}
  process.exit(1);
});

// youtubei.js is fetched as a pre-built browser bundle from jsDelivr by
// scripts/fetch-sabr-dependencies.cr (not bundled here), to avoid re-bundling
// a large lib and clobbering the pre-built artifact.

// Bundle bgutils-js
esbuild.build({
  ...commonEsbuildOptions,
  entryPoints: [path.join(nodeModules, 'bgutils-js/dist/index.js')],
  outfile: path.join(outputDir, 'bgutils-js/bgutils.bundle.min.js'),
  banner: { js: '// bgutils-js library - bundled with esbuild' }
}).then(() => {
  console.log('✓ bgutils-js bundled successfully');
}).catch((err) => {
  console.error('✗ bgutils-js bundling failed:', err);
  process.exit(1);
});
