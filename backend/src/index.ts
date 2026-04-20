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
			if (path === '/auth/demo' && method === 'POST') {
				return await handleDemoAuth(request, env);
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

async function handleDemoAuth(request: Request, env: Env): Promise<Response> {
	const { demo_id } = (await request.json()) as { demo_id: string };
	if (!demo_id || demo_id.length < 8) {
		return new Response(JSON.stringify({ error: 'Invalid demo ID' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const demoSub = 'demo:' + demo_id;

	let user = await env.DB.prepare(
		'SELECT id, apple_sub, username, display_name, avatar_url, created_at, updated_at FROM users WHERE apple_sub = ?'
	).bind(demoSub).first<{ id: string; apple_sub: string | null; username: string | null; display_name: string; avatar_url: string | null; created_at: number; updated_at: number }>();

	if (!user) {
		const userId = crypto.randomUUID();
		await env.DB.prepare(
			'INSERT INTO users (id, apple_sub, display_name, created_at, updated_at) VALUES (?, ?, ?, ?, ?)'
		).bind(userId, demoSub, 'Demo User', Date.now(), Date.now()).run();

		user = { id: userId, apple_sub: demoSub, username: null, display_name: 'Demo User', avatar_url: null, created_at: Date.now(), updated_at: Date.now() };
	}

	const tokens = await createSession(user.id, env);

	return new Response(JSON.stringify({
		user: formatUser(user),
		access_token: tokens.access_token,
		refresh_token: tokens.refresh_token,
	}), { headers: { ...cors, 'Content-Type': 'application/json' } });
}

async function handleAppleAuth(request: Request, env: Env): Promise<Response> {
	const body = (await request.json()) as { apple_token: string; display_name?: string };
	const appleSub = await verifyAppleToken(body.apple_token);
	if (!appleSub) {
		return new Response(JSON.stringify({ error: 'Invalid Apple token' }), { status: 401, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const displayName = body.display_name || 'Tones User';
	const userId = crypto.randomUUID();

	let user = await env.DB.prepare(
		'SELECT id, apple_sub, username, display_name, avatar_url, created_at, updated_at FROM users WHERE apple_sub = ?'
	).bind(appleSub).first<{ id: string; apple_sub: string; username: string | null; display_name: string; avatar_url: string | null; created_at: number; updated_at: number }>();

	if (!user) {
		await env.DB.prepare(
			'INSERT INTO users (id, apple_sub, display_name, created_at, updated_at) VALUES (?, ?, ?, ?, ?)'
		).bind(userId, appleSub, displayName, Date.now(), Date.now()).run();

		user = { id: userId, apple_sub: appleSub, username: null, display_name: displayName, avatar_url: null, created_at: Date.now(), updated_at: Date.now() };
	} else if (displayName && displayName !== 'Tones User') {
		await env.DB.prepare(
			'UPDATE users SET display_name = ?, updated_at = ? WHERE id = ? AND display_name = ?'
		).bind(displayName, Date.now(), user.id, 'Tones User').run();
		user = { ...user, display_name: displayName, updated_at: Date.now() };
	}

	const tokens = await createSession(user.id, env);

	return new Response(JSON.stringify({
		user: formatUser(user),
		access_token: tokens.access_token,
		refresh_token: tokens.refresh_token,
	}), { headers: { ...cors, 'Content-Type': 'application/json' } });
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

	const { username } = await request.json();

	if (!username || username.length < 3 || username.length > 20) {
		return new Response(JSON.stringify({ error: 'Username must be 3-20 characters' }), { status: 400, headers: { ...cors, 'Content-Type': 'application/json' } });
	}

	const normalizedUsername = username.toLowerCase().replace(/[^a-z0-9_]/g, '');

	const existing = await env.DB.prepare(
		'SELECT id FROM users WHERE username = ? AND id != ?'
	).bind(normalizedUsername, auth.userId).first<{ id: string }>();

	if (existing) {
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

async function verifyAppleToken(identityToken: string): Promise<string | null> {
	try {
		const parts = identityToken.split('.');
		if (parts.length !== 3) return null;
		const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')));
		if (payload.iss !== 'https://appleid.apple.com') return null;
		const now = Math.floor(Date.now() / 1000);
		if (payload.exp && payload.exp < now) return null;
		return payload.sub || null;
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

	const users = await env.DB.prepare(
		'SELECT id, username, display_name FROM users WHERE username LIKE ? AND id != ? LIMIT 20'
	).bind(q + '%', auth.userId).all<{ id: string; username: string; display_name: string }>();

	return new Response(JSON.stringify(users.results || []), { headers: { ...cors, 'Content-Type': 'application/json' } });
}