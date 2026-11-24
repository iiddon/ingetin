// Ingetin · Edge Function "push"
// Mengirim notifikasi pengingat ke HP walau aplikasi Ingetin sedang ditutup.
// - GET            -> { publicKey }   (kunci publik VAPID untuk berlangganan)
// - POST {test, endpoint} -> kirim notifikasi uji ke perangkat itu
// - POST {run}     -> cek pengingat yang jatuh tempo & kirim (dipanggil Cron tiap menit)
// Kunci VAPID dibuat otomatis sekali dan disimpan di tabel push_vapid (hanya bisa dibaca server).
import webpush from 'npm:web-push@3.6.7';
import { createClient } from 'npm:@supabase/supabase-js@2';

const URL_ = Deno.env.get('SUPABASE_URL')!;
const KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const sb = createClient(URL_, KEY, { auth: { persistSession: false } });
const CORS = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type', 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS' };
const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
const SUBJECT = 'https://iiddon.github.io/ingetin/';
const WINDOW_MIN = 15; // pengingat yang lewat lebih dari 15 menit tidak dikirim lagi

/* ---------- kunci VAPID ---------- */
let VAPID: { public_key: string; private_key: string } | null = null;
async function vapid() {
  if (VAPID) return VAPID;
  let { data } = await sb.from('push_vapid').select('public_key, private_key').eq('id', 1).maybeSingle();
  if (!data) {
    const k = webpush.generateVAPIDKeys();
    await sb.from('push_vapid').upsert({ id: 1, public_key: k.publicKey, private_key: k.privateKey }, { onConflict: 'id', ignoreDuplicates: true });
    ({ data } = await sb.from('push_vapid').select('public_key, private_key').eq('id', 1).single());
  }
  VAPID = data!;
  return VAPID;
}

/* ---------- tanggal (semua dalam waktu lokal pengguna, pakai offset menit) ---------- */
const HARI = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
const BULAN = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
const pad = (n: number) => String(n).padStart(2, '0');
const pd = (s: string) => { const [y, m, d] = s.split('-').map(Number); return new Date(Date.UTC(y, m - 1, d)); };
const ymd = (d: Date) => d.getUTCFullYear() + '-' + pad(d.getUTCMonth() + 1) + '-' + pad(d.getUTCDate());
const addDays = (d: Date, n: number) => new Date(d.getTime() + n * 86400000);
const diffDays = (a: string, b: string) => Math.round((pd(a).getTime() - pd(b).getTime()) / 86400000);
const fmtTime = (t?: string | null) => (t ? t.slice(0, 5).replace(':', '.') : '');
const fmtLong = (s: string) => { const d = pd(s); return HARI[d.getUTCDay()] + ', ' + d.getUTCDate() + ' ' + BULAN[d.getUTCMonth()] + ' ' + d.getUTCFullYear(); };
const rel = (s: string, today: string) => { const n = diffDays(s, today); if (n === 0) return 'Hari ini'; if (n === 1) return 'Besok'; if (n === 2) return 'Lusa'; if (n > 0) return 'H-' + n; return n === -1 ? 'Kemarin' : (-n) + ' hari lalu'; };
// waktu lokal (tanggal + jam) -> epoch ms, dengan offset tz (menit di timur UTC, WIB = 420)
const at = (date: string, hh: number, mm: number, tz: number) => pd(date).getTime() + (hh * 60 + mm - tz) * 60000;

