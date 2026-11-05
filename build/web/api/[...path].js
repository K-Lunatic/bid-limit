const crypto = require("node:crypto");

const MAX_PLAYERS = 4;
const ROOM_TTL_MS = 30 * 60 * 1000;
const PEER_TTL_MS = 90 * 1000;
const PROFILE_TTL_SECONDS = 30 * 24 * 60 * 60;
const ROOM_INDEX = "bid:rooms";
// shortcut: without Redis this falls back to process memory; production multiplayer requires the Redis env vars.
const memoryRooms = new Map();
const memoryAccounts = new Map();
const memorySessions = new Map();
const profileSecret = process.env.BID_PROFILE_SECRET || "development-only-change-this-secret";
const profileKey = crypto.createHash("sha256").update(profileSecret).digest();

function json(res, status, value) {
  res.statusCode = status;
  res.setHeader("content-type", "application/json; charset=utf-8");
  res.setHeader("access-control-allow-origin", "*");
  res.setHeader("access-control-allow-headers", "content-type,x-room-token,authorization");
  res.setHeader("access-control-allow-methods", "GET,POST,OPTIONS");
  res.end(JSON.stringify(value));
}

function id() { return crypto.randomBytes(4).toString("hex").toUpperCase(); }
function token() { return crypto.randomBytes(24).toString("base64url"); }
function publicRoom(room) {
  return { id: room.id, name: room.name, players: Object.keys(room.peers).length, maxPlayers: MAX_PLAYERS, private: Boolean(room.password) };
}
function passwordRecord(password) {
  const salt = crypto.randomBytes(16);
  return { salt: salt.toString("base64url"), hash: crypto.scryptSync(password, salt, 32).toString("base64url") };
}
function validUsername(value) { return /^[A-Za-z0-9_-]{3,24}$/.test(String(value || "")); }
function matchesPassword(room, password) {
  if (!room.password) return true;
  const candidate = crypto.scryptSync(String(password || ""), Buffer.from(room.password.salt, "base64url"), 32);
  const expected = Buffer.from(room.password.hash, "base64url");
  return candidate.length === expected.length && crypto.timingSafeEqual(candidate, expected);
}
function bearerToken(req) {
  const value = String(req.headers.authorization || "");
  return value.startsWith("Bearer ") ? value.slice(7) : "";
}
function profileCode(payload) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv("aes-256-gcm", profileKey, iv);
  cipher.setAAD(Buffer.from("BID_PROFILE_V1"));
  const encrypted = Buffer.concat([cipher.update(JSON.stringify(payload), "utf8"), cipher.final()]);
  return ["BID1", iv, cipher.getAuthTag(), encrypted].map((value, index) => index === 0 ? value : Buffer.from(value).toString("base64url")).join(".");
}
function readProfileCode(code) {
  const parts = String(code || "").split(".");
  if (parts.length !== 4 || parts[0] !== "BID1") throw new Error("프로필 코드 형식이 올바르지 않습니다.");
  const decipher = crypto.createDecipheriv("aes-256-gcm", profileKey, Buffer.from(parts[1], "base64url"));
  decipher.setAAD(Buffer.from("BID_PROFILE_V1"));
  decipher.setAuthTag(Buffer.from(parts[2], "base64url"));
  const text = Buffer.concat([decipher.update(Buffer.from(parts[3], "base64url")), decipher.final()]).toString("utf8");
  const payload = JSON.parse(text);
  if (!payload.uid || !payload.profile || !payload.issuedAt) throw new Error("프로필 데이터가 올바르지 않습니다.");
  return payload;
}
function validRoomId(value) { return /^[A-F0-9]{8}$/.test(String(value || "")); }
async function bodyOf(req) {
  let body = "";
  for await (const chunk of req) {
    body += chunk;
    if (body.length > 32000) throw new Error("payload too large");
  }
  return body ? JSON.parse(body) : {};
}

