import assert from 'node:assert/strict';
import {readdir, readFile} from 'node:fs/promises';
import {relative, resolve} from 'node:path';
import {fileURLToPath} from 'node:url';

const root = fileURLToPath(new URL('../src/content/docs/', import.meta.url));
async function pages(dir) {
  const entries = await readdir(dir, { withFileTypes: true });
  return (await Promise.all(entries.map(entry => entry.isDirectory()
    ? pages(resolve(dir, entry.name))
    : /\.mdx?$/.test(entry.name) ? [resolve(dir, entry.name)] : []))).flat();
}
const files = await pages(root);
const routes = new Set(files.map(file => relative(root, file).replace(/\.mdx?$/, '').replace(/^index$/, '')));
let links = 0;
for (const file of files) {
  const text = await readFile(file, 'utf8');
  assert.match(text, /^---\ntitle: /, `${file}: missing page title`);
  for (const match of text.matchAll(/\[[^\]]+\]\(([^)]+)\)/g)) {
    const href = match[1];
    if (/^(https?:|#|mailto:)/.test(href)) continue;
    const pageDirectory = /^index\.mdx?$/.test(relative(root, file)) ? root : file.replace(/\.mdx?$/, '');
    const slug = relative(root, resolve(pageDirectory, href))
      .split('#')[0].replace(/\/$/, '');
    assert(routes.has(slug), `${relative(root, file)}: broken page link ${href} (${slug})`);
    links++;
  }
  assert(!text.includes('data: Object()'), `${file}: object null marker`);
}
for (const route of ['start/installation', 'start/ownership', 'concepts/state', 'concepts/transitions',
  'concepts/notifications', 'reference/async-operation', 'reference/stream-operation', 'reference/mixins',
  'guides/widgets', 'guides/messages', 'guides/injection', 'guides/testing', 'guides/migration',
  'guides/examples', 'integrations/overview', 'integrations/bloc', 'integrations/provider',
  'integrations/riverpod', 'integrations/signals', 'integrations/mobx']) {
  assert(routes.has(route), `Missing required guide ${route}`);
}
console.log(`Verified ${files.length} pages, ${links} internal links, required coverage, and payload-pattern guard.`);
