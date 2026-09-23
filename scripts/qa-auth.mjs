import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { spawn, execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const apiPort = 18082;
const server = createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  res.setHeader('Content-Type', 'application/json');
  if (url.pathname === '/sns/jscode2session') {
    res.end(JSON.stringify(url.searchParams.get('js_code') === 'qa-valid'
      ? { openid: 'qa_lecheng_auth_openid', session_key: 'mock-private-key' }
      : { errcode: 40029, errmsg: 'invalid code' }));
  } else if (url.pathname === '/cgi-bin/token') {
    res.end(JSON.stringify({ access_token: 'qa-wechat-token', expires_in: 7200 }));
  } else if (url.pathname === '/wxa/business/getuserphonenumber') {
    let body = '';
    for await (const chunk of req) body += chunk;
    res.end(JSON.stringify(JSON.parse(body).code === 'qa-phone'
      ? { errcode: 0, phone_info: { purePhoneNumber: '13800138000' } }
      : { errcode: 40029 }));
  } else { res.statusCode = 404; res.end('{}'); }
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const mockPort = server.address().port;
const jar = resolve('ruoyi-admin/target/ruoyi-admin.jar');
const app = spawn('java', ['-jar', jar, `--server.port=${apiPort}`], {
  env: { ...process.env, LECHENG_WECHAT_APP_ID: 'qa-app', LECHENG_WECHAT_APP_SECRET: 'qa-secret',
    LECHENG_WECHAT_API_BASE: `http://127.0.0.1:${mockPort}` }, stdio: 'ignore', windowsHide: true,
});
const base = `http://127.0.0.1:${apiPort}`;
const call = async (path, body, headers = {}) => {
  const response = await fetch(base + path, { method: body === undefined ? 'GET' : 'POST',
    headers: { 'Content-Type': 'application/json', ...headers },
    body: body === undefined ? undefined : JSON.stringify(body) });
  return { status: response.status, data: await response.json() };
};
const ready = async () => {
  for (let i = 0; i < 100; i++) {
    if (app.exitCode !== null) throw new Error('Backend exited during startup');
    try { await fetch(base + '/open/lecheng/content/hospital'); return; } catch {}
    await new Promise(resolve => setTimeout(resolve, 300));
  }
  throw new Error('Backend did not start');
};
try {
  await ready();
  assert.equal((await call('/auth/me')).status, 401);
  assert.equal((await call('/auth/wechat', { code: 'bad' })).status, 401);
  assert.equal((await call('/auth/phone', { code: 'qa-valid', phoneCode: 'bad' })).status, 401);
  const logged = await call('/auth/phone', { code: 'qa-valid', phoneCode: 'qa-phone' });
  assert.equal(logged.status, 200);
  assert.equal(logged.data.user.phone, '13800138000');
  assert.equal(logged.data.accessToken.length, 43);
  assert.equal(Object.values(logged.data).includes('mock-private-key'), false);
  const first = logged.data;
  const me = await call('/auth/me', undefined, { 'X-Lecheng-Access': first.accessToken });
  assert.equal(me.data.id, first.user.id);
  const changed = await fetch(base + '/auth/me', { method: 'PUT',
    headers: { 'Content-Type': 'application/json', 'X-Lecheng-Access': first.accessToken },
    body: JSON.stringify({ name: '联调测试用户' }) });
  assert.equal(changed.status, 200);
  assert.equal((await changed.json()).name, '联调测试用户');
  const refreshed = await call('/auth/refresh', { refreshToken: first.refreshToken });
  assert.equal(refreshed.status, 200);
  assert.notEqual(refreshed.data.accessToken, first.accessToken);
  assert.equal((await call('/auth/refresh', { refreshToken: first.refreshToken })).status, 401);
  assert.equal((await call('/auth/me', undefined, { 'X-Lecheng-Access': first.accessToken })).status, 401);
  assert.equal((await call('/auth/logout', { refreshToken: refreshed.data.refreshToken })).status, 200);
  assert.equal((await call('/auth/me', undefined, { 'X-Lecheng-Access': refreshed.data.accessToken })).status, 401);
  console.log('AUTH PASS: code exchange, phone verification, account, refresh rotation, logout');
} finally {
  app.kill(); server.close();
  // Remove only this test principal and its sessions from the local development database.
  try {
    const yml = readFileSync('ruoyi-admin/src/main/resources/application-druid.yml', 'utf8');
    const password = yml.match(/^\s*password:\s*(\S+)/m)?.[1];
    if (password) execFileSync('mysql', ['-uroot', '-D', 'ha', '-e',
      "DELETE FROM lc_auth_session WHERE account_id IN (SELECT id FROM lc_account WHERE openid='qa_lecheng_auth_openid'); DELETE FROM lc_account WHERE openid='qa_lecheng_auth_openid';"],
      { env: { ...process.env, MYSQL_PWD: password }, stdio: 'ignore', windowsHide: true });
  } catch { console.warn('QA account cleanup skipped; remove qa_lecheng_auth_openid if needed.'); }
}