function redisConfigured() {
  return Boolean(redisUrl() && redisToken());
}
function redisUrl() { return process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL || ""; }
function redisToken() { return process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN || ""; }
async function redisPipeline(commands) {
  const response = await fetch(`${redisUrl()}/pipeline`, {
    method: "POST",
    headers: { authorization: `Bearer ${redisToken()}`, "content-type": "application/json" },
    body: JSON.stringify(commands),
  });
  if (!response.ok) throw new Error(`Redis request failed (${response.status})`);
  const result = await response.json();
  return result.map(entry => entry.error ? (() => { throw new Error(entry.error); })() : entry.result);
}
async function redisGet(key) { return (await redisPipeline([["GET", key]]))[0]; }
async function redisPush(key, value) { await redisPipeline([["RPUSH", key, JSON.stringify(value)], ["EXPIRE", key, "1800"]]); }
async function redisTake(key) {
  const script = "local values=redis.call('LRANGE',KEYS[1],0,-1); redis.call('DEL',KEYS[1]); return values";
  const values = (await redisPipeline([["EVAL", script, "1", key]]))[0] || [];
  return values.map(value => JSON.parse(value));
}
async function redisSetPresence(roomId, peerId) {
  await redisPipeline([["SET", `bid:presence:${roomId}:${peerId}`, String(Date.now()), "EX", String(Math.ceil(PEER_TTL_MS / 1000))]]);
}
async function redisGetPresence(roomId, peerId, fallback = 0) {
  const value = await redisGet(`bid:presence:${roomId}:${peerId}`);
  return value ? Number(value) : fallback;
}
async function touchPeer(room, peerId) {
  const now = Date.now();
  if (!redisConfigured()) {
    room.peers[peerId].seenAt = now;
    room.touchedAt = now;
    memoryRooms.set(room.id, room);
    return;
  }
  await redisSetPresence(room.id, peerId);
}
async function withRoomLock(roomId, work) {
  if (!redisConfigured()) return work();
  const lockKey = `bid:lock:${roomId}`;
  const lockToken = token();
  for (let attempt = 0; attempt < 20; attempt += 1) {
    const locked = (await redisPipeline([["SET", lockKey, lockToken, "NX", "EX", "5"]]))[0];
    if (locked === "OK") {
      try {
        return await work();
      } finally {
        const release = "if redis.call('GET',KEYS[1]) == ARGV[1] then return redis.call('DEL',KEYS[1]) else return 0 end";
        await redisPipeline([["EVAL", release, "1", lockKey, lockToken]]);
      }
    }
    await new Promise(resolve => setTimeout(resolve, 25));
  }
  throw new Error("방 상태가 잠시 사용 중입니다. 다시 시도해 주세요.");
}
function accountKey(username) { return `bid:account:${username}`; }
function sessionKey(authToken) { return `bid:session:${authToken}`; }
async function getAccount(username) {
  if (!redisConfigured()) return memoryAccounts.get(username) || null;
  const value = await redisGet(accountKey(username));
  return value ? JSON.parse(value) : null;
}
async function saveAccount(account) {
  if (!redisConfigured()) {
    memoryAccounts.set(account.username, account);
    return;
  }
  await redisPipeline([["SET", accountKey(account.username), JSON.stringify(account), "EX", String(PROFILE_TTL_SECONDS)]]);
}
async function saveSession(authToken, username) {
  if (!redisConfigured()) {
    memorySessions.set(authToken, username);
    return;
  }
  await redisPipeline([["SET", sessionKey(authToken), username, "EX", String(PROFILE_TTL_SECONDS)]]);
}
async function accountFor(req) {
  const authToken = bearerToken(req);
  if (!authToken) return null;
  const username = redisConfigured() ? await redisGet(sessionKey(authToken)) : memorySessions.get(authToken);
  return username ? getAccount(username) : null;
}

