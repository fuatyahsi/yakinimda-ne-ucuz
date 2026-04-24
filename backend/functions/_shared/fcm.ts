// FCM HTTP v1 helper — Deno / Supabase Edge Functions
//
// FCM v1 legacy server key (AIza...) değil, OAuth2 access token ile
// çalışır. Service account JSON'ını FIREBASE_SERVICE_ACCOUNT_JSON env
// değişkeninden okur, self-signed JWT üretip token'a çevirir.
//
// Sebebi: Google 2024 ortasında legacy FCM API'yi kapattı. v1 zorunlu.

import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.1/mod.ts";

export interface FcmMessage {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

interface ServiceAccount {
  client_email: string;
  private_key: string;
  project_id: string;
}

function parseServiceAccount(): ServiceAccount {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) {
    throw new Error(
      "FIREBASE_SERVICE_ACCOUNT_JSON env değişkeni tanımlı değil. " +
        "Firebase Console → Service Accounts → Generate new private key.",
    );
  }
  const parsed = JSON.parse(raw) as ServiceAccount;
  if (!parsed.private_key || !parsed.client_email || !parsed.project_id) {
    throw new Error("Service account JSON eksik alanlar içeriyor.");
  }
  return parsed;
}

async function pemToCryptoKey(pem: string): Promise<CryptoKey> {
  const pkcs8 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\s+/g, "");
  const binary = Uint8Array.from(atob(pkcs8), (c) => c.charCodeAt(0));
  return await crypto.subtle.importKey(
    "pkcs8",
    binary,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

let cachedToken: { token: string; expiresAt: number } | null = null;

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  if (cachedToken && cachedToken.expiresAt > Date.now() + 30_000) {
    return cachedToken.token;
  }
  const key = await pemToCryptoKey(sa.private_key);
  const now = getNumericDate(0);
  const jwt = await create(
    { alg: "RS256", typ: "JWT" },
    {
      iss: sa.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: getNumericDate(3600),
    },
    key,
  );
  const body = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion: jwt,
  });
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!res.ok) {
    throw new Error(`OAuth token exchange failed: ${res.status} ${await res.text()}`);
  }
  const json = await res.json();
  cachedToken = {
    token: json.access_token as string,
    expiresAt: Date.now() + ((json.expires_in as number) * 1000),
  };
  return cachedToken.token;
}

export interface SendResult {
  success: boolean;
  error?: string;
  messageId?: string;
  invalidToken?: boolean;
}

export async function sendFcm(msg: FcmMessage): Promise<SendResult> {
  const sa = parseServiceAccount();
  const token = await getAccessToken(sa);
  const url =
    `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;

  const payload = {
    message: {
      token: msg.token,
      notification: { title: msg.title, body: msg.body },
      data: msg.data ?? {},
      android: {
        priority: "HIGH",
        notification: { channel_id: "deal_alerts" },
      },
      apns: {
        headers: { "apns-priority": "10" },
        payload: { aps: { sound: "default" } },
      },
    },
  };
  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  if (res.ok) {
    const body = await res.json();
    return { success: true, messageId: body.name as string };
  }
  const errBody = await res.text();
  const invalidToken = res.status === 404 ||
    errBody.includes("UNREGISTERED") ||
    errBody.includes("INVALID_ARGUMENT");
  return {
    success: false,
    error: `${res.status} ${errBody}`,
    invalidToken,
  };
}
