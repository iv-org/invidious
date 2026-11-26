#!/usr/bin/env node

/**
 * Bundle googlevideo from npm using esbuild, for the SABR player.
 *
 * Only googlevideo needs it: its package is made of modules that import
 * @bufbuild/protobuf. youtubei.js and bgutils-js are downloaded from npm at build
 * time by scripts/fetch-sabr-dependencies.cr, as browsers can load them as they are.
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
  writeVersionMarker('googlevideo');
  fs.unlinkSync(googlevideoEntryPath);
}).catch((err) => {
  console.error('✗ googlevideo bundling failed:', err);
  try { fs.unlinkSync(googlevideoEntryPath); } catch (e) {}
  process.exit(1);
});

// Record a library's bundled version next to its bundle. Only called once that
// bundle was built: a failed build keeps the previous marker, so the build-time
// check (scripts/fetch-sabr-dependencies.cr) still sees the old version.
function writeVersionMarker(name) {
  const { version } = JSON.parse(fs.readFileSync(path.join(nodeModules, name, 'package.json'), 'utf8'));
  fs.writeFileSync(path.join(outputDir, name, 'versions.yml'), `---\nversion: ${version}\n`);
}