async function listRoomIds() {
  if (!redisConfigured()) return [...memoryRooms.keys()];
  return (await redisPipeline([["SMEMBERS", ROOM_INDEX]]))[0] || [];
}
async function loadRoom(roomId) {
  if (!validRoomId(roomId)) return null;
  if (!redisConfigured()) return memoryRooms.get(roomId) || null;
  const value = await redisGet(`bid:room:${roomId}`);
  return value ? JSON.parse(value) : null;
}
async function saveRoom(room) {
  if (!redisConfigured()) {
    memoryRooms.set(room.id, room);
    return;
  }
  await redisPipeline([["SET", `bid:room:${room.id}`, JSON.stringify(room), "EX", "1800"], ["SADD", ROOM_INDEX, room.id]]);
}
async function removeRoom(room) {
  if (!redisConfigured()) {
    memoryRooms.delete(room.id);
    return;
  }
  const commands = [["DEL", `bid:room:${room.id}`], ["SREM", ROOM_INDEX, room.id], ["DEL", `bid:lock:${room.id}`]];
  for (const peerId of Object.keys(room.peers)) commands.push(["DEL", `bid:queue:${room.id}:${peerId}`, `bid:presence:${room.id}:${peerId}`]);
  await redisPipeline(commands);
}
async function enqueue(room, peerId, message) {
  if (!room.peers[peerId]) return;
  if (!redisConfigured()) {
    room.queues[peerId] ||= [];
    room.queues[peerId].push(message);
    return;
  }
  await redisPush(`bid:queue:${room.id}:${peerId}`, message);
}
async function takeMessages(room, peerId) {
  if (!redisConfigured()) {
    const messages = room.queues[peerId] || [];
    room.queues[peerId] = [];
    memoryRooms.set(room.id, room);
    return messages;
  }
  return redisTake(`bid:queue:${room.id}:${peerId}`);
}
async function cleanRooms() {
  const now = Date.now();
  for (const roomId of await listRoomIds()) {
    await withRoomLock(roomId, async () => {
      const room = await loadRoom(roomId);
      if (!room) return;
      const hostSeenAt = redisConfigured() ? await redisGetPresence(roomId, 1, room.peers[1]?.seenAt || 0) : room.peers[1]?.seenAt || 0;
      if (Math.max(room.touchedAt || 0, hostSeenAt) < now - ROOM_TTL_MS || hostSeenAt < now - PEER_TTL_MS) {
        await removeRoom(room);
        return;
      }
      let changed = false;
      for (const peerId of Object.keys(room.peers)) {
        const seenAt = redisConfigured() ? await redisGetPresence(roomId, peerId, room.peers[peerId].seenAt || 0) : room.peers[peerId].seenAt || 0;
        if (peerId === "1" || seenAt >= now - PEER_TTL_MS) continue;
        delete room.peers[peerId];
        delete room.queues[peerId];
        changed = true;
        for (const remainingId of Object.keys(room.peers)) await enqueue(room, remainingId, { type: "peer_leave", peerId: Number(peerId) });
      }
      if (changed) {
        room.touchedAt = now;
        await saveRoom(room);
      }
    });
  }
}
function getRoute(req) {
  const url = new URL(req.url, "https://bid-limit.local");
  const pathParts = url.pathname.replace(/^\/api\/?/, "").split("/").filter(Boolean);
  return {
    url,
    route: pathParts.join("/"),
    roomId: url.searchParams.get("room") || pathParts[1],
    action: url.searchParams.get("action") || pathParts[2],
    peerId: Number(url.searchParams.get("peer")),
  };
}
async function authorizedRoom(req, roomId, peerId) {
  const room = await loadRoom(roomId);
  const peer = room?.peers[peerId];
  return { room, authorized: Boolean(peer && req.headers["x-room-token"] === peer.token) };
}

