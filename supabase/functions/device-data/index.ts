import { authenticatedDevice, HttpError, json, readJson, run } from '../_shared/http.ts';

Deno.serve((req) => run(async (request) => {
  const { db, deviceId } = await authenticatedDevice(request);
  const body = await readJson(request);
  const mode = body.mode;
  const position = body.servo_position;
  const rainValue = body.rain_value;
  const lightPercent = body.light_percent;
  const rainDetected = body.rain_detected;
  if (!['automatic', 'manual'].includes(String(mode)) || !['open', 'closed'].includes(String(position))) throw new HttpError(400, 'Status mode atau posisi tidak valid.');
  if (!Number.isInteger(rainValue) || Number(rainValue) < 0 || Number(rainValue) > 32767) throw new HttpError(400, 'Nilai sensor hujan tidak valid.');
  if (typeof lightPercent !== 'number' || !Number.isFinite(lightPercent) || lightPercent < 0 || lightPercent > 100 || typeof rainDetected !== 'boolean') throw new HttpError(400, 'Data sensor cahaya atau hujan tidak valid.');

  const { data: previous, error: readError } = await db.from('device_status').select('mode,servo_position').eq('device_id', deviceId).maybeSingle();
  if (readError) throw new HttpError(500, 'Status perangkat belum dapat dibaca.');
  const now = new Date().toISOString();
  const { error: statusError } = await db.from('device_status').upsert({ device_id: deviceId, mode, servo_position: position, last_seen_at: now, updated_at: now });
  if (statusError) throw new HttpError(500, 'Status perangkat belum dapat disimpan.');
  const { error: sensorError } = await db.from('sensor_readings').insert({ device_id: deviceId, rain_value: rainValue, light_percent: lightPercent, rain_detected: rainDetected });
  if (sensorError) throw new HttpError(500, 'Data sensor belum dapat disimpan.');

  const events: Array<{ device_id: string; event_type: string; message: string; metadata: Record<string, string> }> = [];
  if (previous && previous.mode !== mode) events.push({ device_id: deviceId, event_type: 'mode_changed', message: mode === 'automatic' ? 'Mode diubah ke Otomatis' : 'Mode diubah ke Manual', metadata: { from: previous.mode, to: String(mode) } });
  if (previous && previous.servo_position !== position) events.push({ device_id: deviceId, event_type: position === 'open' ? 'line_opened' : 'line_closed', message: position === 'open' ? 'Jemuran dibuka' : 'Jemuran ditutup', metadata: { from: previous.servo_position, to: String(position) } });
  if (events.length) {
    const { error: eventError } = await db.from('activity_history').insert(events);
    if (eventError) throw new HttpError(500, 'Riwayat aktivitas belum dapat disimpan.');
  }
  return json({ ok: true, last_seen_at: now });
}, req));