/* ---------- acara berulang (sama dengan aplikasi) ---------- */
const REP = ['yearly', 'monthly', 'weekly', 'daily'];
const isRec = (e: Ev) => !!(e.repeat && REP.includes(e.repeat));
type Ev = { id: string; owner_id: string; title: string; date: string; time?: string | null; repeat?: string | null; reminders?: string[] | null; checklist?: { done?: boolean; skip?: boolean }[]; occ?: Record<string, { skip?: boolean; checklist?: { done?: boolean; skip?: boolean }[] }>; shared?: boolean; share_with?: string[] | null };
export function occDates(b: Ev, a: string, z: string) {
  const out: string[] = []; const start = b.date; if (z < start) return out;
  const sd = pd(start), A = pd(a > start ? a : start), skip = b.occ || {};
  const push = (k: string) => { if (k >= a && k <= z && k >= start && !(skip[k] && skip[k].skip)) out.push(k); };
  if (!isRec(b)) { push(start); return out; }
  if (b.repeat === 'daily') { let d = A; for (let i = 0; i < 800 && ymd(d) <= z; i++) { push(ymd(d)); d = addDays(d, 1); } }
  else if (b.repeat === 'weekly') { let d = addDays(sd, Math.max(0, Math.floor(diffDays(ymd(A), start) / 7)) * 7); for (let i = 0; i < 600 && ymd(d) <= z; i++) { push(ymd(d)); d = addDays(d, 7); } }
  else if (b.repeat === 'monthly') {
    const day = sd.getUTCDate(); let y = A.getUTCFullYear(), m = A.getUTCMonth();
    for (let i = 0; i < 400; i++) { const last = new Date(Date.UTC(y, m + 1, 0)).getUTCDate(); const k = ymd(new Date(Date.UTC(y, m, Math.min(day, last)))); if (k > z) break; push(k); if (++m > 11) { m = 0; y++; } }
  } else {
    const mo = sd.getUTCMonth(), day = sd.getUTCDate();
    for (let y = A.getUTCFullYear(); y < A.getUTCFullYear() + 120; y++) { const last = new Date(Date.UTC(y, mo + 1, 0)).getUTCDate(); const k = ymd(new Date(Date.UTC(y, mo, Math.min(day, last)))); if (k > z) break; push(k); }
  }
  return out;
}
const DAYS: Record<string, number> = { 'h-7': 7, 'h-3': 3, 'h-1': 1, 'hari-h': 0 };

export type Note = { key: string; title: string; body: string; ev: string };
// Semua pengingat yang jatuh tempo antara (now - WINDOW) dan now untuk satu pengguna.
export function dueFor(uid: string, events: Ev[], friendRem: Record<string, string[]>, tz: number, now: number): Note[] {
  const local = new Date(now + tz * 60000), today = ymd(local);
  const from = now - WINDOW_MIN * 60000, out: Note[] = [];
  const a = ymd(addDays(pd(today), -1)), z = ymd(addDays(pd(today), 8));
  for (const b of events) {
    const mine = b.owner_id === uid;
    const rs = (mine ? b.reminders : friendRem[b.id]) || (mine ? [] : ['h-1', 'hari-h']);
    for (const d of occDates(b, a, z)) {
      const id = isRec(b) ? b.id + '@' + d : b.id;
      for (const k0 of rs) {
        if (!(k0 in DAYS)) continue;
        const day = ymd(addDays(pd(d), -DAYS[k0]));
        const times: [string, number, string][] = [];
        if (DAYS[k0] === 0) {
          if (b.time) { const [hh, mm] = b.time.split(':').map(Number); const t = at(d, hh, mm || 0, tz); times.push(['hari-h', t - 3600000, '1 jam lagi · ' + fmtTime(b.time)], ['hari-h@0', t, 'Dimulai sekarang · ' + fmtTime(b.time)]); }
          else times.push(['hari-h', at(d, 7, 0, tz), 'Hari ini · ' + fmtLong(d)]);
        } else times.push([k0, at(day, 19, 0, tz), rel(d, ymd(new Date(at(day, 19, 0, tz) + tz * 60000))) + ' · ' + fmtLong(d) + (b.time ? ' ' + fmtTime(b.time) : '')]);
        for (const [k, t, body] of times) if (t > from && t <= now) out.push({ key: id + '|' + k + '|' + d, title: 'Ingetin: ' + b.title, body, ev: id });
      }
      // susulan: H+1 pukul 19.00 kalau persiapan acara milik sendiri belum beres
      if (mine && b.repeat !== 'daily') {
        const list: { done?: boolean; skip?: boolean }[] = isRec(b) ? ((b.occ || {})[d]?.checklist || (b.checklist || []).map(() => ({ done: false }))) : (b.checklist || []);
        const open = list.filter((x) => !x.done && !x.skip).length;
        const t = at(ymd(addDays(pd(d), 1)), 19, 0, tz);
        if (open && t > from && t <= now) out.push({ key: id + '|susulan', title: 'Ingetin: ' + b.title, body: open + ' persiapan belum ditandai beres', ev: id });
      }
    }
  }
  return out;
}

