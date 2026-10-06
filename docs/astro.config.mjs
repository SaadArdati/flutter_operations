import {defineConfig} from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  // Set DOCS_BASE=/flutter_operations for a repository-subpath deployment.
  base: process.env.DOCS_BASE || '/',
  site: process.env.DOCS_SITE || undefined,
  integrations: [starlight({
    title: 'flutter_operations',
    description: 'Typed async state. Explicit execution ownership. Flutter operations 4.0.',
    favicon: '/favicon.svg',
    customCss: ['./src/styles/docs.css'],
    sidebar: [
      { label: 'Interactive demo ↗', link: '/demo/', attrs: { target: '_blank', rel: 'noopener noreferrer', 'aria-label': 'Interactive demo (opens in a new tab)' } },
      { label: 'Start here', items: [
        { label: 'Introduction', slug: '' },
        { label: 'Installation & first operation', slug: 'start/installation' },
        { label: 'Choose an owner', slug: 'start/ownership' },
      ] },
      { label: 'Understand the model', items: [{ autogenerate: { directory: 'concepts' } }] },
      { label: 'Execution API', items: [{ autogenerate: { directory: 'reference' } }] },
      { label: 'Implementation guides', items: [{ autogenerate: { directory: 'guides' } }] },
      { label: 'State-management integrations', items: [{ autogenerate: { directory: 'integrations' } }] },
    ],
  })],
});
