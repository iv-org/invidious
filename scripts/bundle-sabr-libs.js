#!/usr/bin/env node

/**
 * Bundle SABR libraries (googlevideo, youtubei.js, bgutils-js) from npm using esbuild
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

// youtubei.js: minify the package's pre-built browser bundle (v18 no longer ships a
// minified one).
esbuild.build({
  ...commonEsbuildOptions,
  entryPoints: [path.join(nodeModules, 'youtubei.js/bundle/browser.js')],
  outfile: path.join(outputDir, 'youtubei.js/youtubei.bundle.min.js'),
  banner: { js: '// youtubei.js library - bundled with esbuild' }
}).then(() => {
  console.log('✓ youtubei.js bundled successfully');
}).catch((err) => {
  console.error('✗ youtubei.js bundling failed:', err);
  process.exit(1);
});

// Bundle bgutils-js. v4 split the package into subpath exports (botguard, webpo,
// utils) and dropped the BG namespace, so expose the pieces we use as one `BG` object.
const bgutilsEntryContent = `
import { BotGuardClient, parseChallengeData } from 'bgutils-js/botguard';
import { WebPoMinter, createColdStartToken } from 'bgutils-js/webpo';
import { buildURL, GOOG_API_KEY } from 'bgutils-js/utils';

export const BG = { BotGuardClient, parseChallengeData, WebPoMinter, createColdStartToken, buildURL, GOOG_API_KEY };
`;

const bgutilsEntryPath = path.join(__dirname, 'temp-bgutils-entry.js');
fs.writeFileSync(bgutilsEntryPath, bgutilsEntryContent);

esbuild.build({
  ...commonEsbuildOptions,
  entryPoints: [bgutilsEntryPath],
  outfile: path.join(outputDir, 'bgutils-js/bgutils.bundle.min.js'),
  banner: { js: '// bgutils-js library - bundled with esbuild' }
}).then(() => {
  console.log('✓ bgutils-js bundled successfully');
  fs.unlinkSync(bgutilsEntryPath);
}).catch((err) => {
  console.error('✗ bgutils-js bundling failed:', err);
  try { fs.unlinkSync(bgutilsEntryPath); } catch (e) {}
  process.exit(1);
});

// Record the bundled versions next to the bundles.
for (const name of ['googlevideo', 'bgutils-js', 'youtubei.js']) {
  const { version } = JSON.parse(fs.readFileSync(path.join(nodeModules, name, 'package.json'), 'utf8'));
  fs.writeFileSync(path.join(outputDir, name, 'versions.yml'), `---\nversion: ${version}\n`);
}
