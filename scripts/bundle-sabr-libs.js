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

// Create a custom entry point that re-exports everything from googlevideo
const googlevideoEntryContent = `
export * from 'googlevideo/sabr-streaming-adapter';
export * from 'googlevideo/ump';
export * from 'googlevideo/utils';
export * from 'googlevideo/protos';
`;

const googlevideoEntryPath = path.join(__dirname, 'temp-googlevideo-entry.js');
fs.writeFileSync(googlevideoEntryPath, googlevideoEntryContent);

// Bundle googlevideo with all exports
esbuild.build({
  entryPoints: [googlevideoEntryPath],
  bundle: true,
  format: 'esm',
  outfile: path.join(outputDir, 'googlevideo/googlevideo.bundle.min.js'),
  minify: true,
  sourcemap: false,
  external: [],
  nodePaths: [nodeModules],
  banner: {
    js: '// googlevideo library - bundled with esbuild'
  }
}).then(() => {
  console.log('✓ googlevideo bundled successfully');
  fs.unlinkSync(googlevideoEntryPath);
}).catch((err) => {
  console.error('✗ googlevideo bundling failed:', err);
  try { fs.unlinkSync(googlevideoEntryPath); } catch (e) {}
  process.exit(1);
});

// Bundle youtubei.js
esbuild.build({
  entryPoints: [path.join(nodeModules, 'youtubei.js/bundle/browser.js')],
  bundle: true,
  format: 'esm',
  outfile: path.join(outputDir, 'youtubei.js/youtubei.bundle.min.js'),
  minify: true,
  sourcemap: false,
  external: [],
  banner: {
    js: '// youtubei.js library - bundled with esbuild'
  }
}).then(() => {
  console.log('✓ youtubei.js bundled successfully');
}).catch((err) => {
  console.error('✗ youtubei.js bundling failed:', err);
  process.exit(1);
});

// Bundle bgutils-js
esbuild.build({
  entryPoints: [path.join(nodeModules, 'bgutils-js/dist/index.js')],
  bundle: true,
  format: 'esm',
  outfile: path.join(outputDir, 'bgutils-js/bgutils.bundle.min.js'),
  minify: true,
  sourcemap: false,
  external: [],
  banner: {
    js: '// bgutils-js library - bundled with esbuild'
  }
}).then(() => {
  console.log('✓ bgutils-js bundled successfully');
}).catch((err) => {
  console.error('✗ bgutils-js bundling failed:', err);
  process.exit(1);
});
