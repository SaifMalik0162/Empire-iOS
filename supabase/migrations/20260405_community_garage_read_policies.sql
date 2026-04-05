alter table if exists public.cars enable row level security;
alter table if exists public.spec_items enable row level security;
alter table if exists public.mod_items enable row level security;

drop policy if exists "cars_select_own_or_public_community" on public.cars;
create policy "cars_select_own_or_public_community"
on public.cars
for select
to authenticated
using (
    auth.uid() is not null
    and (
        lower(trim(user_id::text)) = lower(trim(auth.uid()::text))
        or exists (
            select 1
            from public.community_posts cp
            where cp.car_id is not null
              and cp.car_id::text = cars.id::text
        )
    )
);

drop policy if exists "cars_insert_own" on public.cars;
create policy "cars_insert_own"
on public.cars
for insert
to authenticated
with check (
    auth.uid() is not null
    and lower(trim(user_id::text)) = lower(trim(auth.uid()::text))
);

drop policy if exists "cars_update_own" on public.cars;
create policy "cars_update_own"
on public.cars
for update
to authenticated
using (
    auth.uid() is not null
    and lower(trim(user_id::text)) = lower(trim(auth.uid()::text))
)
with check (
    auth.uid() is not null
    and lower(trim(user_id::text)) = lower(trim(auth.uid()::text))
);

drop policy if exists "cars_delete_own" on public.cars;
create policy "cars_delete_own"
on public.cars
for delete
to authenticated
using (
    auth.uid() is not null
    and lower(trim(user_id::text)) = lower(trim(auth.uid()::text))
);

drop policy if exists "spec_items_select_own_or_public_community" on public.spec_items;
create policy "spec_items_select_own_or_public_community"
on public.spec_items
for select
to authenticated
using (
    auth.uid() is not null
    and exists (
        select 1
        from public.cars c
        where c.id::text = spec_items.car_id::text
          and (
              lower(trim(c.user_id::text)) = lower(trim(auth.uid()::text))
              or exists (
                  select 1
                  from public.community_posts cp
                  where cp.car_id is not null
                    and cp.car_id::text = c.id::text
              )
          )
    )
);

drop policy if exists "spec_items_insert_own" on public.spec_items;
create policy "spec_items_insert_own"
on public.spec_items
for insert
to authenticated
with check (
    auth.uid() is not null
    and exists (
        select 1
        from public.cars c
        where c.id::text = spec_items.car_id::text
          and lower(trim(c.user_id::text)) = lower(trim(auth.uid()::text))
    )
);

drop policy if exists "spec_items_update_own" on public.spec_items;
create policy "spec_items_update_own"
on public.spec_items
for update
to authenticated
using (
    auth.uid() is not null
    and exists (
        select 1
        from public.cars c
        where c.id::text = spec_items.car_id::text
          and lower(trim(c.user_id::text)) = lower(trim(auth.uid()::text))
    )
)
with check (
    auth.uid() is not null
    and exists (
        select 1
        from public.cars c
        where c.id::text = spec_items.car_id::text
          and lower(trim(c.user_id::text)) = lower(trim(auth.uid()::text))
    )
);

drop policy if exists "spec_items_delete_own" on public.spec_items;
create policy "spec_items_delete_own"
on public.spec_items
for delete
to authenticated
using (
    auth.uid() is not null
    and exists (
        select 1
        from public.cars c
        where c.id::text = spec_items.car_id::text
          and lower(trim(c.user_id::text)) = lower(trim(auth.uid()::text))
    )
);

drop policy if exists "mod_items_select_own_or_public_community" on public.mod_items;
create policy "mod_items_select_own_or_public_community"
on public.mod_items
for select
to authenticated
using (
    auth.uid() is not null
    and exists (
        select 1
        from public.cars c
        where c.id::text = mod_items.car_id::text
          and (
              lower(trim(c.user_id::text)) = lower(trim(auth.uid()::text))
              or exists (
                  select 1
                  from public.community_posts cp
                  where cp.car_id is not null
                    and cp.car_id::text = c.id::text
              )
          )
    )
);

drop policy if exists "mod_items_insert_own" on public.mod_items;
create policy "mod_items_insert_own"
on public.mod_items
for insert
to authenticated
with check (
    auth.uid() is not null
    and exists (
        select 1
        from public.cars c
        where c.id::text = mod_items.car_id::text
          and lower(trim(c.user_id::text)) = lower(trim(auth.uid()::text))
    )
);

drop policy if exists "mod_items_update_own" on public.mod_items;
create policy "mod_items_update_own"
on public.mod_items
for update
to authenticated
using (
    auth.uid() is not null
    and exists (
        select 1
        from public.cars c
        where c.id::text = mod_items.car_id::text
          and lower(trim(c.user_id::text)) = lower(trim(auth.uid()::text))
    )
)
with check (
    auth.uid() is not null
    and exists (
        select 1
        from public.cars c
        where c.id::text = mod_items.car_id::text
          and lower(trim(c.user_id::text)) = lower(trim(auth.uid()::text))
    )
);

drop policy if exists "mod_items_delete_own" on public.mod_items;
create policy "mod_items_delete_own"
on public.mod_items
for delete
to authenticated
using (
    auth.uid() is not null
    and exists (
        select 1
        from public.cars c
        where c.id::text = mod_items.car_id::text
          and lower(trim(c.user_id::text)) = lower(trim(auth.uid()::text))
    )
);
