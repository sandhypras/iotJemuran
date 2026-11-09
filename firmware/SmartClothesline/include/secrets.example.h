#pragma once

// Salin file ini sebagai secrets.h lalu isi semua nilai.
// Jangan pernah unggah secrets.h ke repositori publik.
#define WIFI_SSID "NAMA_WIFI"
#define WIFI_PASSWORD "PASSWORD_WIFI"
#define SUPABASE_URL "https://PROJECT_REF.supabase.co"
#define SUPABASE_PUBLISHABLE_KEY "sb_publishable_GANTI_DENGAN_KEY_PROJECT"
#define DEVICE_ID "UUID_DARI_QUERY_INSERT_DEVICES"
#define DEVICE_SECRET "SECRET_ACAK_64_KARAKTER_HEX"

// Kode memakai pin digital DO seperti rangkaian lama:
// hujan aktif LOW, LDR mendeteksi gelap saat HIGH.
#define SERVO_CLOSED_ANGLE 0
#define SERVO_OPEN_ANGLE 150
