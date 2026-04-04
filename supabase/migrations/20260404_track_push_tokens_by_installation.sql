alter table if exists public.user_push_tokens
    add column if not exists installation_id text;

update public.user_push_tokens
set installation_id = gen_random_uuid()::text
where installation_id is null;

alter table if exists public.user_push_tokens
    alter column installation_id set not null;

create unique index if not exists user_push_tokens_installation_idx
    on public.user_push_tokens(installation_id, platform, bundle_id);

create index if not exists user_push_tokens_user_active_seen_idx
    on public.user_push_tokens(user_id, is_active, last_seen_at desc);
