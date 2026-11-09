import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-device-id, x-device-secret, x-retry-count, traceparent, tracestate, baggage',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
};

export class HttpError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

export function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

export function handleOptions(req: Request): Response | null {
  return req.method === 'OPTIONS' ? new Response('ok', { headers: corsHeaders }) : null;
}

export function adminClient(): SupabaseClient {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !key) throw new HttpError(500, 'Secret Supabase untuk fungsi belum dikonfigurasi.');
  return createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
}

export async function authenticatedUser(req: Request): Promise<{ id: string }> {
  const authorization = req.headers.get('Authorization');
  const token = authorization?.replace(/^Bearer\s+/i, '');
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_ANON_KEY');
  if (!token || !url || !key) throw new HttpError(401, 'Sesi aplikasi tidak valid. Buka ulang aplikasi.');
  const client = createClient(url, key, { global: { headers: { Authorization: `Bearer ${token}` } }, auth: { persistSession: false, autoRefreshToken: false } });
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, 'Sesi aplikasi tidak valid. Pairing ulang perangkat.');
  return { id: data.user.id };
}

export async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, '0')).join('');
}

export async function authenticatedDevice(req: Request) {
  const deviceId = req.headers.get('x-device-id') ?? '';
  const secret = req.headers.get('x-device-secret') ?? '';
  if (!/^[0-9a-f-]{36}$/i.test(deviceId) || secret.length < 32) throw new HttpError(401, 'Kredensial perangkat tidak valid.');
  const db = adminClient();
  const { data: device, error } = await db.from('devices').select('id,enabled,device_secret_hash').eq('id', deviceId).maybeSingle();
  if (error) throw new HttpError(500, 'Tidak dapat memeriksa perangkat.');
  if (!device || !device.enabled || !constantTimeEqual(await sha256(secret), device.device_secret_hash)) throw new HttpError(401, 'Kredensial perangkat tidak valid.');
  return { db, deviceId };
}

function constantTimeEqual(left: string, right: string): boolean {
  if (left.length !== right.length) return false;
  let mismatch = 0;
  for (let index = 0; index < left.length; index++) mismatch |= left.charCodeAt(index) ^ right.charCodeAt(index);
  return mismatch === 0;
}

export async function readJson(req: Request): Promise<Record<string, unknown>> {
  try {
    const value = await req.json();
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('object required');
    return value as Record<string, unknown>;
  } catch {
    throw new HttpError(400, 'Isi permintaan tidak valid.');
  }
}

export async function run(handler: (req: Request) => Promise<Response>, req: Request): Promise<Response> {
  const options = handleOptions(req);
  if (options) return options;
  try {
    if (req.method !== 'POST') throw new HttpError(405, 'Metode permintaan tidak didukung.');
    return await handler(req);
  } catch (error) {
    console.error(error);
    const status = error instanceof HttpError ? error.status : 500;
    const message = error instanceof HttpError ? error.message : 'Terjadi kesalahan pada server.';
    return json({ error: message }, status);
  }
}
