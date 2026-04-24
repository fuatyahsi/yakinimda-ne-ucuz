// Edge Function: send_deal_notifications
//
// Ne yapar:
//   1) watches_to_trigger() SQL fonksiyonundan tetiklenmesi gereken
//      (user × ürün × market) satırlarını alır.
//   2) Her satır için notifications tablosuna dedupe_key ile UPSERT.
//      Daha önce aynı kombinasyon için kayıt varsa atlar.
//   3) Gerçekten yeni olan bildirimler için FCM push gönderir.
//   4) Başarısız token'ları (invalid/unregistered) user_profiles'tan temizler.
//   5) user_watches.last_notified_at'i günceller.
//
// Tetikleme:
//   Bu fonksiyon pg_cron'dan HTTP POST ile çağrılır. Örn:
//      SELECT net.http_post(
//        url := 'https://<project>.supabase.co/functions/v1/send_deal_notifications',
//        headers := '{"Authorization":"Bearer <service_role>"}'::jsonb
//      );
//   Ayrıca manuel test için de çağrılabilir.

import { getServiceClient } from "../_shared/supabase.ts";
import { sendFcm } from "../_shared/fcm.ts";

interface TriggerRow {
  watch_id: number;
  user_id: string;
  product_id: string;
  market_id: string;
  current_price: number;
  target_price: number | null;
  original_price: number | null;
  product_name: string;
  market_name: string;
  observed_at: string;
}

interface ProfileRow {
  user_id: string;
  fcm_token: string | null;
  notification_enabled: boolean;
}

function dedupeKey(row: TriggerRow): string {
  // "watch_triggered" tipinde, aynı kullanıcıya aynı product+market için
  // aynı günde iki kez bildirim gitmesin diye tarihi de dahil ediyoruz.
  const day = row.observed_at.slice(0, 10);
  return `watch:${row.product_id}:${row.market_id}:${day}`;
}

function formatPrice(value: number): string {
  return value.toFixed(2).replace(".", ",") + " TL";
}

function buildTitle(row: TriggerRow): string {
  return `Fiyat düştü — ${row.product_name}`;
}

function buildBody(row: TriggerRow): string {
  const price = formatPrice(row.current_price);
  if (row.target_price !== null) {
    return `${row.market_name} şimdi ${price} (hedef: ${formatPrice(row.target_price)})`;
  }
  if (row.original_price !== null && row.original_price > 0) {
    const drop = ((row.original_price - row.current_price) / row.original_price) * 100;
    return `${row.market_name} şimdi ${price} — %${drop.toFixed(0)} düşüş`;
  }
  return `${row.market_name} şimdi ${price}`;
}

async function run(): Promise<Response> {
  const supabase = getServiceClient();
  const startedAt = Date.now();

  // 1) Tetiklenecek satırlar
  const { data: triggers, error: triggerErr } = await supabase
    .rpc("watches_to_trigger", { p_user_id: null });
  if (triggerErr) {
    return jsonResponse(500, { error: `watches_to_trigger: ${triggerErr.message}` });
  }
  const rows = (triggers ?? []) as TriggerRow[];
  if (rows.length === 0) {
    return jsonResponse(200, {
      ok: true,
      triggers: 0,
      sent: 0,
      skipped_duplicate: 0,
      elapsed_ms: Date.now() - startedAt,
    });
  }

  // 2) Kullanıcı profilleri (fcm_token + notification_enabled)
  const userIds = Array.from(new Set(rows.map((r) => r.user_id)));
  const { data: profiles, error: profileErr } = await supabase
    .from("user_profiles")
    .select("user_id, fcm_token, notification_enabled")
    .in("user_id", userIds);
  if (profileErr) {
    return jsonResponse(500, { error: `user_profiles: ${profileErr.message}` });
  }
  const profileMap = new Map<string, ProfileRow>();
  for (const profile of (profiles ?? []) as ProfileRow[]) {
    profileMap.set(profile.user_id, profile);
  }

  let sent = 0;
  let skippedDuplicate = 0;
  let skippedNoToken = 0;
  let failed = 0;
  const tokensToInvalidate: string[] = [];

  for (const row of rows) {
    const profile = profileMap.get(row.user_id);
    if (!profile || !profile.notification_enabled) {
      skippedNoToken++;
      continue;
    }
    if (!profile.fcm_token) {
      skippedNoToken++;
      continue;
    }

    // 3) notifications insert (dedupe_key UNIQUE → çakışırsa atla)
    const notification = {
      user_id: row.user_id,
      type: "watch_triggered",
      product_id: row.product_id,
      market_id: row.market_id,
      title: buildTitle(row),
      body: buildBody(row),
      payload: {
        watch_id: row.watch_id,
        current_price: row.current_price,
        target_price: row.target_price,
        original_price: row.original_price,
        observed_at: row.observed_at,
      },
      dedupe_key: dedupeKey(row),
    };
    const { data: inserted, error: insertErr } = await supabase
      .from("notifications")
      .insert(notification)
      .select("id")
      .maybeSingle();

    if (insertErr) {
      // UNIQUE ihlali (23505) zaten gönderilmiş demek — sessiz geç
      if (insertErr.code === "23505") {
        skippedDuplicate++;
        continue;
      }
      failed++;
      console.error("notifications insert:", insertErr.message);
      continue;
    }
    if (!inserted) {
      skippedDuplicate++;
      continue;
    }

    // 4) FCM gönder
    const result = await sendFcm({
      token: profile.fcm_token,
      title: notification.title,
      body: notification.body,
      data: {
        type: "watch_triggered",
        product_id: row.product_id,
        market_id: row.market_id,
        watch_id: String(row.watch_id),
      },
    });
    if (result.success) {
      sent++;
    } else {
      failed++;
      if (result.invalidToken) {
        tokensToInvalidate.push(profile.user_id);
      }
      await supabase
        .from("notifications")
        .update({ delivery_status: "failed" })
        .eq("id", inserted.id);
    }

    // 5) last_notified_at güncelle
    await supabase
      .from("user_watches")
      .update({ last_notified_at: new Date().toISOString() })
      .eq("id", row.watch_id);
  }

  // 6) Invalid token'ları temizle
  if (tokensToInvalidate.length > 0) {
    await supabase
      .from("user_profiles")
      .update({ fcm_token: null })
      .in("user_id", tokensToInvalidate);
  }

  return jsonResponse(200, {
    ok: true,
    triggers: rows.length,
    sent,
    failed,
    skipped_duplicate: skippedDuplicate,
    skipped_no_token: skippedNoToken,
    cleared_tokens: tokensToInvalidate.length,
    elapsed_ms: Date.now() - startedAt,
  });
}

function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  // Sadece POST kabul et (cron çağıracak)
  if (req.method !== "POST") {
    return jsonResponse(405, { error: "Use POST" });
  }
  try {
    return await run();
  } catch (error) {
    console.error("send_deal_notifications fatal:", error);
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : String(error),
    });
  }
});
