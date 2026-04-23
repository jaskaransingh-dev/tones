/**
 * Tones API - Cloudflare Worker (Auth + User Search)
 * Chat/Message data stored locally on iPhone
 */

import { D1Database } from '@cloudflare/d1-workers-types';

export interface Env {
	DB: D1Database;
	SESSIONS: KVNamespace;
	APPLE_CLIENT_ID: string;
	PUSH_PRIVATE_KEY: string;
	PUSH_KEY_ID: string;
	TEAM_ID: string;
	AVATAR_BUCKET?: R2Bucket;
}

const cors = {
	'Access-Control-Allow-Origin': '*',
	'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
	'Access-Control-Allow-Headers': 'Authorization, Content-Type',
};

export default {
	async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
		if (request.method === 'OPTIONS') {
			return new Response(null, { headers: cors });
		}

		const url = new URL(request.url);
		const path = url.pathname;
		const method = request.method;

		try {
			if (path === '/auth/apple' && method === 'POST') {
				return await handleAppleAuth(request, env);
			}
			if (path === '/auth/demo' && method === 'POST') {
				return await handleDemoAuth(request, env);
			}
			if (path === '/auth/login' && method === 'POST') {
				return await handleLoginByUsername(request, env);
			}
			if (path === '/auth/register' && method === 'POST') {
				return await handleRegisterByUsername(request, env);
			}
			if (path === '/auth/refresh' && method === 'POST') {
				return await handleRefresh(request, env);
			}
			if (path === '/auth/me' && method === 'GET') {
				return await handleMe(request, env);
			}
			if (path === '/auth/avatar' && method === 'POST') {
				return await handleSetAvatar(request, env);
			}
			const avatarMatch = path.match(/^\/avatars\/([^/]+)$/);
			if (avatarMatch && method === 'GET') {
				return await handleGetAvatar(request, env, avatarMatch[1]);
			}
			if (path === '/auth/username' && method === 'POST') {
				return await handleSetUsername(request, env);
			}
			if (path === '/auth/push-token' && method === 'POST') {
				return await handlePushToken(request, env);
			}
			if (path === '/users/search' && method === 'GET') {
				return await handleUserSearch(request, env);
			}
			if (path === '/friends' && method === 'GET') {
				return await handleListFriends(request, env);
			}
			if (path === '/friends/add' && method === 'POST') {
				return await handleAddFriend(request, env);
			}
			const addMatch = path.match(/^\/add\/([^/]+)$/);
			if (addMatch) {
				const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta property="og:title" content="Add me on Tones"><meta property="og:description" content="Tap to add @${addMatch[1]} on Tones and start talking!"><meta property="og:site_name" content="Tones"><meta http-equiv="refresh" content="0;url=tones://add/${addMatch[1]}"><title>Add @${addMatch[1]} on Tones</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,sans-serif;background:#FFF8F0;display:flex;align-items:center;justify-content:center;min-height:100vh;color:#8C7366}.card{text-align:center;padding:40px 24px;border-radius:24px;background:white;box-shadow:0 4px 24px rgba(245,115,104,0.08);max-width:320px;width:90%}.icon{width:80px;height:80px;border-radius:50%;background:#FFDBC9;margin:0 auto 16px;display:flex;align-items:center;justify-content:center;font-size:36px;color:#F57368}h1{font-size:28px;font-weight:300;color:#1F1A17;letter-spacing:2px;margin-bottom:8px}p{font-size:14px;color:#8C7366;margin-bottom:24px}a{display:inline-block;padding:16px 32px;background:#F57368;color:white;border-radius:16px;text-decoration:none;font-weight:600;font-size:16px;box-shadow:0 6px 20px rgba(245,115,104,0.3)}</style></head><body><div class="card"><div class="icon">&#9835;</div><h1>tones</h1><p>Add @${addMatch[1]} on Tones</p><a href="https://apps.apple.com/app/tones">get the app</a></div></body></html>`;
				return new Response(html, { headers: { 'Content-Type': 'text/html', ...cors } });
			}
if (path === '/chats/group' && method === 'POST') {
			return await handleCreateGroup(request, env);
		}
		if (path === '/chats/dm' && method === 'POST') {
			return await handleCreateDM(request, env);
		}
		if (path === '/chats' && method === 'GET') {
				return await handleListChats(request, env);
			}
			const chatMsgMatch = path.match(/^\/chats\/([^/]+)\/messages$/);
			if (chatMsgMatch && method === 'GET') {
				return await handleListMessages(request, env, chatMsgMatch[1]);
			}
			if (chatMsgMatch && method === 'POST') {
				return await handleSendMessage(request, env, ctx, chatMsgMatch[1]);
			}
			const chatMsgHeardMatch = path.match(/^\/chats\/([^/]+)\/messages\/heard$/);
			if (chatMsgHeardMatch && method === 'POST') {
				return await handleMarkHeard(request, env, chatMsgHeardMatch[1]);
			}
			const chatUpdateMatch = path.match(/^\/chats\/([^/]+)$/);
			if (chatUpdateMatch && method === 'PUT') {
				return await handleUpdateChat(request, env, chatUpdateMatch[1]);
			}

			return new Response(JSON.stringify({ error: 'Not found' }), { status: 404, headers: { ...cors, 'Content-Type': 'application/json' } });
		} catch (e) {
			return new Response(JSON.stringify({ error: e instanceof Error ? e.message : 'Server error' }), { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } });
		}
	},
};

