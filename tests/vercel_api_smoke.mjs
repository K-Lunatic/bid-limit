import assert from 'node:assert/strict';
import handler from '../build/web/api/[...path].js';

async function request(url, { method = 'GET', body, headers = {} } = {}) {
  let result;
  const req = {
    url,
    method,
    headers,
    async *[Symbol.asyncIterator]() {
      if (body !== undefined) yield Buffer.from(JSON.stringify(body));
    },
  };
  const res = {
    statusCode: 200,
    headers: {},
    setHeader(name, value) { this.headers[name] = value; },
    end(value) { result = { status: this.statusCode, headers: this.headers, body: JSON.parse(value || '{}') }; },
  };
  await handler(req, res);
  return result;
}

const registered = await request('/api/auth/register', { method: 'POST', body: { username: 'api_smoke_user', password: 'correct-horse' } });
assert.equal(registered.status, 201);
const login = await request('/api/auth/login', { method: 'POST', body: { username: 'api_smoke_user', password: 'correct-horse' } });
assert.equal(login.status, 200);
const auth = { authorization: `Bearer ${login.body.token}` };
const exported = await request('/api/profiles/export', { method: 'POST', headers: auth, body: { profile: { sock: 'e15a67', hair: '35a7d7' } } });
assert.equal(exported.status, 200);
const imported = await request('/api/profiles/import', { method: 'POST', headers: auth, body: { code: exported.body.code } });
assert.deepEqual(imported.body.profile, { sock: 'e15a67', hair: '35a7d7' });

const host = await request('/api/rooms', { method: 'POST', body: { name: 'API smoke', private: false } });
assert.equal(host.status, 201);
const joins = await Promise.all([
  request(`/api/rooms/${host.body.room.id}/join`, { method: 'POST' }),
  request(`/api/rooms/${host.body.room.id}/join`, { method: 'POST' }),
]);
assert.deepEqual(joins.map(join => join.body.peerId).sort((a, b) => a - b), [2, 3]);
const signal = await request(`/api/rooms/${host.body.room.id}/signal?peer=${host.body.peerId}`, {
  method: 'POST',
  headers: { 'x-room-token': host.body.token },
  body: { to: 2, message: { type: 'candidate', candidate: { candidate: 'smoke' } } },
});
assert.equal(signal.status, 202);
const messages = await request(`/api/rooms/${host.body.room.id}/messages?peer=2`, { headers: { 'x-room-token': joins[0].body.token } });
assert.equal(messages.body.messages.filter(message => message.type === 'candidate').length, 1);
assert.equal(messages.headers['access-control-allow-headers'], 'content-type,x-room-token,authorization');
console.log('Vercel API auth, profile, concurrent join and signal queue: PASS');
