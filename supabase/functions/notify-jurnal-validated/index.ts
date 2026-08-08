import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

interface JurnalRecord {
  id: number;
  jadwal_id: number | null;
  tanggal: string | null;
  status: string;
  catatan_admin: string | null;
}

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: JurnalRecord;
  old_record: JurnalRecord | null;
}

function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

// Exchanges the Firebase service account key for a short-lived OAuth2 access
// token, since FCM's HTTP v1 API doesn't accept the key itself as a bearer token.
async function getFcmAccessToken(
  serviceAccount: { client_email: string; private_key: string },
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }))}.${
    base64url(JSON.stringify({
      iss: serviceAccount.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }))
  }`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(serviceAccount.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const jwt = `${unsigned}.${base64url(signature)}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!res.ok) {
    throw new Error(`Failed to get FCM access token: ${await res.text()}`);
  }
  const data = await res.json();
  return data.access_token as string;
}

Deno.serve(async (req) => {
  try {
    const payload = (await req.json()) as WebhookPayload;

    if (payload.table !== "jurnal_harian" || payload.type !== "UPDATE") {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    const { record, old_record } = payload;
    const statusChanged = old_record?.status !== record.status;
    const isValidated = record.status === "approved" || record.status === "rejected";
    if (!statusChanged || !isValidated) {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    if (!FIREBASE_SERVICE_ACCOUNT) {
      throw new Error("FIREBASE_SERVICE_ACCOUNT secret is not set");
    }
    const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: jadwal, error: jadwalError } = await supabase
      .from("jadwal_mengajar")
      .select("guru_id")
      .eq("id", record.jadwal_id)
      .maybeSingle();
    if (jadwalError) throw jadwalError;
    if (!jadwal?.guru_id) {
      return new Response(
        JSON.stringify({ skipped: true, reason: "no guru_id for jadwal_id" }),
        { status: 200 },
      );
    }

    const { data: tokens, error: tokensError } = await supabase
      .from("user_fcm_tokens")
      .select("fcm_token")
      .eq("user_id", jadwal.guru_id);
    if (tokensError) throw tokensError;
    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ skipped: true, reason: "no fcm tokens for guru" }),
        { status: 200 },
      );
    }

    const isApproved = record.status === "approved";
    const title = isApproved ? "Jurnal Disetujui" : "Jurnal Ditolak";
    const body = isApproved
      ? `Jurnal mengajar tanggal ${record.tanggal ?? "-"} telah disetujui.`
      : `Jurnal mengajar tanggal ${record.tanggal ?? "-"} ditolak.${
        record.catatan_admin ? ` Catatan: ${record.catatan_admin}` : ""
      }`;

    const accessToken = await getFcmAccessToken(serviceAccount);

    const results = await Promise.all(
      tokens.map(async ({ fcm_token }) => {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${accessToken}`,
            },
            body: JSON.stringify({
              message: {
                token: fcm_token,
                notification: { title, body },
                data: {
                  jurnal_id: String(record.id),
                  status: record.status,
                },
              },
            }),
          },
        );
        return { token: fcm_token, ok: res.ok, status: res.status };
      }),
    );

    return new Response(JSON.stringify({ sent: results }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error(error);
    return new Response(JSON.stringify({ error: String(error) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
