import { adminClient, authenticatedUser, HttpError, json, readJson, run } from '../_shared/http.ts';

Deno.serve((req) => run(async (request) => {
  const user = await authenticatedUser(request);
  const body = await readJson(request);
  const deviceId = typeof body.device_id === 'string' ? body.device_id : '';
  const command = body.command;
  if (!/^[0-9a-f-]{36}$/i.test(deviceId)) throw new HttpError(400, 'Perangkat tidak valid.');
  if (!['set_mode', 'open', 'close'].includes(String(command))) throw new HttpError(400, 'Perintah tidak dikenal.');

  const db = adminClient();
  const { data: access } = await db.from('app_device_access').select('device_id').eq('user_id', user.id).eq('device_id', deviceId).maybeSingle();
  if (!access) throw new HttpError(403, 'Perangkat belum dipasangkan ke aplikasi ini.');
  const { data: device } = await db.from('devices').select('enabled').eq('id', deviceId).maybeSingle();
  if (!device?.enabled) throw new HttpError(403, 'Perangkat sedang dinonaktifkan.');

  const payload: Record<string, string> = {};
  if (command === 'set_mode') {
    if (body.mode !== 'automatic' && body.mode !== 'manual') throw new HttpError(400, 'Mode harus Otomatis atau Manual.');
    payload.mode = body.mode;
  } else {
    const { data: status } = await db.from('device_status').select('mode').eq('device_id', deviceId).maybeSingle();
    let effectiveMode = status?.mode;
    const { data: pendingMode } = await db.from('device_commands').select('payload').eq('device_id', deviceId).eq('status', 'queued').eq('command_type', 'set_mode').order('sequence_no', { ascending: false }).limit(1).maybeSingle();
    if (pendingMode?.payload?.mode === 'automatic' || pendingMode?.payload?.mode === 'manual') effectiveMode = pendingMode.payload.mode;
    if (effectiveMode !== 'manual') throw new HttpError(409, 'Pilih mode Manual sebelum menggerakkan jemuran.');
    if (command === 'open') {
      const { data: reading } = await db.from('sensor_readings').select('rain_detected').eq('device_id', deviceId).order('created_at', { ascending: false }).limit(1).maybeSingle();
      if (reading?.rain_detected === true) throw new HttpError(409, 'Jemuran tidak dapat dibuka saat sensor mendeteksi hujan.');
    }
  }

  const { data: queued, error } = await db.from('device_commands').insert({ device_id: deviceId, created_by: user.id, command_type: command, payload }).select('id,status,created_at').single();
  if (error) throw new HttpError(500, 'Perintah belum dapat dimasukkan ke antrean.');
  return json({ command_id: queued.id, status: queued.status, created_at: queued.created_at });
}, req));
