# Supabase Edge Functions

Bu klasördeki fonksiyonlar Deno runtime'ında çalışır, Supabase CLI ile
deploy edilir.

## Fonksiyonlar

### `send_deal_notifications`

Kullanıcıların izleme listesindeki ürünler indirime girdiğinde FCM push
bildirimi gönderir.

Akış:
1. `watches_to_trigger()` SQL fonksiyonunu çağırır — tetiklenmesi gereken
   (user, ürün, market, fiyat) satırlarını alır.
2. Her satır için `notifications` tablosuna `dedupe_key` ile INSERT.
   `UNIQUE (user_id, dedupe_key)` sayesinde aynı bildirim iki kez gitmez.
3. FCM HTTP v1 ile push gönderir (OAuth2 service account üzerinden).
4. Invalid token'ları `user_profiles.fcm_token`'dan temizler.
5. `user_watches.last_notified_at`'i günceller.

Tetikleme: pg_cron'dan her 15 dakikada bir HTTP POST.

## Paylaşılan modüller (`_shared/`)

- `supabase.ts` — service-role client. RLS bypass edildiği için
  sadece server-side import edilmeli.
- `fcm.ts` — FCM HTTP v1 wrapper. Service account JSON ile OAuth2
  access token üretir, token'ı 1 saat cache'ler.

## Deploy

```bash
# supabase CLI kurulu olmalı
supabase link --project-ref <proje-ref>

# Secrets
supabase secrets set \
  FIREBASE_SERVICE_ACCOUNT_JSON="$(cat path/to/service-account.json)"

# Fonksiyonu deploy et
supabase functions deploy send_deal_notifications --no-verify-jwt
```

`--no-verify-jwt`: Fonksiyon service_role Authorization header'ı ile
çağrılacak; Supabase'in JWT doğrulaması devre dışı kalsın. Güvenlik
service_role secret'inin gizliliğine dayanıyor — bu nedenle pg_cron
çağrısındaki Authorization header'ı asla loglara basılmamalı.

## pg_cron schedule örneği

```sql
SELECT cron.schedule(
  'send_deal_notifications',
  '*/15 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://<proje-ref>.functions.supabase.co/send_deal_notifications',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.service_role_key', true),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

`app.service_role_key` için Supabase dashboard → Settings → Database →
Custom config'te tanımlanmalı veya bir Vault secret'ine bakılmalı
(production'a geçerken.)

## Manuel test

```bash
curl -X POST \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  https://<proje-ref>.functions.supabase.co/send_deal_notifications
```

Beklenen çıktı:

```json
{
  "ok": true,
  "triggers": 12,
  "sent": 10,
  "failed": 1,
  "skipped_duplicate": 1,
  "skipped_no_token": 0,
  "cleared_tokens": 0,
  "elapsed_ms": 1850
}
```