function getAuthUser(request: Request): { userId: string } | null {
	const auth = request.headers.get('Authorization');
	if (!auth?.startsWith('Bearer ')) return null;
	const token = auth.slice(7);

	try {
		const parts = token.split('.');
		if (parts.length !== 3) return null;

		const payload = JSON.parse(atob(parts[1]));
		return { userId: payload.sub };
	} catch {
		return null;
	}
}

function formatUser(user: { id: string; apple_sub: string | null; username: string | null; avatar_url: string | null; created_at: number; updated_at: number }) {
	return {
		id: user.id,
		apple_sub: user.apple_sub,
		username: user.username,
		avatar_url: user.avatar_url,
		created_at: user.created_at,
		last_active_at: user.updated_at,
	};
}

async function createSession(userId: string, env: Env): Promise<{ access_token: string; refresh_token: string }> {
	const accessToken = createAccessToken(userId, 'tones-secret');
	const refreshToken = crypto.randomUUID();
	await env.DB.prepare(
		'INSERT OR REPLACE INTO sessions (user_id, refresh_token, expires_at) VALUES (?, ?, ?)'
	).bind(userId, refreshToken, Date.now() + 30 * 24 * 60 * 60 * 1000).run();
	return { access_token: accessToken, refresh_token: refreshToken };
}

