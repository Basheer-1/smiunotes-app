import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const script = resolve(dirname(fileURLToPath(import.meta.url)), '../scripts/check-release-api.mjs');

test('production smoke requires explicit approved domain and never makes a request without it', () => {
  for (const candidate of [undefined, '', 'http://smiunotes.com', 'https://example.org',
    'https://smiunotes.com.evil.example', 'https://smiunotes.com/']) {
    const env = { PATH: process.env.PATH };
    if (candidate !== undefined) env.SMIUNOTES_RELEASE_API_BASE = candidate;
    const result = spawnSync(process.execPath, [script], { env, encoding: 'utf8', timeout: 5000 });
    assert.equal(result.status, 2, String(candidate));
    assert.match(result.stderr, /BLOCKED/);
  }
});
