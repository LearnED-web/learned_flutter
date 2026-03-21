import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const CRON_SHARED_SECRET = Deno.env.get('CRON_SHARED_SECRET');

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  throw new Error('SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required');
}

const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const authHeader = req.headers.get('Authorization') ?? '';
  const authToken = CRON_SHARED_SECRET ?? SUPABASE_SERVICE_ROLE_KEY;
  const expectedHeader = `Bearer ${authToken}`;
  if (authHeader !== expectedHeader) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const limit = Number.isInteger(body?.limit) ? body.limit : 50;
    const targetUserId = typeof body?.user_id === 'string' ? body.user_id : null;
    const targetEmail = typeof body?.email === 'string' ? body.email.trim().toLowerCase() : null;

    let resolvedUserId: string | null = targetUserId;
    let accountInfo: Record<string, unknown> | null = null;

    if (!resolvedUserId && targetEmail) {
      const { data: userRow, error: userError } = await adminClient
        .from('users')
        .select('id, email, deletion_status, scheduled_purge_at')
        .eq('email', targetEmail)
        .maybeSingle();

      if (userError) {
        return new Response(JSON.stringify({ error: userError.message }), {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      if (!userRow) {
        return new Response(JSON.stringify({ error: `No user found for email: ${targetEmail}` }), {
          status: 404,
          headers: { 'Content-Type': 'application/json' },
        });
      }

      resolvedUserId = userRow.id;
      accountInfo = userRow;
    }

    const { data, error } = await adminClient.rpc('process_account_purge', {
      p_user_id: resolvedUserId,
      p_limit: resolvedUserId ? 1 : limit,
    });

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({
      success: true,
      target: resolvedUserId ? { user_id: resolvedUserId, email: targetEmail } : null,
      account_info: accountInfo,
      result: data,
    }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
