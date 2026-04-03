alter table if exists public.notification_events enable row level security;

create or replace function public.safe_insert_notification_event(
    p_user_id uuid,
    p_actor_user_id uuid,
    p_event_type text,
    p_title text,
    p_body text,
    p_deep_link text default null,
    p_payload jsonb default '{}'::jsonb,
    p_dedupe_key text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.notification_events (
        user_id,
        actor_user_id,
        event_type,
        title,
        body,
        deep_link,
        payload,
        dedupe_key
    ) values (
        p_user_id,
        p_actor_user_id,
        p_event_type,
        coalesce(nullif(trim(p_title), ''), 'Empire update'),
        coalesce(nullif(trim(p_body), ''), 'Open Empire to see the latest update.'),
        p_deep_link,
        coalesce(p_payload, '{}'::jsonb),
        p_dedupe_key
    );
exception
    when others then
        raise warning 'notification_events insert skipped for user %, event %, error: %',
            p_user_id, p_event_type, sqlerrm;
end;
$$;

create or replace function public.enqueue_post_like_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
    owner_id uuid;
    actor_name text := 'An Empire driver';
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

    select coalesce(nullif(trim(p.username), ''), actor_name)
    into actor_name
    from public.profiles p
    where p.id::uuid = new.user_id
    limit 1;

    perform public.safe_insert_notification_event(
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
    actor_name text := 'An Empire driver';
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

    select coalesce(nullif(trim(p.username), ''), actor_name)
    into actor_name
    from public.profiles p
    where p.id::uuid = new.user_id
    limit 1;

    perform public.safe_insert_notification_event(
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
    actor_name text := 'An Empire driver';
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

    select coalesce(nullif(trim(p.username), ''), actor_name)
    into actor_name
    from public.profiles p
    where p.id::uuid = new.follower_id::uuid
    limit 1;

    perform public.safe_insert_notification_event(
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
declare
    attendee record;
begin
    if row(new.title, new.city, new.date) is not distinct from row(old.title, old.city, old.date) then
        return new;
    end if;

    for attendee in
        select mr.user_id::uuid as user_id
        from public.meets_rsvp mr
        left join public.notification_preferences np on np.user_id = mr.user_id::uuid
        where mr.meet_id::uuid = new.id::uuid
          and coalesce(np.meets, true)
          and mr.user_id::uuid is not null
    loop
        perform public.safe_insert_notification_event(
            attendee.user_id,
            null,
            'meet',
            'Meet update: ' || coalesce(nullif(trim(new.title), ''), 'Empire meet'),
            'A meet you RSVP''d for was updated. Tap to review the latest details.',
            'empireconnect://meet/' || new.id::text,
            jsonb_build_object('meet_id', new.id::text, 'type', 'update')
        );
    end loop;

    return new;
end;
$$;

create or replace function public.queue_meet_reminder_events()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
    reminder_candidate record;
    inserted_count integer := 0;
begin
    for reminder_candidate in
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
    loop
        begin
            insert into public.notification_events (
                user_id,
                event_type,
                title,
                body,
                deep_link,
                payload,
                dedupe_key
            ) values (
                reminder_candidate.user_id,
                'meet',
                'Upcoming meet: ' || coalesce(nullif(trim(reminder_candidate.title), ''), 'Empire meet'),
                coalesce(nullif(trim(reminder_candidate.title), ''), 'Your meet')
                    || ' in '
                    || coalesce(nullif(trim(reminder_candidate.city), ''), 'your city')
                    || ' starts in about an hour.',
                'empireconnect://meet/' || reminder_candidate.meet_id::text,
                jsonb_build_object('meet_id', reminder_candidate.meet_id::text, 'type', 'reminder'),
                'meet-reminder:' || reminder_candidate.meet_id::text || ':' || reminder_candidate.user_id::text
            )
            on conflict (dedupe_key) do nothing;

            if found then
                inserted_count := inserted_count + 1;
            end if;
        exception
            when others then
                raise warning 'meet reminder enqueue skipped for user %, meet %, error: %',
                    reminder_candidate.user_id, reminder_candidate.meet_id, sqlerrm;
        end;
    end loop;

    return inserted_count;
end;
$$;
