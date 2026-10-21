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
  add column if not exists pricing_note text,
  add column if not exists customer_edited_at timestamptz,
  add column if not exists customer_edit_pending boolean not null default false;

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

create or replace function public.inventory_code_for_order_item(p_description text)
returns text
language sql
immutable
set search_path = pg_catalog
as $$
  select case
    when lower(btrim(split_part(coalesce(p_description, ''), ' — Specifications:', 1)))
      like 'legal / long document printing (%full color%' then 'LEGAL-COLOR'
    when lower(btrim(split_part(coalesce(p_description, ''), ' — Specifications:', 1)))
      like 'legal / long document printing (%black & white%' then 'LEGAL-BW'
    else case lower(btrim(split_part(coalesce(p_description, ''), ' — Specifications:', 1)))
      when 'photo printing - 4r' then 'PHOTO-4R'
      when 'photo printing - 5r' then 'PHOTO-5R'
      when 'photo printing - a4' then 'PHOTO-A4'
      when 'poster printing - a2' then 'POSTER-A2'
      when 'poster printing - a1' then 'POSTER-A1'
      when 'business cards (100 pcs)' then 'BUS-CARD-100'
      when 'flyers & leaflets (a5)' then 'FLYER-A5'
      when 'brochure (tri-fold)' then 'BROCHURE-TRI'
      when 'certificate printing' then 'CERTIFICATE'
      when 'invitation printing' then 'INVITATION'
      when 'legal / long document - color' then 'LEGAL-COLOR'
      when 'legal / long document - black & white' then 'LEGAL-BW'
      when 'sticker & label printing - a3' then 'STICKER-A3'
      when 'standard 3×5 ft tarpaulin' then 'TARPAULIN-3X5'
      when 'tarpaulin - 3x5 ft' then 'TARPAULIN-3X5'
      when 'tarpaulin - 2x3 ft' then 'TARPAULIN-2X3'
      when 'tarpaulin - 4x6 ft' then 'TARPAULIN-4X6'
      when 'tarpaulin - 5x8 ft' then 'TARPAULIN-5X8'
      when 'standee (with stand)' then 'STANDEE'
      when 'ring binding w/ clear front cover' then 'BND-RNG-12'
      when 'spiral binding' then 'SPIRAL-BIND'
      when 'soft-cover perfect binding' then 'PERFECT-BIND'
      when 'hard-cover binding (thesis)' then 'HARDCOVER-BIND'
      when 'lamination - short' then 'LAMINATION-S'
      when 'lamination - long' then 'LAMINATION-L'
      when 'folding' then 'FOLDING'
      when 'cutting / trimming' then 'CUT-TRIM'
      when 'office forms (custom)' then 'OFFICE-FORMS'
      when 'books / manuals (custom)' then 'BOOK-MANUAL'
      when 'notepads / notebooks' then 'NOTEPADS'
      when 'custom printed boxes' then 'PRINTED-BOX'
      when 'banner printing' then 'BANNER'
      when 'custom sintra board printing' then 'SINTRA-BOARD'
      else null
    end
  end;
$$;

create or replace function public.adjust_inventory_for_order_item()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  item_description text;
  quantity_change integer;
  inventory_code text;
begin
  if tg_op = 'DELETE' then
    item_description := old.description;
    quantity_change := old.quantity;
  else
    item_description := new.description;
    quantity_change := -new.quantity;
  end if;

  inventory_code := public.inventory_code_for_order_item(item_description);
  if inventory_code is not null then
    update public.inventory
    set quantity = quantity + quantity_change,
        updated_at = now()
    where code = inventory_code;
  end if;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists adjust_inventory_for_order_item on public.order_items;
create trigger adjust_inventory_for_order_item
after insert or delete on public.order_items
for each row execute function public.adjust_inventory_for_order_item();
alter table public.order_items enable trigger adjust_inventory_for_order_item;

create or replace function public.restore_cancelled_order_inventory()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.status = 'Cancelled' and old.status is distinct from new.status then
    update public.inventory inventory
    set quantity = inventory.quantity + order_items.quantity,
        updated_at = now()
    from (
      select public.inventory_code_for_order_item(description) as code,
             sum(quantity) as quantity
      from public.order_items
      where order_id = new.id
      group by 1
    ) order_items
    where order_items.code is not null
      and inventory.code = order_items.code;
  end if;
  return new;
