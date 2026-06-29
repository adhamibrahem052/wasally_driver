-- ============================================
-- وصلى (Wasally) - قاعدة البيانات الكاملة
-- ============================================

-- 0. HELPER FUNCTION (تجنب recursion في RLS)
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- 1. PROFILES
create table if not exists public.profiles (
  id uuid references auth.users not null primary key,
  full_name text,
  phone_number text,
  role text not null default 'customer' check (role in ('customer','driver','store','admin')),
  avatar_url text,
  wallet_balance decimal default 0,
  is_active boolean default true,
  fcm_token text,
  address text,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- 2. STORES
create table if not exists public.stores (
  id uuid default gen_random_uuid() primary key,
  owner_id uuid references public.profiles(id) not null,
  name text not null,
  description text,
  logo_url text,
  cover_url text,
  phone text,
  address text,
  lat double precision,
  lng double precision,
  is_active boolean default true,
  delivery_available boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 3. CATEGORIES
create table if not exists public.categories (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  icon text,
  image_url text,
  sort_order int default 0,
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 4. PRODUCTS
create table if not exists public.products (
  id uuid default gen_random_uuid() primary key,
  store_id uuid references public.stores(id) on delete cascade,
  category_id uuid references public.categories(id),
  name text not null,
  description text,
  price decimal not null,
  compare_price decimal,
  images text[],
  unit text default 'قطعة',
  stock int default 0,
  is_available boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 5. ORDERS
create table if not exists public.orders (
  id uuid default gen_random_uuid() primary key,
  customer_id uuid references public.profiles(id) not null,
  driver_id uuid references public.profiles(id),
  store_id uuid references public.stores(id),
  order_type text not null default 'manual' check (order_type in ('manual','store')),
  order_details text,
  status text not null default 'pending' check (status in (
    'pending','driver_assigned','store_confirmed',
    'preparing','on_the_way','delivered','cancelled','rejected'
  )),
  notes text,
  total_price decimal default 0,
  delivery_fee decimal default 0,
  final_total decimal default 0,
  payment_method text default 'cash' check (payment_method in (
    'cash','vodafone_cash','orange_cash','etisalat_cash',
    'we_cash','instapay','wallet'
  )),
  payment_status text default 'pending' check (payment_status in ('pending','paid','failed','refunded')),
  delivery_address text,
  delivery_lat double precision,
  delivery_lng double precision,
  qr_code_verified boolean default false,
  rating int check (rating between 1 and 5),
  rating_comment text,
  cancelled_reason text,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- 6. ORDER ITEMS
create table if not exists public.order_items (
  id uuid default gen_random_uuid() primary key,
  order_id uuid references public.orders(id) on delete cascade not null,
  product_id uuid references public.products(id),
  name text not null,
  quantity int not null default 1,
  unit_price decimal not null,
  total_price decimal not null,
  notes text
);

-- 7. INVOICES
create table if not exists public.invoices (
  id uuid default gen_random_uuid() primary key,
  order_id uuid references public.orders(id) on delete cascade not null,
  driver_id uuid references public.profiles(id) not null,
  customer_id uuid references public.profiles(id) not null,
  store_id uuid references public.stores(id),
  status text not null default 'pending' check (status in (
    'pending','store_accepted','store_rejected',
    'modified','customer_confirmed','paid'
  )),
  total_amount decimal not null default 0,
  delivery_fee decimal default 0,
  grand_total decimal not null default 0,
  payment_method text default 'cash',
  store_notes text,
  driver_notes text,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- 8. INVOICE ITEMS
create table if not exists public.invoice_items (
  id uuid default gen_random_uuid() primary key,
  invoice_id uuid references public.invoices(id) on delete cascade not null,
  product_id uuid references public.products(id),
  name text not null,
  quantity int not null default 1,
  unit_price decimal not null,
  total_price decimal not null,
  is_available boolean default true,
  substitute_notes text
);

-- 9. INVOICE STORE RESPONSES
create table if not exists public.invoice_store_responses (
  id uuid default gen_random_uuid() primary key,
  invoice_id uuid references public.invoices(id) on delete cascade not null,
  store_id uuid references public.stores(id) not null,
  response text not null check (response in ('accepted','rejected','modified')),
  notes text,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 10. ORDER ITEM REVIEWS
create table if not exists public.order_item_reviews (
  id uuid default gen_random_uuid() primary key,
  order_id uuid references public.orders(id) on delete cascade not null,
  item_name text not null,
  item_quantity int not null default 1,
  item_price decimal not null default 0,
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  rejection_reason text,
  reviewed_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 11. PAYMENTS
create table if not exists public.payments (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) not null,
  order_id uuid references public.orders(id),
  amount decimal not null,
  payment_method text not null,
  status text not null default 'pending' check (status in ('pending','completed','failed','refunded')),
  transaction_ref text,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 12. PAYMENT METHODS
create table if not exists public.payment_methods (
  id uuid default gen_random_uuid() primary key,
  type text not null,
  name text not null,
  details text,
  account_number text,
  account_id text,
  is_active boolean default true,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 13. WALLET TRANSACTIONS
create table if not exists public.wallet_transactions (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) not null,
  type text not null check (type in ('deposit','withdrawal','payment','refund','earning')),
  amount decimal not null,
  balance_before decimal not null,
  balance_after decimal not null,
  reference_id text,
  description text,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 14. NOTIFICATIONS
create table if not exists public.notifications (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) not null,
  title text not null,
  body text not null,
  type text not null default 'general' check (type in (
    'general','order','invoice','payment',
    'promotion','complaint_reply','message'
  )),
  reference_id text,
  is_read boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 15. MESSAGES
create table if not exists public.messages (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id) not null,
  receiver_id uuid references public.profiles(id) not null,
  order_id uuid references public.orders(id),
  message text not null,
  is_read boolean default false,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 16. COMPLAINTS
create table if not exists public.complaints (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) not null,
  type text not null check (type in ('complaint','suggestion','inquiry')),
  title text not null,
  description text not null,
  status text not null default 'pending' check (status in ('pending','reviewed','resolved','rejected')),
  admin_reply text,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- 17. RATINGS
create table if not exists public.ratings (
  id uuid default gen_random_uuid() primary key,
  order_id uuid references public.orders(id) on delete cascade not null,
  user_id uuid references public.profiles(id) not null,
  driver_rating int check (driver_rating between 1 and 5),
  app_rating int check (app_rating between 1 and 5),
  delivery_rating int check (delivery_rating between 1 and 5),
  comment text,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 18. QR CODES
create table if not exists public.qr_codes (
  id uuid default gen_random_uuid() primary key,
  order_id uuid references public.orders(id) on delete cascade not null,
  code text not null unique,
  is_scanned boolean default false,
  scanned_at timestamp with time zone,
  created_at timestamp with time zone default timezone('utc'::text, now())
);

-- 19. DRIVER LOCATIONS
create table if not exists public.driver_locations (
  id uuid default gen_random_uuid() primary key,
  driver_id uuid references public.profiles(id) not null,
  order_id uuid references public.orders(id),
  lat double precision not null,
  lng double precision not null,
  heading double precision,
  speed double precision,
  is_active boolean default true,
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

-- ============================================
-- RLS POLICIES
-- ============================================

-- PROFILES
alter table public.profiles enable row level security;
create policy "Users view own profile" on public.profiles for select using (auth.uid() = id);
drop policy if exists "Admin view all profiles" on public.profiles;
create policy "Admin view all profiles" on public.profiles for select using (public.is_admin());
create policy "Users update own profile" on public.profiles for update using (auth.uid() = id);

-- STORES
alter table public.stores enable row level security;
create policy "Anyone view stores" on public.stores for select using (true);
create policy "Store owner manage store" on public.stores for all using (auth.uid() = owner_id);
drop policy if exists "Admin manage stores" on public.stores;
create policy "Admin manage stores" on public.stores for all using (public.is_admin());

-- PRODUCTS
alter table public.products enable row level security;
create policy "Anyone view products" on public.products for select using (true);
create policy "Store owner manage products" on public.products for all using (
  exists (select 1 from public.stores where id = products.store_id and owner_id = auth.uid())
);
drop policy if exists "Admin manage products" on public.products;
create policy "Admin manage products" on public.products for all using (public.is_admin());

-- ORDERS
alter table public.orders enable row level security;
create policy "Customer view own orders" on public.orders for select using (auth.uid() = customer_id);
create policy "Driver view assigned orders" on public.orders for select using (auth.uid() = driver_id or driver_id is null);
create policy "Store view related orders" on public.orders for select using (
  exists (select 1 from public.stores where id = orders.store_id and owner_id = auth.uid())
);
drop policy if exists "Admin view all orders" on public.orders;
drop policy if exists "Admin update all orders" on public.orders;
create policy "Admin view all orders" on public.orders for select using (public.is_admin());
create policy "Admin update all orders" on public.orders for update using (public.is_admin());
create policy "Customer insert orders" on public.orders for insert with check (auth.uid() = customer_id);
create policy "Driver update assigned orders" on public.orders for update using (auth.uid() = driver_id);

-- INVOICES
alter table public.invoices enable row level security;
create policy "Driver manage invoices" on public.invoices for all using (auth.uid() = driver_id);
create policy "Customer view invoices" on public.invoices for select using (auth.uid() = customer_id);
create policy "Store view invoices" on public.invoices for select using (
  exists (select 1 from public.stores where id = invoices.store_id and owner_id = auth.uid())
);
drop policy if exists "Admin view all invoices" on public.invoices;
create policy "Admin view all invoices" on public.invoices for select using (public.is_admin());

-- NOTIFICATIONS
alter table public.notifications enable row level security;
create policy "Users view own notifications" on public.notifications for select using (auth.uid() = user_id);
drop policy if exists "Admin insert notifications" on public.notifications;
create policy "Admin insert notifications" on public.notifications for insert with check (public.is_admin());

-- MESSAGES
alter table public.messages enable row level security;
create policy "Users view own messages" on public.messages for select using (auth.uid() = sender_id or auth.uid() = receiver_id);
create policy "Users send messages" on public.messages for insert with check (auth.uid() = sender_id);

-- COMPLAINTS
alter table public.complaints enable row level security;
create policy "Users view own complaints" on public.complaints for select using (auth.uid() = user_id);
create policy "Users insert complaints" on public.complaints for insert with check (auth.uid() = user_id);
drop policy if exists "Admin view all complaints" on public.complaints;
drop policy if exists "Admin update complaints" on public.complaints;
create policy "Admin view all complaints" on public.complaints for select using (public.is_admin());
create policy "Admin update complaints" on public.complaints for update using (public.is_admin());

-- RATINGS
alter table public.ratings enable row level security;
create policy "Users insert ratings" on public.ratings for insert with check (auth.uid() = user_id);
create policy "Users view ratings" on public.ratings for select using (true);

-- QR CODES
alter table public.qr_codes enable row level security;
create policy "Driver view qr codes" on public.qr_codes for select using (
  auth.uid() in (select driver_id from public.orders where id = qr_codes.order_id)
);
create policy "Customer scan qr codes" on public.qr_codes for update using (
  auth.uid() in (select customer_id from public.orders where id = qr_codes.order_id)
);

-- DRIVER LOCATIONS
alter table public.driver_locations enable row level security;
create policy "Driver insert location" on public.driver_locations for insert with check (auth.uid() = driver_id);
create policy "Driver update own location" on public.driver_locations for update using (auth.uid() = driver_id);
drop policy if exists "Admin view driver locations" on public.driver_locations;
create policy "Admin view driver locations" on public.driver_locations for select using (public.is_admin());
create policy "Customer view driver location" on public.driver_locations for select using (
  auth.uid() in (select customer_id from public.orders where id = driver_locations.order_id)
);

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Auto create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, role)
  values (new.id, new.raw_user_meta_data->>'full_name', coalesce(new.raw_user_meta_data->>'role', 'customer'));
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- Update updated_at timestamp
create or replace function public.update_updated_at()
returns trigger as $$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$$ language plpgsql;

create trigger update_profiles_updated_at
  before update on public.profiles
  for each row execute function public.update_updated_at();

create trigger update_orders_updated_at
  before update on public.orders
  for each row execute function public.update_updated_at();

-- Generate QR code on order confirmation
create or replace function public.generate_order_qr()
returns trigger as $$
begin
  if new.status = 'on_the_way' then
    insert into public.qr_codes (order_id, code)
    values (new.id, encode(gen_random_bytes(16), 'hex'));
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_order_on_the_way
  after update on public.orders
  for each row
  when (new.status = 'on_the_way')
  execute function public.generate_order_qr();

-- ============================================
-- SEED DATA (بيانات افتراضية)
-- ============================================

insert into public.payment_methods (type, name, details, account_number, is_active)
values
  ('vodafone_cash', 'فودافون كاش', 'تحويل عبر فودافون كاش', '01000000000', true),
  ('orange_cash', 'أورانج كاش', 'تحويل عبر أورانج كاش', '01200000000', true),
  ('etisalat_cash', 'اتصالات كاش', 'تحويل عبر اتصالات كاش', '01100000000', true),
  ('we_cash', 'وي كاش', 'تحويل عبر وي كاش', '01500000000', true),
  ('instapay', 'إنستاباي', 'تحويل عبر إنستاباي', null, true),
  ('bank_card', 'تحويل بنكي', 'بنك مصر - حساب وصلى', '123456789', true)
on conflict do nothing;

-- ============================================
-- INDEXES
-- ============================================
create index if not exists idx_orders_customer on public.orders(customer_id);
create index if not exists idx_orders_driver on public.orders(driver_id);
create index if not exists idx_orders_status on public.orders(status);
create index if not exists idx_products_store on public.products(store_id);
create index if not exists idx_products_category on public.products(category_id);
create index if not exists idx_notifications_user on public.notifications(user_id);
create index if not exists idx_messages_participants on public.messages(sender_id, receiver_id);
create index if not exists idx_driver_locations_driver on public.driver_locations(driver_id);
create index if not exists idx_driver_locations_active on public.driver_locations(is_active);

-- ============================================
-- 20. RECHARGE REQUESTS (طلبات شحن المحفظة)
-- ============================================
create table if not exists public.recharge_requests (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) not null,
  amount decimal not null,
  payment_method text not null,
  screenshot_url text,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  admin_notes text,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

alter table public.recharge_requests enable row level security;
create policy "Users view own requests" on public.recharge_requests for select using (auth.uid() = user_id);
create policy "Users insert requests" on public.recharge_requests for insert with check (auth.uid() = user_id);
create policy "Admin manage requests" on public.recharge_requests for all using (public.is_admin());

-- IMPORTANT: Create a storage bucket called "recharge_screenshots" from Supabase Dashboard
-- (Settings → Storage → Create bucket) or via SQL:
-- insert into storage.buckets (id, name, public) values ('recharge_screenshots', 'recharge_screenshots', true);
-- Then add policy: create policy "Users upload screenshots" on storage.objects for insert with check (bucket_id = 'recharge_screenshots' and auth.role() = 'authenticated');

-- ============================================
-- 21. DRIVER COLLECTIONS (تحصيل وتوريد السائقين)
-- ============================================
create table if not exists public.driver_collections (
  id uuid default gen_random_uuid() primary key,
  driver_id uuid references public.profiles(id) not null,
  type text not null check (type in ('supply', 'collection')),
  amount decimal not null,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  admin_notes text,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

alter table public.driver_collections enable row level security;
create policy "Driver view own collections" on public.driver_collections for select using (auth.uid() = driver_id);
create policy "Driver insert collections" on public.driver_collections for insert with check (auth.uid() = driver_id);
drop policy if exists "Admin manage collections" on public.driver_collections;
create policy "Admin manage collections" on public.driver_collections for all using (public.is_admin());

-- ============================================
-- 22. DRIVER STORE TRANSACTIONS (معاملات السائق مع المتاجر)
-- ============================================
create table if not exists public.driver_store_invoices (
  id uuid default gen_random_uuid() primary key,
  driver_id uuid references public.profiles(id) not null,
  store_id uuid references public.stores(id) not null,
  order_id uuid references public.orders(id),
  total_amount decimal not null,
  payment_method text not null default 'cash' check (payment_method in ('cash', 'instapay', 'wallet', 'bank')),
  status text not null default 'pending' check (status in ('pending', 'store_confirmed', 'prepared', 'paid', 'cancelled')),
  driver_notes text,
  store_notes text,
  created_at timestamp with time zone default timezone('utc'::text, now()),
  updated_at timestamp with time zone default timezone('utc'::text, now())
);

alter table public.driver_store_invoices enable row level security;
create policy "Driver manage store invoices" on public.driver_store_invoices for all using (auth.uid() = driver_id);
create policy "Store view invoices" on public.driver_store_invoices for select using (
  exists (select 1 from public.stores where id = driver_store_invoices.store_id and owner_id = auth.uid())
);
