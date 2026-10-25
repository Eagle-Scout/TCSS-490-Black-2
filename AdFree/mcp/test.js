#!/usr/bin/env node
// Tests the MCP server without the app: a mock app answers through the same mailbox.
// Run: node AdFree/mcp/test.js
'use strict';
const { spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const assert = require('assert');

const bridge = fs.mkdtempSync(path.join(os.tmpdir(), 'adfree-bridge-'));
const requests = path.join(bridge, 'requests'), responses = path.join(bridge, 'responses');
fs.mkdirSync(requests); fs.mkdirSync(responses);

const server = spawn('node', [path.join(__dirname, 'server.js')], { env: { ...process.env, ADFREE_BRIDGE: bridge } });
const pending = new Map();
let nextId = 1;
require('readline').createInterface({ input: server.stdout }).on('line', (line) => {
  const m = JSON.parse(line);
  if (pending.has(m.id)) { pending.get(m.id)(m); pending.delete(m.id); }
});
const rpc = (method, params) => new Promise((resolve) => {
  const id = nextId++;
  pending.set(id, resolve);
  server.stdin.write(JSON.stringify({ jsonrpc: '2.0', id, method, params }) + '\n');
});
const call = (name, args) => rpc('tools/call', { name, arguments: args }).then((m) => m.result);

// Mock app: heartbeat plus a responder that records every request it receives.
const received = [];
let beat;
function startMockApp() {
  const writeStatus = () => fs.writeFileSync(path.join(bridge, 'status.json'), JSON.stringify({ pid: 1, updated: Date.now() / 1000 }));
  writeStatus();
  beat = setInterval(writeStatus, 1000);
  setInterval(() => {
    for (const f of fs.readdirSync(requests).filter((n) => n.endsWith('.json'))) {
      const req = JSON.parse(fs.readFileSync(path.join(requests, f), 'utf8'));
      fs.unlinkSync(path.join(requests, f));
      received.push(req);
      fs.writeFileSync(path.join(responses, `${req.id}.json`), JSON.stringify({ ok: true, result: `mock:${req.tool}` }));
    }
  }, 50).unref();
}

let passed = 0;
const check = (name, fn) => fn().then(() => { passed++; console.log('ok   ' + name); }, (e) => { console.log('FAIL ' + name + '\n     ' + e.message); process.exitCode = 1; });

(async () => {
  await check('handshake advertises tools and echoes the protocol version', async () => {
    const m = await rpc('initialize', { protocolVersion: '2025-03-26', capabilities: {}, clientInfo: { name: 'test', version: '0' } });
    assert.strictEqual(m.result.protocolVersion, '2025-03-26');
    assert.ok(m.result.capabilities.tools);
    const list = (await rpc('tools/list')).result.tools;
    assert.deepStrictEqual(list.map((t) => t.name).sort(),
      ['clear_site_rules', 'get_page_snapshot', 'get_report', 'list_sites', 'open_site', 'read_file', 'revert_file', 'set_layer', 'set_site_rules', 'write_file']);
  });

  await check('reports a clear error when the app is not running', async () => {
    const r = await call('get_report', {});
    assert.ok(r.isError); assert.match(r.content[0].text, /not running/);
  });

  startMockApp();

  await check('a read tool reaches the app and returns its answer', async () => {
    const r = await call('get_report', {});
    assert.ok(!r.isError); assert.strictEqual(r.content[0].text, 'mock:get_report');
  });

  const bad = [
    ['unknown file', 'read_file', { file: 'secrets.txt' }],
    ['bad domain', 'set_site_rules', { domain: 'not a domain', summary: 'x' }],
    ['selector with braces', 'set_site_rules', { domain: 'example.com', hide_selectors: ['a{color:red}'], summary: 'x' }],
    ['non-array selectors', 'set_site_rules', { domain: 'example.com', hide_selectors: 'div', summary: 'x' }],
    ['invalid JS', 'write_file', { file: 'youtube-adblock.js', content: 'function ( {', summary: 'x' }],
    ['invalid JSON', 'write_file', { file: 'ContentRules.json', content: '[{"a":', summary: 'x' }],
    ['JSON that is not a rule array', 'write_file', { file: 'ContentRules.json', content: '{"a":1}', summary: 'x' }],
    ['oversized file', 'write_file', { file: 'twitch-adblock.js', content: '//' + 'x'.repeat(200001), summary: 'x' }],
    ['unknown layer', 'set_layer', { layer: 'everything', enabled: true }],
    ['unknown tool', 'format_disk', {}],
  ];
  const before = received.length;
  for (const [name, tool, args] of bad) {
    await check(`rejects ${name} before it reaches the app`, async () => {
      const r = await call(tool, args);
      assert.ok(r.isError, 'expected an error result');
    });
  }
  await check('none of the rejected calls reached the app', async () => assert.strictEqual(received.length, before));

  await check('a valid write is forwarded and written to the audit log without its content', async () => {
    const content = '(() => { /* test */ })();';
    const r = await call('write_file', { file: 'youtube-adblock.js', content, summary: 'test edit' });
    assert.ok(!r.isError);
    const req = received[received.length - 1];
    assert.strictEqual(req.tool, 'write_file'); assert.strictEqual(req.args.content, content);
    const log = fs.readFileSync(path.join(bridge, 'audit.log'), 'utf8').trim().split('\n').map(JSON.parse);
    const entry = log[log.length - 1];
    assert.strictEqual(entry.tool, 'write_file'); assert.strictEqual(entry.outcome, 'ok');
    assert.ok(entry.args.sha256 && !('content' in entry.args));
  });

  await check('valid site rules are forwarded with trimmed values', async () => {
    const r = await call('set_site_rules', { domain: 'Example.com', hide_selectors: ['  div.ad  '], block_url_patterns: ['.*ads\\.example\\.com'], summary: 'test' });
    assert.ok(!r.isError);
    const req = received[received.length - 1];
    assert.deepStrictEqual(req.args, { domain: 'example.com', hide_selectors: ['div.ad'], block_url_patterns: ['.*ads\\.example\\.com'] });
  });

  console.log(`\n${passed} checks passed${process.exitCode ? ', some FAILED' : ''}`);
  clearInterval(beat); server.kill(); fs.rmSync(bridge, { recursive: true, force: true });
  process.exit(process.exitCode || 0);
})();