end;
$$;

drop trigger if exists restore_cancelled_order_inventory on public.orders;
create trigger restore_cancelled_order_inventory
after update of status on public.orders
for each row execute function public.restore_cancelled_order_inventory();
alter table public.orders enable trigger restore_cancelled_order_inventory;

insert into public.services (name, description, category, unit, unit_price, active)
select new_service.name, new_service.description, new_service.category, new_service.unit,
       new_service.unit_price, true
from (values
  ('Photo Printing - 4R', '4R photo printing', 'Photo Printing', 'photo', 15.00),
  ('Photo Printing - 5R', '5R photo printing', 'Photo Printing', 'photo', 25.00),
  ('Photo Printing - A4', 'A4 photo printing', 'Photo Printing', 'photo', 40.00),
  ('Poster Print - A2', 'A2 poster printing', 'Poster Printing', 'piece', 180.00),
  ('Poster Print - A1', 'A1 poster printing', 'Poster Printing', 'piece', 300.00),
  ('Business Cards', 'Business cards, 100 pieces per box', 'Business Printing', 'box', 350.00),
  ('Flyers - A5', 'A5 flyers and leaflets', 'Business Printing', 'piece', 4.00),
  ('Brochure - Tri-fold', 'Tri-fold brochure printing', 'Business Printing', 'piece', 12.00),
  ('Certificate', 'Certificate printing', 'Document Printing', 'piece', 25.00),
  ('Invitation', 'Invitation printing', 'Document Printing', 'piece', 20.00),
  ('Document Printing - Legal - Full Color', 'Legal or long document printing, full color', 'Document Printing', 'page', 6.00),
  ('Document Printing - Legal - Black & White', 'Legal or long document printing, black and white', 'Document Printing', 'page', 3.00),
  ('Large-Format Tarpaulin - 2x3 ft', '2x3 ft tarpaulin printing', 'Large Format Printing', 'piece', 90.00),
  ('Large-Format Tarpaulin - 4x6 ft', '4x6 ft tarpaulin printing', 'Large Format Printing', 'piece', 400.00),
  ('Large-Format Tarpaulin - 5x8 ft', '5x8 ft tarpaulin printing', 'Large Format Printing', 'piece', 700.00),
  ('Standee (with stand)', 'Standee printing with stand', 'Large Format Printing', 'piece', 650.00),
  ('Spiral Binding', 'Spiral binding per copy', 'Binding and Finishing', 'copy', 35.00),
  ('Perfect Binding', 'Soft-cover perfect binding per copy', 'Binding and Finishing', 'copy', 120.00),
  ('Hard-Cover Binding', 'Hard-cover thesis binding per copy', 'Binding and Finishing', 'copy', 350.00),
  ('Lamination - Short', 'Short-size lamination', 'Binding and Finishing', 'piece', 15.00),
  ('Lamination - Long', 'Long-size lamination', 'Binding and Finishing', 'piece', 20.00),
  ('Folding', 'Folding per sheet', 'Binding and Finishing', 'sheet', 0.50),
  ('Cutting / Trimming', 'Cutting and trimming per copy', 'Binding and Finishing', 'copy', 30.00),
  ('Office Forms (Custom)', 'Custom office forms; quote required', 'Office Printing', 'set', 0.00),
  ('Books / Manuals (Custom)', 'Custom books or manuals; quote required', 'Book Printing', 'book', 0.00),
  ('Notepads / Notebooks', 'Custom notepads or notebooks; quote required', 'Book Printing', 'pad', 0.00),
  ('Custom Printed Boxes', 'Custom printed packaging boxes; quote required', 'Packaging', 'box', 0.00),
  ('Banner Printing', 'Custom banner printing; quote required', 'Large Format Printing', 'piece', 0.00),
  ('Sintra Board Printing', 'Custom Sintra board printing; quote required', 'Signage', 'board', 0.00)
) as new_service(name, description, category, unit, unit_price)
where not exists (
  select 1 from public.services existing where existing.name = new_service.name
);

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

