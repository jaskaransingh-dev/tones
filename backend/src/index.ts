/**
 * Tones API - Cloudflare Worker (Auth + User Search)
 * Chat/Message data stored locally on iPhone
 */

import { D1Database } from '@cloudflare/d1-workers-types';

export interface Env {
	DB: D1Database;
	SESSIONS: KVNamespace;
	APPLE_CLIENT_ID: string;
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
			if (path === '/auth/username' && method === 'POST') {
				return await handleSetUsername(request, env);
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
				const html = `<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta property="og:title" content="Add me on Tones"><meta property="og:description" content="Tap to add @${addMatch[1]} on Tones and start talking!"><meta property="og:site_name" content="Tones"><meta http-equiv="refresh" content="0;url=tones://add/${addMatch[1]}"><title>Add @${addMatch[1]} on Tones</title><style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:-apple-system,sans-serif;background:#FEF6F0;display:flex;align-items:center;justify-content:center;min-height:100vh;color:#8C7366}.card{text-align:center;padding:40px 24px;border-radius:24px;background:white;box-shadow:0 4px 24px rgba(0,0,0,0.06);max-width:320px;width:90%}h1{font-size:28px;font-weight:300;color:#3D362E;letter-spacing:2px;margin-bottom:8px}p{font-size:14px;opacity:0.7;margin-bottom:24px}a{display:inline-block;padding:16px 32px;background:#F57368;color:white;border-radius:16px;text-decoration:none;font-weight:600;font-size:16px}</style></head><body><div class="card"><h1>tones</h1><p>Add @${addMatch[1]} on Tones</p><a href="https://apps.apple.com/app/tones">get the app</a></div></body></html>`;
				return new Response(html, { headers: { 'Content-Type': 'text/html', ...cors } });
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
				return await handleSendMessage(request, env, chatMsgMatch[1]);
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

function formatUser(user: { id: string; apple_sub: string | null; username: string | null; display_name: string; avatar_url: string | null; created_at: number; updated_at: number }) {
	return {
		id: user.id,
		apple_sub: user.apple_sub,
		username: user.username,
		display_name: user.display_name,
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

async function handleLoginByUsername(request: Request, env: Env): Promise<Response> {
	const { username } = (await request.json()) as { username: string };
	if (!username || username.length < 3) {
		return new Response(JSON.stringify({ error: 'Username required' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const normalized = username.toLowerCase().replace(/[^a-z0-9._]/g, '');

	const user = await env.DB.prepare(
		'SELECT id, apple_sub, username, display_name, avatar_url, created_at, updated_at FROM users WHERE username = ?'
	).bind(normalized).first<{ id: string; apple_sub: string; username: string | null; display_name: string; avatar_url: string | null; created_at: number; updated_at: number }>();

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
	const { username, display_name } = (await request.json()) as { username: string; display_name?: string };

	const cleaned = username.toLowerCase().replace(/[^a-z0-9._]/g, '');
	if (!cleaned || cleaned.length < 3 || cleaned.length > 20) {
		return new Response(JSON.stringify({ error: 'Username must be 3-20 characters (letters, numbers, . _) ' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const taken = await env.DB.prepare('SELECT id FROM users WHERE username = ?').bind(cleaned).first();
	if (taken) {
		return new Response(JSON.stringify({ error: 'Username taken' }), { status: 409, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const userId = crypto.randomUUID();
	const name = display_name || '@' + cleaned;
	await env.DB.prepare(
		'INSERT INTO users (id, apple_sub, username, display_name, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)'
	).bind(userId, null, cleaned, name, Date.now(), Date.now()).run();

	const user = { id: userId, apple_sub: null as string | null, username: cleaned as string | null, display_name: name, avatar_url: null as string | null, created_at: Date.now(), updated_at: Date.now() };
	const tokens = await createSession(userId, env);

	return new Response(JSON.stringify({
		user: formatUser(user),
		access_token: tokens.access_token,
		refresh_token: tokens.refresh_token,
	}), { status: 201, headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleAppleAuth(request: Request, env: Env): Promise<Response> {
	try {
		const body = (await request.json()) as { apple_token: string; display_name?: string };
		const appleSub = await verifyAppleToken(body.apple_token, env.APPLE_CLIENT_ID);
		if (!appleSub) {
			return new Response(JSON.stringify({ error: 'Invalid Apple token' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
		}

		const displayName = body.display_name || 'Tones User';

		let user = await env.DB.prepare(
			'SELECT id, apple_sub, username, display_name, avatar_url, created_at, updated_at FROM users WHERE apple_sub = ?'
		).bind(appleSub).first<{ id: string; apple_sub: string; username: string | null; display_name: string; avatar_url: string | null; created_at: number; updated_at: number }>();

		if (!user) {
			const userId = crypto.randomUUID();
			await env.DB.prepare(
				'INSERT INTO users (id, apple_sub, display_name, created_at, updated_at) VALUES (?, ?, ?, ?, ?)'
			).bind(userId, appleSub, displayName, Date.now(), Date.now()).run();

			user = { id: userId, apple_sub: appleSub, username: null, display_name: displayName, avatar_url: null, created_at: Date.now(), updated_at: Date.now() };
		} else if (displayName && displayName !== 'Tones User' && user.display_name === 'Tones User') {
			await env.DB.prepare(
				'UPDATE users SET display_name = ?, updated_at = ? WHERE id = ?'
			).bind(displayName, Date.now(), user.id).run();
			user = { ...user, display_name: displayName, updated_at: Date.now() };
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
		'SELECT id, username, display_name FROM users WHERE id = ?'
	).bind(session.user_id).first<{ id: string; username: string; display_name: string }>();

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
		'SELECT id, apple_sub, username, display_name, avatar_url, created_at, updated_at FROM users WHERE id = ?'
	).bind(auth.userId).first<{ id: string; apple_sub: string; username: string | null; display_name: string; avatar_url: string | null; created_at: number; updated_at: number }>();

	if (!user) {
		return new Response(JSON.stringify({ error: 'User not found' }), { status: 404, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	return new Response(JSON.stringify({
		id: user.id,
		apple_sub: user.apple_sub,
		username: user.username,
		display_name: user.display_name,
		avatar_url: user.avatar_url,
		created_at: user.created_at,
		last_active_at: user.updated_at,
	}), { headers: { ...cors, 'Content-Type': 'application/json' } });
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
		'UPDATE users SET username = ?, display_name = ?, updated_at = ? WHERE id = ?'
	).bind(normalizedUsername, '@' + normalizedUsername, Date.now(), auth.userId).run();

	return new Response(JSON.stringify({ username: normalizedUsername, display_name: '@' + normalizedUsername }), { headers: { ...cors, 'Content-Type': 'application/json' } });
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
		'SELECT id, username, display_name FROM users WHERE LOWER(username) = LOWER(?) AND id != ?'
	).bind(q, auth.userId).first<{ id: string; username: string; display_name: string }>();

	if (exactUser) {
		return new Response(JSON.stringify([exactUser]), { headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const users = await env.DB.prepare(
		'SELECT id, username, display_name FROM users WHERE username LIKE ? AND id != ? LIMIT 20'
	).bind(q.toLowerCase() + '%', auth.userId).all<{ id: string; username: string; display_name: string }>();

	return new Response(JSON.stringify(users.results || []), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleListFriends(request: Request, env: Env): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) {
		return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const friends = await env.DB.prepare(
		`SELECT u.id, u.username, u.display_name, u.avatar_url 
		 FROM friends f 
		 JOIN users u ON u.id = f.friend_id 
		 WHERE f.user_id = ?
		 UNION
		 SELECT u.id, u.username, u.display_name, u.avatar_url 
		 FROM friends f 
		 JOIN users u ON u.id = f.user_id 
		 WHERE f.friend_id = ?`
	).bind(auth.userId, auth.userId).all<{ id: string; username: string | null; display_name: string; avatar_url: string | null }>();

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

	// Check if friend exists
	const friendExists = await env.DB.prepare(
		'SELECT id FROM users WHERE id = ?'
	).bind(friend_id).first<{ id: string }>();

	if (!friendExists) {
		return new Response(JSON.stringify({ error: 'User not found' }), { status: 404, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	// Check if already friends
	const alreadyFriends = await env.DB.prepare(
		'SELECT id FROM friends WHERE user_id = ? AND friend_id = ?'
	).bind(auth.userId, friend_id).first();

	if (alreadyFriends) {
		return new Response(JSON.stringify({ error: 'Already friends' }), { status: 409, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	// Add friend (bidirectional, but skip self-add for second direction)
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

	// Find existing DM where both users are members
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

async function handleListChats(request: Request, env: Env): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });

	const chats = await env.DB.prepare(
		`SELECT c.id, c.type, c.title, c.updated_at,
		 (SELECT u.username FROM chat_members cm JOIN users u ON u.id = cm.user_id
		  WHERE cm.chat_id = c.id AND cm.user_id != ? LIMIT 1) as peer_username,
		 (SELECT u.display_name FROM chat_members cm JOIN users u ON u.id = cm.user_id
		  WHERE cm.chat_id = c.id AND cm.user_id != ? LIMIT 1) as peer_display_name,
		 (SELECT u.id FROM chat_members cm JOIN users u ON u.id = cm.user_id
		  WHERE cm.chat_id = c.id AND cm.user_id != ? LIMIT 1) as peer_id
		 FROM chats c
		 JOIN chat_members m ON m.chat_id = c.id
		 WHERE m.user_id = ?
		 ORDER BY c.updated_at DESC`
	).bind(auth.userId, auth.userId, auth.userId, auth.userId).all();

	return new Response(JSON.stringify(chats.results || []), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleListMessages(request: Request, env: Env, chatId: string): Promise<Response> {
	const auth = getAuthUser(request);
	if (!auth) return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });

	const member = await env.DB.prepare('SELECT 1 FROM chat_members WHERE chat_id = ? AND user_id = ?').bind(chatId, auth.userId).first();
	if (!member) return new Response(JSON.stringify({ error: 'Not a member' }), { status: 403, headers: { ...cors, 'Content-Type': 'application/json' } });

	const since = parseInt(new URL(request.url).searchParams.get('since') || '0');

	const messages = await env.DB.prepare(
		`SELECT m.id, m.chat_id, m.sender_id, m.audio_base64, m.duration_ms, m.created_at,
		 u.display_name as sender_name, u.username as sender_username
		 FROM messages m JOIN users u ON u.id = m.sender_id
		 WHERE m.chat_id = ? AND m.created_at > ?
		 ORDER BY m.created_at ASC`
	).bind(chatId, since).all();

	return new Response(JSON.stringify(messages.results || []), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleSendMessage(request: Request, env: Env, chatId: string): Promise<Response> {
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

	return new Response(JSON.stringify({ id: messageId, created_at: now }), { headers: { ...cors, 'Content-Type': 'application/json' } });
}