async function handleDemoAuth(request: Request, env: Env): Promise<Response> {
	const { username } = (await request.json()) as { username: string };
	const cleaned = username.toLowerCase().replace(/[^a-z0-9._]/g, '');
	if (!cleaned || cleaned.length < 3 || cleaned.length > 20) {
		return new Response(JSON.stringify({ error: 'Username must be 3-20 characters (letters, numbers, . _)' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	let user = await env.DB.prepare(
		'SELECT id, apple_sub, username, avatar_url, created_at, updated_at FROM users WHERE username = ?'
	).bind(cleaned).first<{ id: string; apple_sub: string | null; username: string | null; avatar_url: string | null; created_at: number; updated_at: number }>();

	if (user) {
		const tokens = await createSession(user.id, env);
		return new Response(JSON.stringify({
			user: formatUser(user),
			access_token: tokens.access_token,
			refresh_token: tokens.refresh_token,
		}), { headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const userId = crypto.randomUUID();
	await env.DB.prepare(
		'INSERT INTO users (id, apple_sub, username, created_at, updated_at) VALUES (?, ?, ?, ?, ?)'
	).bind(userId, null, cleaned, Date.now(), Date.now()).run();

	user = { id: userId, apple_sub: null as string | null, username: cleaned as string | null, avatar_url: null as string | null, created_at: Date.now(), updated_at: Date.now() };
	const tokens = await createSession(userId, env);

	return new Response(JSON.stringify({
		user: formatUser(user),
		access_token: tokens.access_token,
		refresh_token: tokens.refresh_token,
	}), { status: 201, headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleLoginByUsername(request: Request, env: Env): Promise<Response> {
	const { username } = (await request.json()) as { username: string };
	if (!username || username.length < 3) {
		return new Response(JSON.stringify({ error: 'Username required' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const normalized = username.toLowerCase().replace(/[^a-z0-9._]/g, '');

	const user = await env.DB.prepare(
		'SELECT id, apple_sub, username, avatar_url, created_at, updated_at FROM users WHERE username = ?'
	).bind(normalized).first<{ id: string; apple_sub: string | null; username: string | null; avatar_url: string | null; created_at: number; updated_at: number }>();

	if (!user) {
		return new Response(JSON.stringify({ error: 'User not found. Create an account first.' }), { status: 404, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const tokens = await createSession(user.id, env);

	return new Response(JSON.stringify({
		user: formatUser(user),
		access_token: tokens.access_token,
		refresh_token: tokens.refresh_token,
	}), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleRegisterByUsername(request: Request, env: Env): Promise<Response> {
	const { username } = (await request.json()) as { username: string };

	const cleaned = username.toLowerCase().replace(/[^a-z0-9._]/g, '');
	if (!cleaned || cleaned.length < 3 || cleaned.length > 20) {
		return new Response(JSON.stringify({ error: 'Username must be 3-20 characters (letters, numbers, . _)' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const taken = await env.DB.prepare('SELECT id FROM users WHERE username = ?').bind(cleaned).first();
	if (taken) {
		return new Response(JSON.stringify({ error: 'Username taken' }), { status: 409, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const userId = crypto.randomUUID();
	await env.DB.prepare(
		'INSERT INTO users (id, apple_sub, username, created_at, updated_at) VALUES (?, ?, ?, ?, ?)'
	).bind(userId, null, cleaned, Date.now(), Date.now()).run();

	const user = { id: userId, apple_sub: null as string | null, username: cleaned as string | null, avatar_url: null as string | null, created_at: Date.now(), updated_at: Date.now() };
	const tokens = await createSession(userId, env);

	return new Response(JSON.stringify({
		user: formatUser(user),
		access_token: tokens.access_token,
		refresh_token: tokens.refresh_token,
	}), { status: 201, headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleAppleAuth(request: Request, env: Env): Promise<Response> {
	try {
		const body = (await request.json()) as { apple_token: string };
		const appleSub = await verifyAppleToken(body.apple_token, env.APPLE_CLIENT_ID);
		if (!appleSub) {
			return new Response(JSON.stringify({ error: 'Invalid Apple token' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
		}

		let user = await env.DB.prepare(
			'SELECT id, apple_sub, username, avatar_url, created_at, updated_at FROM users WHERE apple_sub = ?'
		).bind(appleSub).first<{ id: string; apple_sub: string; username: string | null; avatar_url: string | null; created_at: number; updated_at: number }>();

		if (!user) {
			const userId = crypto.randomUUID();
			await env.DB.prepare(
				'INSERT INTO users (id, apple_sub, created_at, updated_at) VALUES (?, ?, ?, ?)'
			).bind(userId, appleSub, Date.now(), Date.now()).run();

			user = { id: userId, apple_sub: appleSub, username: null as string | null, avatar_url: null as string | null, created_at: Date.now(), updated_at: Date.now() };
		}

		const tokens = await createSession(user.id, env);

		return new Response(JSON.stringify({
			user: formatUser(user),
			access_token: tokens.access_token,
			refresh_token: tokens.refresh_token,
		}), { headers: { ...cors, 'Content-Type': 'application/json' } });
	} catch (e) {
		return new Response(JSON.stringify({ error: e instanceof Error ? e.message : 'Server error' }), { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } });
	}
}

async function handleRefresh(request: Request, env: Env): Promise<Response> {
	const { refresh_token } = await request.json();

	const session = await env.DB.prepare(
		'SELECT user_id, expires_at FROM sessions WHERE refresh_token = ?'
	).bind(refresh_token).first<{ user_id: string; expires_at: number }>();

	if (!session || session.expires_at < Date.now()) {
		return new Response(JSON.stringify({ error: 'Invalid token' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const user = await env.DB.prepare(
		'SELECT id, username FROM users WHERE id = ?'
	).bind(session.user_id).first<{ id: string; username: string }>();

	const accessToken = createAccessToken(user!.id, 'tones-secret');
	const newRefreshToken = crypto.randomUUID();

	await env.DB.prepare(
		'UPDATE sessions SET refresh_token = ?, expires_at = ? WHERE refresh_token = ?'
	).bind(newRefreshToken, Date.now() + 30 * 24 * 60 * 60 * 1000, refresh_token).run();

	return new Response(JSON.stringify({
		access_token: accessToken,
		refresh_token: newRefreshToken,
	}), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleMe(request: Request, env: Env): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) {
		return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const user = await env.DB.prepare(
		'SELECT id, apple_sub, username, avatar_url, created_at, updated_at FROM users WHERE id = ?'
	).bind(auth.userId).first<{ id: string; apple_sub: string; username: string | null; avatar_url: string | null; created_at: number; updated_at: number }>();

	if (!user) {
		return new Response(JSON.stringify({ error: 'User not found' }), { status: 404, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	return new Response(JSON.stringify(formatUser(user)), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleSetUsername(request: Request, env: Env): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) {
		return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const existingUser = await env.DB.prepare(
		'SELECT username FROM users WHERE id = ?'
	).bind(auth.userId).first<{ username: string | null }>();

	if (existingUser?.username) {
		return new Response(JSON.stringify({ error: 'Username already set and cannot be changed' }), { status: 403, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const { username } = (await request.json()) as { username: string };

	const cleaned = username.toLowerCase().replace(/[^a-z0-9_.]/g, '');
	if (!cleaned || cleaned.length < 3 || cleaned.length > 20) {
		return new Response(JSON.stringify({ error: 'Username must be 3-20 characters (letters, numbers, . _)' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const normalizedUsername = cleaned;

	const taken = await env.DB.prepare(
		'SELECT id FROM users WHERE username = ? AND id != ?'
	).bind(normalizedUsername, auth.userId).first<{ id: string }>();

	if (taken) {
		const suggestions = await getSuggestions(env, normalizedUsername);
		return new Response(JSON.stringify({ error: 'Username taken', suggestions }), { status: 409, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	await env.DB.prepare(
		'UPDATE users SET username = ?, updated_at = ? WHERE id = ?'
	).bind(normalizedUsername, Date.now(), auth.userId).run();

	return new Response(JSON.stringify({ username: normalizedUsername }), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function getSuggestions(env: Env, base: string): Promise<string[]> {
	const suggestions: string[] = [];

	for (let i = 1; i <= 5; i++) {
		const suggestion = i === 1 ? base.slice(0, 15) : base.slice(0, 14) + String(i);
		const existing = await env.DB.prepare('SELECT id FROM users WHERE username = ?').bind(suggestion).first();
		if (!existing && !suggestions.includes(suggestion)) {
			suggestions.push(suggestion);
		}
		if (suggestions.length >= 3) break;
	}

	return suggestions;
}

async function handleGetAvatar(request: Request, env: Env, userIdOrUsername: string): Promise<Response> {
	let user = await env.DB.prepare(
		'SELECT id, avatar_url FROM users WHERE id = ?'
	).bind(userIdOrUsername).first<{ id: string; avatar_url: string | null }>();

	if (!user) {
		user = await env.DB.prepare(
			'SELECT id, avatar_url FROM users WHERE username = ?'
		).bind(userIdOrUsername).first<{ id: string; avatar_url: string | null }>();
	}

	if (!user || !user.avatar_url || user.avatar_url === 'none') {
		return new Response(JSON.stringify({ error: 'No avatar' }), { status: 404, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const avatarUrl = user.avatar_url;

	if (avatarUrl.startsWith('data:')) {
		const matches = avatarUrl.match(/^data:(image\/[a-z]+);base64,(.+)$/);
		if (matches) {
			const binary = Uint8Array.from(atob(matches[2]), c => c.charCodeAt(0));
			return new Response(binary, {
				headers: { ...cors, 'Content-Type': matches[1], 'Cache-Control': 'public, max-age=86400' },
			});
		}
		return new Response(JSON.stringify({ error: 'Invalid avatar' }), { status: 500, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	if (env.AVATAR_BUCKET) {
		const obj = await env.AVATAR_BUCKET.get(avatarUrl);
		if (obj) {
			return new Response(obj.body, {
				headers: { ...cors, 'Content-Type': obj.httpMetadata?.contentType ?? 'image/jpeg', 'Cache-Control': 'public, max-age=86400' },
			});
		}
	}

	return new Response(JSON.stringify({ error: 'Avatar not found' }), { status: 404, headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleSetAvatar(request: Request, env: Env): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) {
		return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const body = (await request.json()) as { avatar_data?: string };
	const avatarData = body.avatar_data;
	if (!avatarData) {
		return new Response(JSON.stringify({ error: 'avatar_data required' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	if (avatarData === 'none') {
		await env.DB.prepare(
			'UPDATE users SET avatar_url = ?, updated_at = ? WHERE id = ?'
		).bind('none', Date.now(), auth.userId).run();

		return new Response(JSON.stringify({ avatar_url: 'none' }), { headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const maxSize = 2 * 1024 * 1024;
	if (avatarData.length > maxSize * 1.37) {
		return new Response(JSON.stringify({ error: 'Image too large (max 2MB)' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const matches = avatarData.match(/^data:image\/(png|jpeg|jpg|webp|heic);base64,/);
	if (!matches) {
		return new Response(JSON.stringify({ error: 'Invalid image format. Use JPEG, PNG, WebP, or HEIC.' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	let avatarUrl: string;

	if (env.AVATAR_BUCKET) {
		const ext = matches[1] === 'jpeg' ? 'jpg' : matches[1];
		const key = `avatars/${auth.userId}.${ext}`;
		const binary = Uint8Array.from(atob(avatarData.split(',')[1]), c => c.charCodeAt(0));
		await env.AVATAR_BUCKET.put(key, binary.buffer as ArrayBuffer, {
			httpMetadata: { contentType: `image/${matches[1] === 'jpg' ? 'jpeg' : matches[1]}` },
		});
		avatarUrl = key;
	} else {
		avatarUrl = avatarData;
	}

	await env.DB.prepare(
		'UPDATE users SET avatar_url = ?, updated_at = ? WHERE id = ?'
	).bind(avatarUrl, Date.now(), auth.userId).run();

	return new Response(JSON.stringify({ avatar_url: avatarUrl }), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handlePushToken(request: Request, env: Env): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) {
		return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const { push_token, platform } = (await request.json()) as { push_token: string; platform?: string };
	if (!push_token) {
		return new Response(JSON.stringify({ error: 'push_token required' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	await env.DB.prepare(
		'INSERT OR REPLACE INTO push_tokens (user_id, push_token, platform, updated_at) VALUES (?, ?, ?, ?)'
	).bind(auth.userId, push_token, platform || 'ios', Date.now()).run();

	return new Response(JSON.stringify({ success: true }), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function sendPushNotification(recipientUserId: string, senderId: string, senderUsername: string | null, chatId: string, env: Env): Promise<void> {
	const rows = await env.DB.prepare(
		'SELECT push_token, platform FROM push_tokens WHERE user_id = ?'
	).bind(recipientUserId).all<{ push_token: string; platform: string }>();

	if (!rows.results || rows.results.length === 0) return;

	const senderName = senderUsername ? `@${senderUsername}` : 'someone';
	const payload = JSON.stringify({
		aps: {
			alert: {
				title: senderName,
				body: 'sent you a tone 🎵',
			},
			sound: 'default',
		},
		chatId: chatId,
		senderId: senderId,
	});

	const jwt = generateAPNSJWT(env);
	const authHeader = jwt ? `bearer ${jwt}` : undefined;

	for (const row of rows.results) {
		try {
			const pushUrl = 'https://api.push.apple.com/1/device/' + row.push_token;
			const headers: Record<string, string> = {
				'content-type': 'application/json',
				'apns-topic': 'tonesapp.Tones',
				'apns-push-type': 'alert',
				'apns-priority': '10',
			};
			if (authHeader) {
				headers['authorization'] = authHeader;
			}
			const resp = await fetch(pushUrl, {
				method: 'POST',
				headers,
				body: payload,
			});
			if (resp.status === 410 || resp.status === 400) {
				await env.DB.prepare('DELETE FROM push_tokens WHERE push_token = ?').bind(row.push_token).run();
			}
		} catch {
		}
	}
}

function generateAPNSJWT(env: Env): string | null {
	if (!env.PUSH_PRIVATE_KEY || env.PUSH_PRIVATE_KEY === '') return null;
	try {
		const now = Math.floor(Date.now() / 1000);
		const header = btoa(JSON.stringify({ alg: 'ES256', kid: env.PUSH_KEY_ID || '' }));
		const payload = btoa(JSON.stringify({ iss: env.TEAM_ID || '', iat: now }));
		// Note: For proper ES256 signing, use a library like 'jose' in production
		// This creates an unsigned JWT placeholder - replace with proper signing
		// when you have your .p8 key configured
		return `${header}.${payload}.unsigned`;
	} catch {
		return null;
	}
}

async function verifyAppleToken(identityToken: string, clientId: string): Promise<string | null> {
	try {
		const parts = identityToken.split('.');
		if (parts.length !== 3) return null;
		
		let base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
		while (base64.length % 4) { base64 += '='; }
		
		const decoded = atob(base64);
		const payload = JSON.parse(decoded);
		if (!payload || typeof payload !== 'object') return null;
		if (payload.iss !== 'https://appleid.apple.com') return null;
		
		const aud = payload.aud;
		if (aud !== clientId && !(Array.isArray(aud) && aud.includes(clientId))) return null;
		
		const exp = Number(payload.exp);
		if (exp > 0 && exp < Math.floor(Date.now() / 1000)) return null;
		
		return String(payload.sub || '');
	} catch {
		return null;
	}
}

function createAccessToken(userId: string, _secret: string): string {
	const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
	const payload = btoa(JSON.stringify({ sub: userId, iat: Date.now() }));
	const signature = btoa(userId + ':' + Date.now());
	return header + '.' + payload + '.' + signature;
}

async function handleUserSearch(request: Request, env: Env): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) {
		return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const q = new URL(request.url).searchParams.get('q') || '';
	if (q.length < 2) {
		return new Response(JSON.stringify([]), { headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const exactUser = await env.DB.prepare(
		'SELECT id, username, avatar_url FROM users WHERE LOWER(username) = LOWER(?) AND id != ?'
	).bind(q, auth.userId).first<{ id: string; username: string; avatar_url: string | null }>();

	if (exactUser) {
		return new Response(JSON.stringify([exactUser]), { headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const users = await env.DB.prepare(
		'SELECT id, username, avatar_url FROM users WHERE username LIKE ? AND id != ? LIMIT 20'
	).bind(q.toLowerCase() + '%', auth.userId).all<{ id: string; username: string; avatar_url: string | null }>();

	return new Response(JSON.stringify(users.results || []), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleListFriends(request: Request, env: Env): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) {
		return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const friends = await env.DB.prepare(
		`SELECT u.id, u.username, u.avatar_url 
		 FROM friends f 
		 JOIN users u ON u.id = f.friend_id 
		 WHERE f.user_id = ?
		 UNION
		 SELECT u.id, u.username, u.avatar_url 
		 FROM friends f 
		 JOIN users u ON u.id = f.user_id 
		 WHERE f.friend_id = ?`
	).bind(auth.userId, auth.userId).all<{ id: string; username: string | null; avatar_url: string | null }>();

	return new Response(JSON.stringify(friends.results || []), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleAddFriend(request: Request, env: Env): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) {
		return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const { friend_id } = (await request.json()) as { friend_id: string };

	if (!friend_id) {
		return new Response(JSON.stringify({ error: 'friend_id required' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const friendExists = await env.DB.prepare(
		'SELECT id FROM users WHERE id = ?'
	).bind(friend_id).first<{ id: string }>();

	if (!friendExists) {
		return new Response(JSON.stringify({ error: 'User not found' }), { status: 404, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const alreadyFriends = await env.DB.prepare(
		'SELECT id FROM friends WHERE user_id = ? AND friend_id = ?'
	).bind(auth.userId, friend_id).first();

	if (alreadyFriends) {
		return new Response(JSON.stringify({ error: 'Already friends' }), { status: 409, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	await env.DB.prepare(
		'INSERT INTO friends (id, user_id, friend_id, created_at) VALUES (?, ?, ?, ?)'
	).bind(crypto.randomUUID(), auth.userId, friend_id, Date.now()).run();
	if (friend_id !== auth.userId) {
		await env.DB.prepare(
			'INSERT OR IGNORE INTO friends (id, user_id, friend_id, created_at) VALUES (?, ?, ?, ?)'
		).bind(crypto.randomUUID(), friend_id, auth.userId, Date.now()).run();
	}

	return new Response(JSON.stringify({ success: true }), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleCreateDM(request: Request, env: Env): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });

	const { friend_id } = (await request.json()) as { friend_id: string };
	if (!friend_id) return new Response(JSON.stringify({ error: 'friend_id required' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });

	const existing = await env.DB.prepare(
		`SELECT c.id FROM chats c
		 JOIN chat_members m1 ON m1.chat_id = c.id AND m1.user_id = ?
		 JOIN chat_members m2 ON m2.chat_id = c.id AND m2.user_id = ?
		 WHERE c.type = 'dm' LIMIT 1`
	).bind(auth.userId, friend_id).first<{ id: string }>();

	if (existing) {
		return new Response(JSON.stringify({ id: existing.id, type: 'dm' }), { headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const chatId = crypto.randomUUID();
	const now = Date.now();
	await env.DB.prepare('INSERT INTO chats (id, type, created_at, updated_at) VALUES (?, ?, ?, ?)').bind(chatId, 'dm', now, now).run();
	await env.DB.prepare('INSERT INTO chat_members (chat_id, user_id) VALUES (?, ?)').bind(chatId, auth.userId).run();
	if (friend_id !== auth.userId) {
		await env.DB.prepare('INSERT INTO chat_members (chat_id, user_id) VALUES (?, ?)').bind(chatId, friend_id).run();
	}

	return new Response(JSON.stringify({ id: chatId, type: 'dm' }), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleCreateGroup(request: Request, env: Env): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });

	const { title, member_ids } = (await request.json()) as { title?: string; member_ids: string[] };
	if (!member_ids || member_ids.length === 0) {
		return new Response(JSON.stringify({ error: 'member_ids required (at least 1)' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const allMemberIds = [auth.userId, ...member_ids.filter(id => id !== auth.userId)];
	const uniqueIds = [...new Set(allMemberIds)];

	for (const uid of uniqueIds) {
		const exists = await env.DB.prepare('SELECT id FROM users WHERE id = ?').bind(uid).first();
		if (!exists) {
			return new Response(JSON.stringify({ error: `User ${uid} not found` }), { status: 404, headers: { ...cors, 'Content-Type': 'application/json' } });
		}
	}

	const chatId = crypto.randomUUID();
	const now = Date.now();
	const groupTitle = title?.trim() || null;
	await env.DB.prepare('INSERT INTO chats (id, type, title, created_at, updated_at) VALUES (?, ?, ?, ?, ?)').bind(chatId, 'group', groupTitle, now, now).run();
	for (const uid of uniqueIds) {
		await env.DB.prepare('INSERT INTO chat_members (chat_id, user_id) VALUES (?, ?)').bind(chatId, uid).run();
	}

	return new Response(JSON.stringify({ id: chatId, type: 'group', title: groupTitle }), { status: 201, headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleListChats(request: Request, env: Env): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });

	const chats = await env.DB.prepare(
		`SELECT c.id, c.type, c.title, c.avatar_url, c.updated_at,
		 (SELECT u.username FROM chat_members cm JOIN users u ON u.id = cm.user_id
		  WHERE cm.chat_id = c.id AND cm.user_id != ? LIMIT 1) as peer_username,
		 (SELECT u.id FROM chat_members cm JOIN users u ON u.id = cm.user_id
		  WHERE cm.chat_id = c.id AND cm.user_id != ? LIMIT 1) as peer_id,
		 (SELECT u.avatar_url FROM chat_members cm JOIN users u ON u.id = cm.user_id
		  WHERE cm.chat_id = c.id AND cm.user_id != ? LIMIT 1) as peer_avatar_url,
		 (SELECT u.avatar_url FROM chat_members cm JOIN users u ON u.id = cm.user_id
		  WHERE cm.chat_id = c.id AND cm.user_id = ? LIMIT 1) as my_avatar_url
		 FROM chats c
		 JOIN chat_members m ON m.chat_id = c.id
		 WHERE m.user_id = ?
		 ORDER BY c.updated_at DESC`
	).bind(auth.userId, auth.userId, auth.userId, auth.userId, auth.userId).all();

	const chatsWithUnread = await Promise.all((chats.results || []).map(async (chat: any) => {
		const unheard = await env.DB.prepare(
			`SELECT COUNT(*) as cnt FROM messages m
			 WHERE m.chat_id = ? AND m.sender_id != ?
			 AND NOT EXISTS (SELECT 1 FROM message_reads mr WHERE mr.message_id = m.id AND mr.user_id = ?)`
		).bind(chat.id, auth.userId, auth.userId).first<{ cnt: number }>();

		let members: Array<{ id: string; username: string | null; avatar_url: string | null }> = [];
		if (chat.type === 'group') {
			const memberRows = await env.DB.prepare(
				`SELECT u.id, u.username, u.avatar_url FROM chat_members cm JOIN users u ON u.id = cm.user_id WHERE cm.chat_id = ?`
			).bind(chat.id).all<{ id: string; username: string | null; avatar_url: string | null }>();
			members = memberRows.results || [];
		}

		return { ...chat, unread_count: unheard?.cnt ?? 0, members };
	}));

	return new Response(JSON.stringify(chatsWithUnread), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleListMessages(request: Request, env: Env, chatId: string): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });

	const member = await env.DB.prepare('SELECT 1 FROM chat_members WHERE chat_id = ? AND user_id = ?').bind(chatId, auth.userId).first();
	if (!member) return new Response(JSON.stringify({ error: 'Not a member' }), { status: 403, headers: { ...cors, 'Content-Type': 'application/json' } });

	const since = parseInt(new URL(request.url).searchParams.get('since') || '0');

	const messages = await env.DB.prepare(
		`SELECT m.id, m.chat_id, m.sender_id, m.audio_base64, m.duration_ms, m.created_at,
		 u.username as sender_username,
		 u.avatar_url as sender_avatar_url,
		 CASE WHEN mr.message_id IS NOT NULL THEN 1 ELSE 0 END as heard
		 FROM messages m JOIN users u ON u.id = m.sender_id
		 LEFT JOIN message_reads mr ON mr.message_id = m.id AND mr.user_id = ?
		 WHERE m.chat_id = ? AND m.created_at > ?
		 ORDER BY m.created_at ASC`
	).bind(auth.userId, chatId, since).all();

	const results = (messages.results || []).map((m: any) => ({ ...m, heard: !!m.heard }));
	return new Response(JSON.stringify(results), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleSendMessage(request: Request, env: Env, ctx: ExecutionContext, chatId: string): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });

	const member = await env.DB.prepare('SELECT 1 FROM chat_members WHERE chat_id = ? AND user_id = ?').bind(chatId, auth.userId).first();
	if (!member) return new Response(JSON.stringify({ error: 'Not a member' }), { status: 403, headers: { ...cors, 'Content-Type': 'application/json' } });

	const { id, audio_base64, duration_ms } = (await request.json()) as { id?: string; audio_base64: string; duration_ms: number };
	if (!audio_base64 || !duration_ms) return new Response(JSON.stringify({ error: 'audio_base64 and duration_ms required' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });

	const messageId = id || crypto.randomUUID();
	const now = Date.now();

	await env.DB.prepare(
		'INSERT INTO messages (id, chat_id, sender_id, audio_base64, duration_ms, created_at) VALUES (?, ?, ?, ?, ?, ?)'
	).bind(messageId, chatId, auth.userId, audio_base64, duration_ms, now).run();

	await env.DB.prepare('UPDATE chats SET updated_at = ? WHERE id = ?').bind(now, chatId).run();

	const members = await env.DB.prepare(
		'SELECT user_id FROM chat_members WHERE chat_id = ? AND user_id != ?'
	).bind(chatId, auth.userId).all<{ user_id: string }>();

	if (members.results && members.results.length > 0) {
		const sender = await env.DB.prepare(
			'SELECT username FROM users WHERE id = ?'
		).bind(auth.userId).first<{ username: string | null }>();
		for (const member of members.results) {
			ctx.waitUntil(sendPushNotification(member.user_id, auth.userId, sender?.username ?? null, chatId, env));
		}
	}

	return new Response(JSON.stringify({ id: messageId, created_at: now }), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleUpdateChat(request: Request, env: Env, chatId: string): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });

	const member = await env.DB.prepare('SELECT 1 FROM chat_members WHERE chat_id = ? AND user_id = ?').bind(chatId, auth.userId).first();
	if (!member) return new Response(JSON.stringify({ error: 'Not a member' }), { status: 403, headers: { ...cors, 'Content-Type': 'application/json' } });

	const chat = await env.DB.prepare('SELECT id, type, title FROM chats WHERE id = ?').bind(chatId).first<{ id: string; type: string; title: string | null }>();
	if (!chat) return new Response(JSON.stringify({ error: 'Chat not found' }), { status: 404, headers: { ...cors, 'Content-Type': 'application/json' } });
	if (chat.type !== 'group') return new Response(JSON.stringify({ error: 'Only group chats can be updated' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });

	const { title, avatar_data } = (await request.json()) as { title?: string; avatar_data?: string };
	const now = Date.now();

	let avatarUrl: string | null = null;
	if (avatar_data !== undefined) {
		if (avatar_data === 'none') {
			avatarUrl = null;
		} else if (avatar_data.startsWith('data:image/')) {
			avatarUrl = avatar_data;
		} else {
			return new Response(JSON.stringify({ error: 'Invalid avatar_data format' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
		}
	}

	if (title === undefined && avatar_data === undefined) {
		return new Response(JSON.stringify({ error: 'title or avatar_data required' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const setClauses: string[] = ['updated_at = ?'];
	const bindValues: any[] = [now];

	if (title !== undefined) {
		setClauses.push('title = ?');
		bindValues.push(title);
	}

	bindValues.push(chatId);

	await env.DB.prepare(
		`UPDATE chats SET ${setClauses.join(', ')} WHERE id = ?`
	).bind(...bindValues).run();

	let newTitle = title ?? chat.title ?? '';
	let newAvatarUrl: string | null = null;
	if (avatar_data !== undefined) {
		newAvatarUrl = avatarUrl;
	}

	return new Response(JSON.stringify({
		id: chatId,
		type: 'group',
		title: newTitle,
		avatar_url: newAvatarUrl,
	}), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleMarkHeard(request: Request, env: Env, chatId: string): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });

	const member = await env.DB.prepare('SELECT 1 FROM chat_members WHERE chat_id = ? AND user_id = ?').bind(chatId, auth.userId).first();
	if (!member) return new Response(JSON.stringify({ error: 'Not a member' }), { status: 403, headers: { ...cors, 'Content-Type': 'application/json' } });

	const body = (await request.json()) as { message_ids?: string[] };
	const messageIds = body.message_ids || [];
	if (messageIds.length === 0) {
		return new Response(JSON.stringify({ success: true }), { headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const now = Date.now();
	for (const msgId of messageIds) {
		await env.DB.prepare(
			'INSERT OR IGNORE INTO message_reads (message_id, user_id, heard_at) VALUES (?, ?, ?)'
		).bind(msgId, auth.userId, now).run();
	}

	return new Response(JSON.stringify({ success: true }), { headers: { ...cors, 'Content-Type': 'application/json' } });
}