module.exports = async function handler(req, res) {
  if (req.method === "OPTIONS") return json(res, 204, {});
  if (process.env.VERCEL && !redisConfigured()) return json(res, 503, { error: "멀티플레이 저장소가 아직 연결되지 않았습니다." });
  try {
    await cleanRooms();
    const { route, roomId, action, peerId } = getRoute(req);
    if (req.method === "GET" && route === "rooms" && !action) {
      const rooms = [];
      for (const listedId of await listRoomIds()) {
        const room = await loadRoom(listedId);
        if (room) rooms.push(publicRoom(room));
      }
      return json(res, 200, { rooms });
    }
    if (req.method === "POST" && route === "rooms" && !action) {
      const input = await bodyOf(req);
      const privateRoom = Boolean(input.private);
      const password = String(input.password || "");
      if (privateRoom && password.length < 4) return json(res, 400, { error: "비밀번호는 4자 이상이어야 합니다." });
      const room = { id: id(), name: String(input.name || "BID! 방").trim().slice(0, 24) || "BID! 방", password: privateRoom ? passwordRecord(password) : null, peers: { 1: { token: token(), seenAt: Date.now() } }, queues: { 1: [] }, nextPeerId: 2, touchedAt: Date.now() };
      await saveRoom(room);
      if (redisConfigured()) await redisSetPresence(room.id, 1);
      return json(res, 201, { room: publicRoom(room), peerId: 1, token: room.peers[1].token });
    }

    if (req.method === "POST" && (route === "auth/register" || route === "auth/login")) {
      const input = await bodyOf(req);
      const username = String(input.username || "").trim().slice(0, 24);
      const password = String(input.password || "");
      if (!validUsername(username)) return json(res, 400, { error: "아이디 형식이 올바르지 않습니다." });
      if (password.length < 8) return json(res, 400, { error: "비밀번호는 8자 이상이어야 합니다." });
      const existing = await getAccount(username);
      if (route === "auth/register") {
        if (existing) return json(res, 409, { error: "이미 사용 중인 아이디입니다." });
        const passwordData = passwordRecord(password);
        const account = { username, uid: crypto.randomUUID(), ...passwordData };
        await saveAccount(account);
        const auth = token();
        await saveSession(auth, username);
        return json(res, 201, { username, uid: account.uid, token: auth });
      }
      if (!existing) return json(res, 401, { error: "아이디 또는 비밀번호가 맞지 않습니다." });
      const candidate = crypto.scryptSync(password, Buffer.from(existing.salt, "base64url"), 32);
      const expected = Buffer.from(existing.hash, "base64url");
      if (candidate.length !== expected.length || !crypto.timingSafeEqual(candidate, expected)) return json(res, 401, { error: "아이디 또는 비밀번호가 맞지 않습니다." });
      const auth = token();
      await saveSession(auth, username);
      return json(res, 200, { username: existing.username, uid: existing.uid, token: auth });
    }
    if (req.method === "POST" && (route === "profiles/export" || route === "profiles/import")) {
      const account = await accountFor(req);
      if (!account) return json(res, 401, { error: "로그인이 필요합니다." });
      const input = await bodyOf(req);
      if (route === "profiles/export") {
        if (!input.profile || typeof input.profile !== "object") return json(res, 400, { error: "프로필 형식이 올바르지 않습니다." });
        return json(res, 200, { code: profileCode({ uid: account.uid, profile: input.profile, issuedAt: Date.now() }), uid: account.uid });
      }
      const payload = readProfileCode(input.code);
      if (payload.uid !== account.uid) return json(res, 409, { error: "UID가 현재 계정과 다릅니다. 중복 UID 가능성이 있어 가져오기를 거부했습니다." });
      return json(res, 200, { uid: account.uid, profile: payload.profile });
    }

    if (req.method === "POST" && action === "join") {
      return await withRoomLock(roomId, async () => {
        const input = await bodyOf(req);
        const room = await loadRoom(roomId);
        if (!room) return json(res, 404, { error: "방을 찾을 수 없습니다." });
        if (Object.keys(room.peers).length >= MAX_PLAYERS) return json(res, 409, { error: "방이 가득 찼습니다." });
        if (!matchesPassword(room, input.password)) return json(res, 401, { error: "비밀번호가 맞지 않습니다." });
        const joinedId = room.nextPeerId++;
        const joinedToken = token();
        room.peers[joinedId] = { token: joinedToken, seenAt: Date.now() };
        room.queues[joinedId] = [];
        room.touchedAt = Date.now();
        await saveRoom(room);
        if (redisConfigured()) await redisSetPresence(room.id, joinedId);
        for (const existingId of Object.keys(room.peers)) if (Number(existingId) !== joinedId) await enqueue(room, existingId, { type: "peer_join", peerId: joinedId });
        return json(res, 200, { room: publicRoom(room), peerId: joinedId, token: joinedToken });
      });
    }
    const { room, authorized } = await authorizedRoom(req, roomId, peerId);
    if (!room) return json(res, 404, { error: "방을 찾을 수 없습니다." });
    if (!authorized) return json(res, 401, { error: "유효하지 않은 방 권한입니다." });
    await touchPeer(room, peerId);
    if (req.method === "GET" && action === "messages") {
      const messages = await takeMessages(room, peerId);
      return json(res, 200, { messages });
    }
    if (req.method === "POST" && action === "signal") {
      const input = await bodyOf(req);
      const message = input.message;
      const recipient = Number(input.to);
      const allowed = ["offer", "answer", "candidate", "voice-offer", "voice-answer", "voice-candidate"];
      if (!room.peers[recipient] || recipient === peerId || !message || !allowed.includes(message.type) || JSON.stringify(message).length > 24000) return json(res, 400, { error: "유효하지 않은 신호입니다." });
      await enqueue(room, recipient, { ...message, from: peerId });
      return json(res, 202, { ok: true });
    }
    if (req.method === "POST" && action === "leave") {
      return await withRoomLock(roomId, async () => {
        const latest = await loadRoom(roomId);
        if (!latest) return json(res, 404, { error: "방을 찾을 수 없습니다." });
        if (peerId === 1) await removeRoom(latest);
        else {
          delete latest.peers[peerId];
          delete latest.queues[peerId];
          await saveRoom(latest);
          if (redisConfigured()) await redisPipeline([["DEL", `bid:presence:${roomId}:${peerId}`]]);
          for (const remainingId of Object.keys(latest.peers)) await enqueue(latest, remainingId, { type: "peer_leave", peerId });
        }
        return json(res, 200, { ok: true, roomClosed: peerId === 1 });
      });
    }
    return json(res, 404, { error: "알 수 없는 요청입니다." });
  } catch (error) {
    return json(res, 400, { error: error instanceof Error ? error.message : "잘못된 요청입니다." });
  }
};
