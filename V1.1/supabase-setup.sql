create or replace function public.is_richers_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles
    where id = (select auth.uid())
      and role = 'admin'
  );
$$;

create or replace function public.create_richers_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.email,
    nullif(new.raw_user_meta_data ->> 'phone', ''),
    'customer'
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_richers_profile on auth.users;
create trigger on_auth_user_created_richers_profile
after insert on auth.users
for each row execute function public.create_richers_profile();

alter table public.profiles
  add column if not exists is_verified boolean not null default false,
  add column if not exists email text;

update public.profiles p
set email = u.email
from auth.users u
where p.id = u.id and p.email is null;

insert into public.profiles (id, full_name, email, phone, role)
select
  u.id,
  coalesce(u.raw_user_meta_data ->> 'full_name', ''),
  u.email,
  nullif(u.raw_user_meta_data ->> 'phone', ''),
  'customer'
from auth.users u
on conflict (id) do nothing;

alter table public.orders
  add column if not exists service_type text,
  add column if not exists service text,
  add column if not exists paper text,
  add column if not exists color text,
  add column if not exists binding text,
  add column if not exists copies integer not null default 1 check (copies > 0),
  add column if not exists item_quantity integer not null default 1 check (item_quantity > 0),
  add column if not exists pickup_date text,
  add column if not exists file_name text,
  add column if not exists file_path text,
  add column if not exists pricing_note text;

alter table public.order_items
  add column if not exists description text;

alter table public.inventory
  add column if not exists code text,
  add column if not exists description text,
  add column if not exists category text;

update public.inventory
set description = coalesce(description, item_name),
    unit = coalesce(unit, 'Units'),
    code = coalesce(code, 'INV-' || id::text),
    category = coalesce(category, 'General')
where description is null or code is null or category is null;

alter table public.inventory
  alter column description set not null,
  alter column code set not null,
  alter column category set not null;

create unique index if not exists inventory_code_unique on public.inventory (code);

drop policy if exists "Anyone can read active services" on public.services;
drop policy if exists "Public can read active services" on public.services;
create policy "Public can read active services"
on public.services for select to anon, authenticated
using (active = true or public.is_richers_admin());

drop policy if exists "Admins manage services" on public.services;
create policy "Admins manage services"
on public.services for all to authenticated
using (public.is_richers_admin())
with check (public.is_richers_admin());

drop policy if exists "Users read own profile or admins read all" on public.profiles;
create policy "Users read own profile or admins read all"
on public.profiles for select to authenticated
using (id = (select auth.uid()) or public.is_richers_admin());

drop policy if exists "Admins update profiles" on public.profiles;
create policy "Admins update profiles"
on public.profiles for update to authenticated
using (public.is_richers_admin())
with check (public.is_richers_admin());

drop policy if exists "Customers read own orders or admins read all" on public.orders;
create policy "Customers read own orders or admins read all"
on public.orders for select to authenticated
using (customer_id = (select auth.uid()) or public.is_richers_admin());

drop policy if exists "Customers create own orders" on public.orders;
create policy "Customers create own orders"
on public.orders for insert to authenticated
with check (
  customer_id = (select auth.uid())
  and status = 'Received'
  and payment_status = 'Unpaid'
);

drop policy if exists "Admins update orders" on public.orders;
create policy "Admins update orders"
on public.orders for update to authenticated
using (public.is_richers_admin())
with check (public.is_richers_admin());

drop policy if exists "Customers read own order items or admins read all" on public.order_items;
create policy "Customers read own order items or admins read all"
on public.order_items for select to authenticated
using (
  public.is_richers_admin()
  or exists (
    select 1 from public.orders
    where orders.id = order_items.order_id
      and orders.customer_id = (select auth.uid())
  )
);

drop policy if exists "Customers create own order items" on public.order_items;
create policy "Customers create own order items"
on public.order_items for insert to authenticated
with check (
  exists (
    select 1 from public.orders
    where orders.id = order_items.order_id
      and orders.customer_id = (select auth.uid())
  )
);

drop policy if exists "Admins update order items" on public.order_items;
create policy "Admins update order items"
on public.order_items for update to authenticated
using (public.is_richers_admin())
with check (public.is_richers_admin());

drop policy if exists "Admins manage inventory" on public.inventory;
create policy "Admins manage inventory"
on public.inventory for all to authenticated
using (public.is_richers_admin())
with check (public.is_richers_admin());

drop policy if exists "Customers read own payments or admins read all" on public.payments;
create policy "Customers read own payments or admins read all"
on public.payments for select to authenticated
using (
  public.is_richers_admin()
  or exists (
    select 1 from public.orders
    where orders.id = payments.order_id
      and orders.customer_id = (select auth.uid())
  )
);

drop policy if exists "Admins record payments" on public.payments;
create policy "Admins record payments"
on public.payments for insert to authenticated
with check (public.is_richers_admin());

insert into storage.buckets (id, name, public)
values ('order-files', 'order-files', false)
on conflict (id) do update set public = false;

drop policy if exists "Customers upload own order files" on storage.objects;
create policy "Customers upload own order files"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'order-files'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "Customers read own order files or admins read all" on storage.objects;
create policy "Customers read own order files or admins read all"
on storage.objects for select to authenticated
using (
  bucket_id = 'order-files'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_richers_admin()
  )
);

drop policy if exists "Customers delete own order files or admins delete all" on storage.objects;
create policy "Customers delete own order files or admins delete all"
on storage.objects for delete to authenticated
using (
  bucket_id = 'order-files'
  and (
    (storage.foldername(name))[1] = (select auth.uid())::text
    or public.is_richers_admin()
  )
);

create or replace function public.record_cash_payment(target_order_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  order_total numeric(10, 2);
begin
  if not public.is_richers_admin() then
    raise exception 'Only admins may record payments';
  end if;

  select total into order_total
  from public.orders
  where id = target_order_id
  for update;

  if not found then
    raise exception 'Order was not found';
  end if;

  if exists (select 1 from public.payments where order_id = target_order_id) then
    raise exception 'A payment is already recorded for this order';
  end if;

  insert into public.payments (order_id, amount, method, recorded_by)
  values (target_order_id, order_total, 'Cash on pickup', auth.uid());

  update public.orders
  set payment_status = 'Paid'
  where id = target_order_id;
end;
$$;

grant execute on function public.is_richers_admin() to anon, authenticated;
revoke all on function public.record_cash_payment(bigint) from public, anon;
grant execute on function public.record_cash_payment(bigint) to authenticated;
