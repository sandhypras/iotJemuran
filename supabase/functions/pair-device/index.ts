import { adminClient, authenticatedUser, HttpError, json, readJson, run, sha256 } from '../_shared/http.ts';

Deno.serve((req) => run(async (request) => {
  const user = await authenticatedUser(request);
  const body = await readJson(request);
  const pairingCode = typeof body.pairing_code === 'string' ? body.pairing_code.trim().toUpperCase() : '';
  if (!/^[A-Z0-9-]{8,40}$/.test(pairingCode)) throw new HttpError(400, 'Kode pairing harus terdiri dari 8–40 huruf, angka, atau tanda hubung.');

  const db = adminClient();
  const { data: device, error: lookupError } = await db.from('devices').select('id,name').eq('pairing_code_hash', await sha256(pairingCode)).eq('enabled', true).maybeSingle();
  if (lookupError) throw new HttpError(500, 'Tidak dapat memeriksa kode pairing.');
  if (!device) throw new HttpError(404, 'Kode pairing salah atau sudah tidak berlaku.');

  const { error: linkError } = await db.from('app_device_access').upsert({ user_id: user.id, device_id: device.id }, { onConflict: 'user_id,device_id', ignoreDuplicates: true });
  if (linkError) throw new HttpError(500, 'Perangkat ditemukan, tetapi akses belum dapat disimpan.');
  return json({ device_id: device.id, name: device.name });
}, req));