drop function if exists public.customer_edit_order(bigint, text, text, text, text, text, integer, integer, text, numeric, jsonb, text, text, text);
drop function if exists public.customer_edit_order(bigint, text, text, text, text, text, integer, integer, text, numeric, jsonb, text, text);

create or replace function public.customer_edit_order(
  p_order_id bigint,
  p_service_type text,
  p_service text,
  p_paper text,
  p_color text,
  p_binding text,
  p_copies integer,
  p_item_quantity integer,
  p_pickup_date text,
  p_total numeric,
  p_items jsonb,
  p_additional_details text,
  p_file_name text,
  p_file_path text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
declare
  target_order public.orders%rowtype;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to edit an order';
  end if;

  select * into target_order
  from public.orders
  where id = p_order_id
  for update;

  if not found or target_order.customer_id <> auth.uid() then
    raise exception 'Order not found';
  end if;

  if target_order.status <> 'Received' or target_order.payment_status <> 'Unpaid' then
    raise exception 'Only unpaid orders that have not started processing can be edited';
  end if;

  if p_copies < 1 or p_item_quantity < 1 or p_total < 0 or
     jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Order details are incomplete or invalid';
  end if;

  if p_file_path is not null and p_file_path not like auth.uid()::text || '/%' then
    raise exception 'Replacement file must belong to the signed-in customer';
  end if;

  update public.orders
  set service_type = p_service_type,
      service = p_service,
      paper = p_paper,
      color = p_color,
      binding = p_binding,
      copies = p_copies,
      item_quantity = p_item_quantity,
      pickup_date = p_pickup_date,
      file_name = coalesce(p_file_name, file_name),
      file_path = coalesce(p_file_path, file_path),
      total = p_total,
      pricing_note = case
        when nullif(btrim(p_additional_details), '') is not null then
          'Custom product; awaiting shop quote. Specifications: ' || btrim(p_additional_details)
        else 'Customer edited estimate; confirm final price with the shop.'
      end,
      customer_edited_at = now(),
      customer_edit_pending = true
  where id = p_order_id;

  delete from public.order_items where order_id = p_order_id;

  insert into public.order_items (order_id, service_id, service_name, description, quantity, unit_price)
  select p_order_id, item.service_id, item.service_name, item.description, item.quantity, item.unit_price
  from jsonb_populate_recordset(null::public.order_items, p_items) as item;
end;
$$;

revoke all on function public.customer_edit_order(bigint, text, text, text, text, text, integer, integer, text, numeric, jsonb, text, text, text) from public;
grant execute on function public.customer_edit_order(bigint, text, text, text, text, text, integer, integer, text, numeric, jsonb, text, text, text) to authenticated;

create or replace function public.customer_cancel_order(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth, pg_temp
as $$
declare
  target_order public.orders%rowtype;
begin
  if auth.uid() is null then
    raise exception 'You must be signed in to cancel an order';
  end if;

  select * into target_order
  from public.orders
  where id = p_order_id
  for update;

  if not found or target_order.customer_id <> auth.uid() then
    raise exception 'Order not found';
  end if;

  if target_order.status <> 'Received' or target_order.payment_status <> 'Unpaid' then
    raise exception 'Only unpaid orders that have not started processing can be cancelled';
  end if;

  update public.orders
  set status = 'Cancelled',
      pricing_note = concat_ws(' ', nullif(btrim(pricing_note), ''), 'Customer cancelled this order.')
  where id = p_order_id;
end;
$$;

revoke all on function public.customer_cancel_order(bigint) from public;
grant execute on function public.customer_cancel_order(bigint) to authenticated;

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

insert into storage.buckets (id, name, public, allowed_mime_types, file_size_limit)
values (
  'order-files',
  'order-files',
  false,
  array[
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'image/png',
    'image/jpeg'
  ],
  52428800
)
on conflict (id) do update
set public = false,
    allowed_mime_types = excluded.allowed_mime_types,
    file_size_limit = excluded.file_size_limit;

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

notify pgrst, 'reload schema';
