import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");

const NOBOX_SEND_URL = "https://id.nobox.ai/Inbox/Send";

interface JurnalRecord {
  id: number;
  jadwal_id: number | null;
  tanggal: string | null;
  materi: string | null;
  status: string;
  catatan_admin: string | null;
}

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  record: JurnalRecord;
  old_record: JurnalRecord | null;
}

interface JadwalInfo {
  guru_id: string | null;
  kelas_id: number | null;
  master_kelas: { nama_kelas: string } | null;
  master_mata_pelajaran: { nama_mata_pelajaran: string } | null;
  profiles: { nama_lengkap: string } | null;
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

// Nobox expects local Indonesian numbers as `62xxxxxxxxxx` (no leading `0`,
// no `+`) — `master_siswa.no_hp_ortu` is stored as `08xxxxxxxxxx`.
function normalizeNoboxPhone(raw: string): string {
  const digits = raw.trim().replace(/\D/g, "");
  if (digits.startsWith("0")) return `62${digits.slice(1)}`;
  if (digits.startsWith("62")) return digits;
  return `62${digits}`;
}

// Notifies the guru who submitted the jurnal, on both approve and reject.
// Best-effort: a missing/broken FCM setup must not block the parent
// WhatsApp notifications below, so failures are captured, not thrown.
async function sendFcmToGuru(
  supabase: SupabaseClient,
  guruId: string,
  record: JurnalRecord,
): Promise<unknown> {
  try {
    if (!FIREBASE_SERVICE_ACCOUNT) {
      return { skipped: true, reason: "FIREBASE_SERVICE_ACCOUNT secret is not set" };
    }
    const serviceAccount = JSON.parse(FIREBASE_SERVICE_ACCOUNT);

    const { data: tokens, error: tokensError } = await supabase
      .from("user_fcm_tokens")
      .select("fcm_token")
      .eq("user_id", guruId);
    if (tokensError) throw tokensError;
    if (!tokens || tokens.length === 0) {
      return { skipped: true, reason: "no fcm tokens for guru" };
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

    return { sent: results };
  } catch (error) {
    console.error("FCM notification failed:", error);
    return { error: String(error) };
  }
}

// Notifies every student's parent in the jurnal's kelas via WhatsApp
// (Nobox.ai), only called when the jurnal was approved. `presensi_siswa`
// only logs exceptions (Izin/Sakit/Alpha) — a student with no row is
// assumed to have attended, so the message is personalized either way.
// Best-effort per recipient: one failed send (or an unconfigured Nobox
// account) must not block the guru's FCM notification above.
async function sendWhatsappToParents(
  supabase: SupabaseClient,
  jadwal: JadwalInfo,
  record: JurnalRecord,
): Promise<unknown> {
  try {
    const { data: settings, error: settingsError } = await supabase
      .from("pengaturan_aplikasi")
      .select("nobox_account_ids, nobox_token")
      .eq("id", 1)
      .maybeSingle();
    if (settingsError) throw settingsError;
    if (!settings?.nobox_account_ids || !settings?.nobox_token) {
      return { skipped: true, reason: "Nobox belum dikonfigurasi di Pengaturan" };
    }

    if (!jadwal.kelas_id) {
      return { skipped: true, reason: "jadwal has no kelas_id" };
    }

    const { data: siswaList, error: siswaError } = await supabase
      .from("master_siswa")
      .select("id, nama_siswa, no_hp_ortu")
      .eq("kelas_id", jadwal.kelas_id)
      .not("no_hp_ortu", "is", null);
    if (siswaError) throw siswaError;
    if (!siswaList || siswaList.length === 0) {
      return { skipped: true, reason: "no siswa with parent phone in kelas" };
    }

    const { data: presensi, error: presensiError } = await supabase
      .from("presensi_siswa")
      .select("siswa_id, status")
      .eq("jurnal_id", record.id);
    if (presensiError) throw presensiError;
    const absenceBySiswa = new Map<number, string>(
      (presensi ?? []).map((p) => [p.siswa_id as number, p.status as string]),
    );

    const mapel = jadwal.master_mata_pelajaran?.nama_mata_pelajaran ?? "-";
    const kelas = jadwal.master_kelas?.nama_kelas ?? "-";
    const guru = jadwal.profiles?.nama_lengkap ?? "-";
    const tanggal = record.tanggal ?? "-";

    const results = await Promise.all(
      siswaList.map(async (siswa) => {
        const absenceStatus = absenceBySiswa.get(siswa.id as number);
        const body = absenceStatus
          ? `Yth. Orang Tua/Wali dari ${siswa.nama_siswa},\nJurnal mengajar ${mapel} kelas ${kelas} tanggal ${tanggal} bersama ${guru} telah disetujui.\nAnanda tercatat *${absenceStatus}* pada pertemuan ini.`
          : `Yth. Orang Tua/Wali dari ${siswa.nama_siswa},\nJurnal mengajar ${mapel} kelas ${kelas} tanggal ${tanggal} bersama ${guru} telah disetujui.\nMateri: ${record.materi ?? "-"}`;

        const res = await fetch(NOBOX_SEND_URL, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "x-api-key": settings.nobox_token,
          },
          body: JSON.stringify({
            ExtId: normalizeNoboxPhone(siswa.no_hp_ortu as string),
            ChannelId: "1",
            AccountIds: settings.nobox_account_ids,
            BodyType: "Text",
            Body: body,
            Attachment: "",
          }),
        });
        return { siswa_id: siswa.id, ok: res.ok, status: res.status };
      }),
    );

    return { sent: results };
  } catch (error) {
    console.error("Parent WhatsApp notification failed:", error);
    return { error: String(error) };
  }
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

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    const { data: jadwal, error: jadwalError } = await supabase
      .from("v_jadwal_mengajar")
      .select("guru_id, kelas_id, master_kelas, master_mata_pelajaran, profiles")
      .eq("id", record.jadwal_id)
      .maybeSingle();
    if (jadwalError) throw jadwalError;
    if (!jadwal?.guru_id) {
      return new Response(
        JSON.stringify({ skipped: true, reason: "no guru_id for jadwal_id" }),
        { status: 200 },
      );
    }

    const [fcm, whatsapp] = await Promise.all([
      sendFcmToGuru(supabase, jadwal.guru_id, record),
      record.status === "approved"
        ? sendWhatsappToParents(supabase, jadwal as JadwalInfo, record)
        : Promise.resolve({ skipped: true, reason: "not approved" }),
    ]);

    return new Response(JSON.stringify({ fcm, whatsapp }), {
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
