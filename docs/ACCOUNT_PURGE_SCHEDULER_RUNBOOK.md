# Account Purge Scheduler Runbook

This runbook operationalizes delayed account purging after retention expiry.

## What It Uses

- SQL function: `public.process_account_purge(p_user_id uuid, p_limit integer)`
- Edge Function: `supabase/functions/process-due-account-purges/index.ts`
- Trigger mode: scheduled HTTP POST (recommended every 24h or 1h)

## Deploy Edge Function

1. Ensure Supabase CLI is authenticated and linked to project `ugphaeiqbfejnzpiqdty`.
2. Deploy function:

```bash
supabase functions deploy process-due-account-purges --project-ref ugphaeiqbfejnzpiqdty --no-verify-jwt
```

3. Confirm required secrets are present (usually auto in hosted runtime):

```bash
supabase secrets list --project-ref ugphaeiqbfejnzpiqdty
```

Required at runtime:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `CRON_SHARED_SECRET`

Fallback behavior:
- If `CRON_SHARED_SECRET` is unavailable, the function accepts `Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>`.
- This fallback exists to unblock environments where secret management RBAC prevents adding new project secrets.

Set the scheduler secret:

```bash
supabase secrets set CRON_SHARED_SECRET=<strong-random-secret> --project-ref ugphaeiqbfejnzpiqdty
```

## Manual Invocation (No App Needed)

Use HTTP call to verify scheduler path immediately:

```bash
curl -X POST "https://ugphaeiqbfejnzpiqdty.functions.supabase.co/process-due-account-purges" \
  -H "Authorization: Bearer <CRON_SHARED_SECRET>" \
  -H "Content-Type: application/json" \
  -d '{"limit": 50}'
```

Expected success shape:

```json
{
  "success": true,
  "result": {
    "success": true,
    "processed": 0,
    "failed": 0
  }
}
```

## Suggested Schedule

- Production: every 24h at off-peak hours.
- Higher-volume environments: every 1h with `limit` of 50-200.

## Scheduler Options

1. Supabase Scheduled Functions (if enabled in project).
2. GitHub Actions/Azure DevOps cron hitting the function endpoint with `CRON_SHARED_SECRET`.
3. Any secure external cron job with HTTPS call.

## GitHub Actions Scheduler (Implemented)

Workflow file:
- `.github/workflows/account-purge-scheduler.yml`

Required GitHub repository secrets:
- `SUPABASE_PURGE_ENDPOINT` = `https://ugphaeiqbfejnzpiqdty.functions.supabase.co/process-due-account-purges`
- `CRON_SHARED_SECRET` = same value stored in Supabase secret `CRON_SHARED_SECRET`

Behavior:
- Runs daily at `02:15 UTC`
- Supports manual run with optional `limit` input

Important:
- Do not send `SUPABASE_SERVICE_ROLE_KEY` over HTTP to trigger the function.
- Use only `CRON_SHARED_SECRET` for endpoint authorization.

Temporary unblock note:
- If you cannot set `CRON_SHARED_SECRET` due RBAC, use the fallback above and rotate the service role key after RBAC is fixed.

## SQL Smoke Test (No App Needed)

Use `supabase/smoke_test_account_deletion.sql` in Supabase SQL Editor.

- It simulates an authenticated user request context.
- It validates:
  - RPC success
  - request row insertion
  - user status transitions to `requested`
- It always ends with `ROLLBACK`, so no persistent data changes.

## Operational Monitoring

- Check `trigger_logs` table for purge failures and error states.
- Alert when `failed > 0` in scheduler responses.
- Keep `p_limit` tuned so each run completes quickly.
