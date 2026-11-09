# Smart Clothesline

Aplikasi Android Flutter untuk memantau jemuran otomatis ESP8266 melalui Supabase. Aplikasi tidak meminta akun/email. Saat pertama dibuka, aplikasi membuat sesi anonim Supabase, lalu mengikat sesi tersebut ke perangkat setelah kode pairing benar.

## Struktur proyek

```text
lib/                         aplikasi Flutter
  core/                      konfigurasi dan tema
  data/                      akses Supabase
  models/                    model data
  screens/                   dashboard, riwayat, pairing
  widgets/                   kartu sensor
supabase/
  migrations/                tabel, index, RLS, Realtime
  functions/                 pairing, command, dan data perangkat
firmware/SmartClothesline/   firmware PlatformIO untuk ESP8266
```

## Menjalankan workspace yang sudah disiapkan

Proyek Supabase yang tertaut sudah menerima migrasi database, empat Edge Function sudah aktif, dan perangkat `Jemuran Rumah` sudah didaftarkan. Konfigurasi aplikasi lokal ada di `supabase.env.json`. Kode pairing lokal ada di `firmware/SmartClothesline/pairing-code.txt`.

Untuk menjalankan aplikasi di Chrome:

```powershell
flutter run -d chrome --dart-define-from-file=supabase.env.json
```

Untuk menyambungkan ESP8266, isi `WIFI_SSID` dan `WIFI_PASSWORD` pada `firmware/SmartClothesline/include/secrets.h`. UUID, publishable key, dan secret perangkat sudah disiapkan di file lokal tersebut. File kredensial lokal diabaikan Git; jangan pindahkan secret perangkat ke file contoh atau unggah ke repositori.

## 1. Siapkan Supabase

1. Buat proyek baru di Supabase dan simpan **Project URL** serta **publishable key**. Publishable key memang dipakai aplikasi; **jangan pernah menaruh Service Role Key di Flutter atau firmware**.
2. Aktifkan anonymous sign-ins di Dashboard Supabase: **Authentication → Sign In / Providers → Anonymous Sign-Ins**. Anonymous session tidak meminta pengguna login.
3. Pasang Supabase CLI, lalu dari folder proyek jalankan:

   ```powershell
   supabase login
   supabase link --project-ref PROJECT_REF
   supabase db push
   ```

   Migrasi `supabase/migrations/202610300001_smart_clothesline.sql` membuat tabel perangkat, status, data sensor, riwayat, command queue, RLS, dan publikasi Realtime.
4. Deploy empat Edge Function:

   ```powershell
   supabase functions deploy pair-device
   supabase functions deploy send-command
   supabase functions deploy device-data
   supabase functions deploy device-commands
   ```

   `supabase/config.toml` mengatur validasi JWT: endpoint aplikasi memerlukan sesi Supabase; endpoint ESP8266 memvalidasi ID dan secret khusus perangkat di dalam fungsi. Edge Function memakai service key dari environment Supabase di server.
5. Bila fungsi baru tidak memakai secret bawaan Supabase, jangan menaruh secret di folder Flutter. Periksa **Edge Functions → Logs** jika ada error saat deployment.

### Buat kredensial perangkat

Buat kode pairing acak dan secret perangkat terpisah. Contoh PowerShell menghasilkan nilai heksadesimal acak:

```powershell
$pairingCode = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(16))
$deviceSecret = [Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$pairingCode
$deviceSecret
```

Jalankan query berikut di **SQL Editor**. Ganti placeholder dengan nilai tadi, lalu salin `id` hasil query:

```sql
insert into public.devices (name, pairing_code_hash, device_secret_hash)
values (
  'Jemuran Rumah',
  encode(extensions.digest('KODE_PAIRING_HEKSADESIMAL', 'sha256'), 'hex'),
  encode(extensions.digest('SECRET_PERANGKAT_HEKSADESIMAL', 'sha256'), 'hex')
)
returning id;
```

Kode pairing dimasukkan di aplikasi. Secret perangkat dan UUID hasil query dimasukkan hanya ke firmware ESP8266. Database hanya menyimpan hash keduanya. Untuk mencegah pairing baru, rotasi `pairing_code_hash`; untuk menonaktifkan akses perangkat yang sudah dipasangkan, set `enabled = false`. Akses satu sesi dapat dicabut dengan menghapus barisnya dari `app_device_access`.

