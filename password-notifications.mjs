// Supabase database webhook -> a single verified Cloudflare email destination.
// Configure NOTIFY_TOKEN as a secret; never put it in the app or GitHub.
const recipient = 'juancruz19@hotmail.com';
const sender = 'avisos@pheloxapp.com';
const dashboard = 'https://supabase.com/dashboard/project/qpkivgrrkudrcjytevjy/auth/users';

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') return new Response('Method not allowed', {status: 405});
    if (!env.NOTIFY_TOKEN || env.NOTIFY_TOKEN.length < 32 || !env.EMAIL) {
      return new Response('Not configured', {status: 503});
    }
    const authorization = request.headers.get('Authorization') || '';
    const expected = 'Bearer ' + env.NOTIFY_TOKEN;
    const hash = async value => new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value)));
    const [a, b] = await Promise.all([hash(authorization), hash(expected)]);
    let difference = 0;
    for (let i = 0; i < a.length; i++) difference |= a[i] ^ b[i];
    if (difference) return new Response('Unauthorized', {status: 401});
    if (Number(request.headers.get('Content-Length')) > 16384) return new Response('Too large', {status: 413});
    const raw = await request.text();
    if (raw.length > 16384) return new Response('Too large', {status: 413});
    let event;
    try { event = JSON.parse(raw); } catch { return new Response('Invalid JSON', {status: 400}); }
    const record = event?.record;
    if (event.type !== 'INSERT' || event.schema !== 'public' || event.table !== 'password_reset_requests' || record?.status !== 'pendiente') {
      return new Response('Ignored', {status: 200});
    }
    if (!record.id || typeof record.username !== 'string' || !record.username.trim() || record.username.length > 200) {
      return new Response('Invalid request', {status: 400});
    }
    // Only an identifier is sent. Passwords, phone numbers and notes stay out of email.
    const username = record.username.replace(/[\r\n\x00-\x1f\x7f]/g, ' ');
    try {
      await env.EMAIL.send({
        to: recipient,
        from: sender,
        subject: 'PHELOX - Solicitud de recuperacion de contrasena',
        text: `El usuario ${username} solicita recuperar su contraseña.\n\nRevisá el pedido en la app: https://pheloxapp.com/\n\nPara enviar la recuperación, abrí Supabase y usá Send password recovery para el usuario correspondiente:\n${dashboard}\n\nDespués marcá la solicitud como atendida en la app. Cada usuario elige su contraseña desde el enlace recibido.`,
      });
      return Response.json({ok: true});
    } catch {
      // Return failure to the webhook without exposing credentials or user data.
      return new Response('Email delivery failed', {status: 502});
    }
  },
};
