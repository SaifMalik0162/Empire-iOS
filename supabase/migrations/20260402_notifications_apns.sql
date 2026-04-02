create extension if not exists pgcrypto;

alter table if exists public.post_likes
    add column if not exists created_at timestamptz not null default timezone('utc', now());

alter table if exists public.user_follows
    add column if not exists created_at timestamptz not null default timezone('utc', now());

create table if not exists public.user_push_tokens (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    device_token text not null unique,
    platform text not null default 'ios',
    environment text not null default 'development',
    bundle_id text not null,
    is_active boolean not null default true,
    last_seen_at timestamptz not null default timezone('utc', now()),
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists user_push_tokens_user_id_idx
    on public.user_push_tokens(user_id);

create table if not exists public.notification_preferences (
    user_id uuid primary key references auth.users(id) on delete cascade,
    likes boolean not null default true,
    comments boolean not null default true,
    follows boolean not null default true,
    meets boolean not null default true,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.notification_events (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    actor_user_id uuid references auth.users(id) on delete set null,
    event_type text not null check (event_type in ('like', 'comment', 'follow', 'meet')),
    title text not null,
    body text not null,
    deep_link text,
    payload jsonb not null default '{}'::jsonb,
    dedupe_key text unique,
    status text not null default 'pending' check (status in ('pending', 'delivered', 'failed')),
    delivered_at timestamptz,
    error_message text,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists notification_events_user_id_idx
    on public.notification_events(user_id, created_at desc);

create index if not exists notification_events_pending_idx
    on public.notification_events(status, created_at asc);

create or replace function public.set_row_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = timezone('utc', now());
    return new;
end;
$$;

drop trigger if exists set_user_push_tokens_updated_at on public.user_push_tokens;
create trigger set_user_push_tokens_updated_at
before update on public.user_push_tokens
for each row execute procedure public.set_row_updated_at();

drop trigger if exists set_notification_preferences_updated_at on public.notification_preferences;
create trigger set_notification_preferences_updated_at
before update on public.notification_preferences
for each row execute procedure public.set_row_updated_at();

drop trigger if exists set_notification_events_updated_at on public.notification_events;
create trigger set_notification_events_updated_at
before update on public.notification_events
for each row execute procedure public.set_row_updated_at();

alter table public.user_push_tokens enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.notification_events enable row level security;

drop policy if exists "push_tokens_select_own" on public.user_push_tokens;
create policy "push_tokens_select_own"
on public.user_push_tokens
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "push_tokens_insert_own" on public.user_push_tokens;
create policy "push_tokens_insert_own"
on public.user_push_tokens
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "push_tokens_update_own" on public.user_push_tokens;
create policy "push_tokens_update_own"
on public.user_push_tokens
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "notification_preferences_select_own" on public.notification_preferences;
create policy "notification_preferences_select_own"
on public.notification_preferences
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "notification_preferences_upsert_own" on public.notification_preferences;
create policy "notification_preferences_upsert_own"
on public.notification_preferences
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "notification_preferences_update_own" on public.notification_preferences;
create policy "notification_preferences_update_own"
on public.notification_preferences
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "notification_events_select_own" on public.notification_events;
create policy "notification_events_select_own"
on public.notification_events
for select
to authenticated
using (auth.uid() = user_id);

create or replace function public.notification_preferences_for(target_user_id uuid)
returns public.notification_preferences
language sql
stable
as $$
    select *
    from public.notification_preferences
    where user_id = target_user_id
$$;

create or replace function public.enqueue_post_like_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    owner_id uuid;
    actor_name text;
    car_name text;
    prefs public.notification_preferences;
begin
    select cp.user_id::uuid, cp.car_name
    into owner_id, car_name
    from public.community_posts cp
    where cp.id::uuid = new.post_id;

    if owner_id is null or owner_id = new.user_id then
        return new;
    end if;

    select * into prefs
    from public.notification_preferences
    where user_id = owner_id;

    if prefs.user_id is not null and prefs.likes is false then
        return new;
    end if;

    select coalesce(nullif(trim(p.username), ''), 'An Empire driver')
    into actor_name
    from public.profiles p
    where p.id::uuid = new.user_id;

    insert into public.notification_events (
        user_id,
        actor_user_id,
        event_type,
        title,
        body,
        deep_link,
        payload
    ) values (
        owner_id,
        new.user_id,
        'like',
        actor_name || ' liked your build',
        coalesce(car_name, 'Your build') || ' got some love.',
        'empireconnect://post/' || new.post_id::text,
        jsonb_build_object('post_id', new.post_id::text)
    );

    return new;
end;
$$;

create or replace function public.enqueue_post_comment_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    owner_id uuid;
    actor_name text;
    car_name text;
    prefs public.notification_preferences;
begin
    select cp.user_id::uuid, cp.car_name
    into owner_id, car_name
    from public.community_posts cp
    where cp.id::uuid = new.post_id;

    if owner_id is null or owner_id = new.user_id then
        return new;
    end if;

    select * into prefs
    from public.notification_preferences
    where user_id = owner_id;

    if prefs.user_id is not null and prefs.comments is false then
        return new;
    end if;

    select coalesce(nullif(trim(p.username), ''), 'An Empire driver')
    into actor_name
    from public.profiles p
    where p.id::uuid = new.user_id;

    insert into public.notification_events (
        user_id,
        actor_user_id,
        event_type,
        title,
        body,
        deep_link,
        payload
    ) values (
        owner_id,
        new.user_id,
        'comment',
        actor_name || ' commented on your build',
        left(coalesce(new.body, 'Open Empire to read the latest comment.'), 160),
        'empireconnect://post/' || new.post_id::text,
        jsonb_build_object('post_id', new.post_id::text, 'comment_id', new.id::text)
    );

    return new;
end;
$$;

create or replace function public.enqueue_follow_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    actor_name text;
    prefs public.notification_preferences;
begin
    if new.follower_id = new.followed_id then
        return new;
    end if;

    select * into prefs
    from public.notification_preferences
    where user_id = new.followed_id::uuid;

    if prefs.user_id is not null and prefs.follows is false then
        return new;
    end if;

    select coalesce(nullif(trim(p.username), ''), 'An Empire driver')
    into actor_name
    from public.profiles p
    where p.id::uuid = new.follower_id::uuid;

    insert into public.notification_events (
        user_id,
        actor_user_id,
        event_type,
        title,
        body,
        deep_link,
        payload
    ) values (
        new.followed_id::uuid,
        new.follower_id::uuid,
        'follow',
        actor_name || ' followed you',
        'Your Empire profile has a new follower.',
        'empireconnect://profile/' || new.follower_id::text,
        jsonb_build_object('actor_user_id', new.follower_id::text)
    );

    return new;
end;
$$;

create or replace function public.enqueue_meet_update_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if row(new.title, new.city, new.date) is not distinct from row(old.title, old.city, old.date) then
        return new;
    end if;

    insert into public.notification_events (
        user_id,
        event_type,
        title,
        body,
        deep_link,
        payload
    )
    select
        mr.user_id::uuid,
        'meet',
        'Meet update: ' || new.title,
        'A meet you RSVP''d for was updated. Tap to review the latest details.',
        'empireconnect://meet/' || new.id::text,
        jsonb_build_object('meet_id', new.id::text, 'type', 'update')
    from public.meets_rsvp mr
    left join public.notification_preferences np on np.user_id = mr.user_id::uuid
    where mr.meet_id::uuid = new.id::uuid
      and coalesce(np.meets, true)
      and mr.user_id::uuid is not null;

    return new;
end;
$$;

drop trigger if exists enqueue_post_like_notification_trigger on public.post_likes;
create trigger enqueue_post_like_notification_trigger
after insert on public.post_likes
for each row execute procedure public.enqueue_post_like_notification();

drop trigger if exists enqueue_post_comment_notification_trigger on public.post_comments;
create trigger enqueue_post_comment_notification_trigger
after insert on public.post_comments
for each row execute procedure public.enqueue_post_comment_notification();

drop trigger if exists enqueue_follow_notification_trigger on public.user_follows;
create trigger enqueue_follow_notification_trigger
after insert on public.user_follows
for each row execute procedure public.enqueue_follow_notification();

drop trigger if exists enqueue_meet_update_notifications_trigger on public.meets;
create trigger enqueue_meet_update_notifications_trigger
after update of title, city, date on public.meets
for each row execute procedure public.enqueue_meet_update_notifications();

create or replace function public.queue_meet_reminder_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    inserted_count integer := 0;
begin
    with reminder_candidates as (
        select
            mr.user_id::uuid as user_id,
            m.id::uuid as meet_id,
            m.title,
            m.city,
            m.date
        from public.meets_rsvp mr
        join public.meets m
            on m.id::uuid = mr.meet_id::uuid
        left join public.notification_preferences np
            on np.user_id = mr.user_id::uuid
        where coalesce(np.meets, true)
          and m.date between timezone('utc', now()) + interval '55 minutes'
                         and timezone('utc', now()) + interval '65 minutes'
    ), inserted as (
        insert into public.notification_events (
            user_id,
            event_type,
            title,
            body,
            deep_link,
            payload,
            dedupe_key
        )
        select
            rc.user_id,
            'meet',
            'Upcoming meet: ' || rc.title,
            rc.title || ' in ' || rc.city || ' starts in about an hour.',
            'empireconnect://meet/' || rc.meet_id::text,
            jsonb_build_object('meet_id', rc.meet_id::text, 'type', 'reminder'),
            'meet-reminder:' || rc.meet_id::text || ':' || rc.user_id::text
        from reminder_candidates rc
        on conflict (dedupe_key) do nothing
        returning 1
    )
    select count(*) into inserted_count from inserted;

    return inserted_count;
end;
$$;
