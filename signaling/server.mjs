import { createServer } from "node:http";
import { createCipheriv, createDecipheriv, createHash, randomBytes, randomUUID, scryptSync, timingSafeEqual } from "node:crypto";

const MAX_PLAYERS = 4;
const ROOM_TTL_MS = 30 * 60 * 1000;
const PEER_TTL_MS = 90 * 1000;
const jsonHeaders = { "content-type": "application/json; charset=utf-8", "access-control-allow-origin": "*", "access-control-allow-headers": "content-type,x-room-token,authorization", "access-control-allow-methods": "GET,POST,OPTIONS" };
const profileSecret = process.env.BID_PROFILE_SECRET ?? "development-only-change-this-secret";
const profileKey = createHash("sha256").update(profileSecret).digest();

const roomId = () => randomBytes(4).toString("hex").toUpperCase();
const token = () => randomBytes(24).toString("base64url");
const send = (response, status, value) => {
	response.writeHead(status, jsonHeaders);
	response.end(JSON.stringify(value));
};

async function bodyOf(request) {
	let body = "";
	for await (const chunk of request) {
		body += chunk;
		if (body.length > 32_000) throw new Error("payload too large");
	}
	return body ? JSON.parse(body) : {};
}

function passwordRecord(password) {
	const salt = randomBytes(16);
	return { salt, hash: scryptSync(password, salt, 32) };
}

function matchesPassword(room, password) {
	if (!room.password) return true;
	const candidate = scryptSync(password ?? "", room.password.salt, 32);
	return timingSafeEqual(candidate, room.password.hash);
}

function bearerToken(request) {
	const value = request.headers.authorization ?? "";
	return value.startsWith("Bearer ") ? value.slice(7) : "";
}

function profileCode(payload) {
	const iv = randomBytes(12);
	const cipher = createCipheriv("aes-256-gcm", profileKey, iv);
	cipher.setAAD(Buffer.from("BID_PROFILE_V1"));
	const encrypted = Buffer.concat([cipher.update(JSON.stringify(payload), "utf8"), cipher.final()]);
	return ["BID1", iv, cipher.getAuthTag(), encrypted].map((value, index) => index === 0 ? value : Buffer.from(value).toString("base64url")).join(".");
}

function readProfileCode(code) {
	const parts = String(code ?? "").split(".");
	if (parts.length !== 4 || parts[0] !== "BID1") throw new Error("프로필 코드 형식이 올바르지 않습니다.");
	const decipher = createDecipheriv("aes-256-gcm", profileKey, Buffer.from(parts[1], "base64url"));
	decipher.setAAD(Buffer.from("BID_PROFILE_V1"));
	decipher.setAuthTag(Buffer.from(parts[2], "base64url"));
	const text = Buffer.concat([decipher.update(Buffer.from(parts[3], "base64url")), decipher.final()]).toString("utf8");
	const payload = JSON.parse(text);
	if (!payload.uid || !payload.profile || !payload.issuedAt) throw new Error("프로필 데이터가 올바르지 않습니다.");
	return payload;
}

function publicRoom(room) {
	return { id: room.id, name: room.name, players: room.peers.size, maxPlayers: MAX_PLAYERS, private: Boolean(room.password) };
}