/* ---------- kirim ---------- */
type Sub = { endpoint: string; user_id: string; sub: webpush.PushSubscription; tz_min: number };
async function send(s: Sub, payload: Record<string, unknown>) {
  const v = await vapid();
  const r = webpush.generateRequestDetails(s.sub, JSON.stringify(payload), { vapidDetails: { subject: SUBJECT, publicKey: v.public_key, privateKey: v.private_key }, TTL: 3600, urgency: 'high' });
  const res = await fetch(r.endpoint, { method: r.method, headers: r.headers as Record<string, string>, body: new Uint8Array(r.body as unknown as ArrayBuffer) });
  if (res.status === 404 || res.status === 410) await sb.from('push_subs').delete().eq('endpoint', s.endpoint); // langganan kedaluwarsa
  await res.body?.cancel();
  return res.status;
}

async function run() {
  const { data: subs } = await sb.from('push_subs').select('endpoint, user_id, sub, tz_min');
  if (!subs || !subs.length) return { users: 0, sent: 0 };
  const byUser = new Map<string, Sub[]>();
  for (const s of subs as Sub[]) byUser.set(s.user_id, [...(byUser.get(s.user_id) || []), s]);
  const now = Date.now(); let sent = 0;
  for (const [uid, list] of byUser) {
    const { data: fr } = await sb.from('friendships').select('friend_id').eq('user_id', uid);
    const fids = (fr || []).map((x) => x.friend_id);
    const cols = 'id, owner_id, title, date, time, repeat, reminders, checklist, occ, shared, share_with';
    const { data: own } = await sb.from('events').select(cols).eq('owner_id', uid);
    let theirs: Ev[] = [];
    if (fids.length) { const { data } = await sb.from('events').select(cols).in('owner_id', fids).eq('shared', true); theirs = ((data || []) as Ev[]).filter((e) => !e.share_with || e.share_with.includes(uid)); }
    const { data: pref } = await sb.from('push_prefs').select('friend_rem').eq('user_id', uid).maybeSingle();
    const notes = dueFor(uid, [...((own || []) as Ev[]), ...theirs], (pref && pref.friend_rem) || {}, list[0].tz_min ?? 420, now);
    if (!notes.length) continue;
    // tandai terkirim; yang sudah ditandai (oleh server atau aplikasi yang sedang terbuka) dilewati
    const { data: fresh } = await sb.from('push_sent').upsert(notes.map((n) => ({ user_id: uid, key: n.key })), { onConflict: 'user_id,key', ignoreDuplicates: true }).select('key');
    const ok = new Set((fresh || []).map((x) => x.key));
    for (const n of notes) if (ok.has(n.key)) for (const s of list) { await send(s, { title: n.title, body: n.body, tag: n.key, ev: n.ev }).catch(() => 0); sent++; }
  }
  if (new Date().getUTCMinutes() === 0) await sb.from('push_sent').delete().lt('sent_at', new Date(now - 14 * 86400000).toISOString());
  return { users: byUser.size, sent };
}

if (import.meta.main) Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {
    if (req.method === 'GET') return json({ publicKey: (await vapid()).public_key });
    const body = await req.json().catch(() => ({}));
    if (body.test && body.endpoint) {
      const { data: s } = await sb.from('push_subs').select('endpoint, user_id, sub, tz_min').eq('endpoint', body.endpoint).maybeSingle();
      if (!s) return json({ ok: false, error: 'Perangkat belum terdaftar' }, 404);
      const st = await send(s as Sub, { title: 'Ingetin', body: 'Notifikasi dari server berhasil. Pengingat akan tetap datang walau aplikasi ditutup.', tag: 'ingetin-push-test' });
      return json({ ok: st >= 200 && st < 300, status: st });
    }
    return json({ ok: true, ...(await run()) });
  } catch (err) {
    return json({ ok: false, error: String((err as Error)?.message || err) }, 500);
  }
});
