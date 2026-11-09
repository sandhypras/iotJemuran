import { authenticatedDevice, HttpError, json, readJson, run } from '../_shared/http.ts';

Deno.serve((req) => run(async (request) => {
  const { db, deviceId } = await authenticatedDevice(request);
  const body = await readJson(request);
  if (body.action === 'next') {
    const { data: command, error } = await db.from('device_commands').select('id,command_type,payload,created_at').eq('device_id', deviceId).eq('status', 'queued').order('sequence_no').limit(1).maybeSingle();
    if (error) throw new HttpError(500, 'Antrean perintah belum dapat dibaca.');
    return json({ command: command ?? null });
  }
  if (body.action === 'ack') {
    const commandId = typeof body.command_id === 'string' ? body.command_id : '';
    if (!/^[0-9a-f-]{36}$/i.test(commandId) || typeof body.success !== 'boolean') throw new HttpError(400, 'Acknowledgment tidak valid.');
    const status = body.success ? 'completed' : 'failed';
    const message = typeof body.message === 'string' ? body.message.slice(0, 240) : null;
    const { data, error } = await db.from('device_commands').update({ status, result_message: message, processed_at: new Date().toISOString() }).eq('id', commandId).eq('device_id', deviceId).eq('status', 'queued').select('id').maybeSingle();
    if (error) throw new HttpError(500, 'Hasil perintah belum dapat disimpan.');
    return json({ ok: true, acknowledged: data != null });
  }
  throw new HttpError(400, 'Aksi perangkat tidak dikenal.');
}, req));