export function createSignalingServer({ now = () => Date.now() } = {}) {
	const rooms = new Map();
	const accounts = new Map();
	const sessions = new Map();
	const cleanRooms = () => {
		const expires = now() - PEER_TTL_MS;
		for (const [id, room] of rooms) {
			if (room.touchedAt < now() - ROOM_TTL_MS || room.peers.get(1)?.seenAt < expires) {
				rooms.delete(id);
				continue;
			}
			for (const [peerId, peer] of room.peers) {
				if (peerId === 1 || peer.seenAt >= expires) continue;
				room.peers.delete(peerId);
				room.queues.delete(peerId);
				for (const remainingId of room.peers.keys()) room.queues.get(remainingId)?.push({ type: "peer_leave", peerId });
			}
		}
	};
	const authenticate = (request, room, peerId) => {
		const peer = room?.peers.get(peerId);
		const provided = request.headers["x-room-token"];
		return Boolean(peer && typeof provided === "string" && provided.length > 0 && peer.token === provided);
	};
	const enqueue = (room, peerId, message) => room.queues.get(peerId)?.push(message);
	const accountFor = request => accounts.get(sessions.get(bearerToken(request)));

	return createServer(async (request, response) => {
		if (request.method === "OPTIONS") return send(response, 204, {});
		try {
			cleanRooms();
			const url = new URL(request.url, "http://signal.local");
			const parts = url.pathname.split("/").filter(Boolean);
			if (request.method === "POST" && url.pathname === "/auth/register") {
				const input = await bodyOf(request);
				const username = String(input.username ?? "").trim().slice(0, 24);
				const password = String(input.password ?? "");
				if (!/^[A-Za-z0-9_-]{3,24}$/.test(username)) return send(response, 400, { error: "아이디 형식이 올바르지 않습니다." });
				if (password.length < 8) return send(response, 400, { error: "비밀번호는 8자 이상이어야 합니다." });
				if (accounts.has(username)) return send(response, 409, { error: "이미 사용 중인 아이디입니다." });
				const passwordData = passwordRecord(password);
				const account = { username, uid: randomUUID(), ...passwordData };
				accounts.set(username, account);
				const auth = token();
				sessions.set(auth, username);
				return send(response, 201, { username, uid: account.uid, token: auth });
			}
			if (request.method === "POST" && url.pathname === "/auth/login") {
				const input = await bodyOf(request);
				const account = accounts.get(String(input.username ?? "").trim());
				if (!account) return send(response, 401, { error: "아이디 또는 비밀번호가 맞지 않습니다." });
				const candidate = scryptSync(String(input.password ?? ""), account.salt, 32);
				if (!timingSafeEqual(candidate, account.hash)) return send(response, 401, { error: "아이디 또는 비밀번호가 맞지 않습니다." });
				const auth = token();
				sessions.set(auth, account.username);
				return send(response, 200, { username: account.username, uid: account.uid, token: auth });
			}
			if (request.method === "POST" && (url.pathname === "/profiles/export" || url.pathname === "/profiles/import")) {
				const account = accountFor(request);
				if (!account) return send(response, 401, { error: "로그인이 필요합니다." });
				const input = await bodyOf(request);
				if (url.pathname === "/profiles/export") {
					const profile = input.profile;
					if (!profile || typeof profile !== "object") return send(response, 400, { error: "프로필 형식이 올바르지 않습니다." });
					return send(response, 200, { code: profileCode({ uid: account.uid, profile, issuedAt: Date.now() }), uid: account.uid });
				}
				const payload = readProfileCode(input.code);
				if (payload.uid !== account.uid) return send(response, 409, { error: "UID가 현재 계정과 다릅니다. 중복 UID 가능성이 있어 가져오기를 거부했습니다." });
				return send(response, 200, { uid: account.uid, profile: payload.profile });
			}
			if (request.method === "GET" && url.pathname === "/rooms") {
				return send(response, 200, { rooms: [...rooms.values()].map(publicRoom) });
			}
			if (request.method === "POST" && url.pathname === "/rooms") {
				const input = await bodyOf(request);
				const name = String(input.name ?? "BID! 방").trim().slice(0, 24) || "BID! 방";
				const privateRoom = Boolean(input.private);
				const password = String(input.password ?? "");
				if (privateRoom && password.length < 4) return send(response, 400, { error: "비밀번호는 4자 이상이어야 합니다." });
				const id = roomId();
				const hostToken = token();
				rooms.set(id, { id, name, password: privateRoom ? passwordRecord(password) : null, peers: new Map([[1, { token: hostToken, seenAt: now() }]]), queues: new Map([[1, []]]), nextPeerId: 2, touchedAt: now() });
				return send(response, 201, { room: { ...publicRoom(rooms.get(id)), private: privateRoom }, peerId: 1, token: hostToken });
			}
			const room = rooms.get(parts[1]);
			if (!room) return send(response, 404, { error: "방을 찾을 수 없습니다." });
			if (request.method === "POST" && parts[2] === "join") {
				const input = await bodyOf(request);
				if (room.peers.size >= MAX_PLAYERS) return send(response, 409, { error: "방이 가득 찼습니다." });
				if (!matchesPassword(room, input.password)) return send(response, 401, { error: "비밀번호가 맞지 않습니다." });
				const peerId = room.nextPeerId++;
				const peerToken = token();
				room.peers.set(peerId, { token: peerToken, seenAt: now() });
				room.queues.set(peerId, []);
				for (const existingId of room.peers.keys()) {
					if (existingId !== peerId) enqueue(room, existingId, { type: "peer_join", peerId });
				}
				return send(response, 200, { room: publicRoom(room), peerId, token: peerToken });
			}
			const peerId = Number(url.searchParams.get("peer"));
			if (!authenticate(request, room, peerId)) return send(response, 401, { error: "유효하지 않은 방 권한입니다." });
			room.peers.get(peerId).seenAt = now();
			room.touchedAt = now();
			if (request.method === "GET" && parts[2] === "messages") {
				const messages = room.queues.get(peerId) ?? [];
				room.queues.set(peerId, []);
				return send(response, 200, { messages });
			}
			if (request.method === "POST" && parts[2] === "signal") {
				const input = await bodyOf(request);
				const recipient = Number(input.to);
				if (!room.peers.has(recipient) || recipient === peerId) return send(response, 400, { error: "대상을 찾을 수 없습니다." });
				const message = input.message;
				if (!message || typeof message !== "object" || !["offer", "answer", "candidate", "voice-offer", "voice-answer", "voice-candidate"].includes(message.type) || JSON.stringify(message).length > 24_000) return send(response, 400, { error: "유효하지 않은 신호입니다." });
				enqueue(room, recipient, { ...message, from: peerId });
				return send(response, 202, { ok: true });
			}
			if (request.method === "POST" && parts[2] === "leave") {
				if (peerId === 1) {
					rooms.delete(room.id);
					return send(response, 200, { ok: true, roomClosed: true });
				}
				room.peers.delete(peerId);
				room.queues.delete(peerId);
				for (const remainingId of room.peers.keys()) enqueue(room, remainingId, { type: "peer_leave", peerId });
				return send(response, 200, { ok: true });
			}
			return send(response, 404, { error: "알 수 없는 요청입니다." });
		} catch (error) {
			return send(response, 400, { error: error instanceof Error ? error.message : "잘못된 요청입니다." });
		}
	});
}

if (process.argv[1] === new URL(import.meta.url).pathname) {
	const port = Number(process.env.PORT ?? 8787);
	createSignalingServer().listen(port, () => console.log(`BID! signaling server listening on ${port}`));
}
