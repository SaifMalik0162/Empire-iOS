create or replace function public.enforce_profiles_username_cooldown_14d()
returns trigger
language plpgsql
as $$
declare
  old_username text;
  new_username text;
begin
  old_username := nullif(btrim(old.username), '');
  new_username := nullif(btrim(new.username), '');

  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if new_username is null or old_username is not distinct from new_username then
    return new;
  end if;

  -- The first claimed username should not start the 14-day lockout window.
  if old_username is null then
    new.last_username_change_at := null;
    return new;
  end if;

  if old.last_username_change_at is not null
     and old.last_username_change_at > now() - interval '14 days' then
    raise exception 'Username can only be changed every 14 days.';
  end if;

  new.last_username_change_at := now();
  return new;
end;
$$;