## 2. Jalankan aplikasi Flutter

Salin `supabase.env.example.json` menjadi `supabase.env.json`, lalu isi URL dan publishable key proyek:

```json
{
  "SUPABASE_URL": "https://PROJECT_REF.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_..."
}
```

File tersebut sudah diabaikan Git. Jalankan aplikasi:

```powershell
flutter pub get
flutter run --dart-define-from-file=supabase.env.json
```

Dashboard memperbarui status melalui Supabase Realtime dan menandai perangkat offline jika heartbeat terakhir lebih dari 45 detik. Tab Riwayat menampilkan aktivitas dan sampel sensor berdasarkan tanggal. Data sensor dikirim firmware setiap 15 detik.

## 3. Sambungkan ESP8266 dan sensor

Firmware mengikuti rangkaian digital dari kode lama: modul hujan dan LDR dibaca dari pin DO, tanpa ADS1115.

| Modul | Sambungan NodeMCU |
| --- | --- |
| VCC / GND modul hujan dan LDR | 3V3 / GND NodeMCU |
| DO modul hujan | D7 |
| DO modul LDR | D6 |
| Sinyal servo | D1 |
| Servo V+ / GND | Catu daya servo eksternal / GND bersama |

Gunakan pin **DO**, bukan AO. Atur potensiometer pada modul sensor untuk menentukan batas hujan dan terang/gelap. Kode lama memakai hujan aktif LOW dan LDR gelap aktif HIGH. Jangan memberi daya servo dari pin 3V3 ESP8266; gunakan catu terpisah yang sesuai dan satukan ground catu servo dengan ground NodeMCU. Pastikan keluaran DO tidak melebihi 3,3 V.

1. Salin `firmware/SmartClothesline/include/secrets.example.h` menjadi `secrets.h` di folder yang sama.
2. Isi Wi-Fi, URL Supabase, publishable key, UUID perangkat, dan secret perangkat.
3. Pastikan sertifikat CA pada `supabase_root_ca.h` cocok dengan sertifikat untuk host proyek Anda. File ini memercayai ISRG Root X1 dan GlobalSign Root CA R1 yang sesuai dengan rantai sertifikat host proyek saat diperiksa. Rantai TLS dapat berubah; periksa issuer dan perbarui trust anchor sebelum masa berlakunya habis. Firmware tetap memverifikasi TLS.
4. Periksa Serial Monitor: log menampilkan status `BASAH/KERING` dan `GELAP/TERANG`. Jika status terbalik, sesuaikan potensiometer modul atau polaritas input digital pada firmware.
5. Dari `firmware/SmartClothesline`, unggah menggunakan PlatformIO:

   ```powershell
   pio run -t upload
   pio device monitor
   ```

Aturan otomatis lokal: sensor hujan selalu menutup jemuran, termasuk saat mode Manual. Saat kering dan mode Otomatis, status terang membuka jemuran dan status gelap menutupnya. Jika Wi-Fi/internet putus, aturan lokal terus bekerja. Perintah cloud yang masih antre diambil dan di-ack oleh perangkat setelah koneksi pulih.

## 4. Buat APK Android

APK release yang dapat dipasang:

```powershell
flutter build apk --release --dart-define-from-file=supabase.env.json
```

Hasilnya ada di `build/app/outputs/flutter-apk/app-release.apk`. Untuk distribusi di Play Store, atur signing key release Android sebelum publikasi. File `supabase.env.json` hanya menyediakan URL dan publishable key; kredensial perangkat tetap berada di firmware/server.

## Catatan operasional

- Pairing memakai anonymous Supabase Auth, bukan login dengan email. Jika data aplikasi dihapus atau aplikasi dipasang ulang, sesi anonim lama tidak dapat dipulihkan; masukkan kode pairing lagi.
- Pengguna aplikasi hanya dapat membaca baris perangkat yang dipasangkan. Aplikasi tidak mempunyai izin menulis tabel command secara langsung; semua command melewati Edge Function dan masuk antrean.
- Posisi jemuran dilaporkan setelah ESP8266 mengirim status berikutnya. Fungsi Edge mencatat perubahan mode/posisi di riwayat aktivitas.
- Potensiometer modul menentukan ambang digital sensor. Sudut servo bergantung pada mekanik jemuran; sesuaikan sebelum dibiarkan berjalan tanpa pengawasan.
