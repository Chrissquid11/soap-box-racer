// The whole config is @vibe/pipeline's `vibe()`: the plugins, the modes, debugGuard, the server and the
// build. A project says only what is its own: here, its port -- the dev server's, held to; the preview's
// is 1000 below it unless `previewPort` says otherwise.
import { defineConfig } from 'vite';
import { vibe } from '@vibe/pipeline';
export default defineConfig(vibe({ port: 5190 }));
