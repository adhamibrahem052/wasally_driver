-- ============================================================
-- Create Tables + RLS Policies for Wasally Driver App
-- Run this in Supabase SQL Editor (ALL at once)
-- ============================================================

-- ============================================================
-- CREATE TABLES (if not exist)
-- ============================================================

-- Invoices
CREATE TABLE IF NOT EXISTS public.invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  driver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  store_id UUID,
  total_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  delivery_fee DOUBLE PRECISION NOT NULL DEFAULT 0,
  grand_total DOUBLE PRECISION NOT NULL DEFAULT 0,
  payment_method TEXT NOT NULL DEFAULT 'cash',
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Invoice Items
CREATE TABLE IF NOT EXISTS public.invoice_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price DOUBLE PRECISION NOT NULL DEFAULT 0,
  total_price DOUBLE PRECISION NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Invoice Store Responses
CREATE TABLE IF NOT EXISTS public.invoice_store_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES public.invoices(id) ON DELETE CASCADE,
  store_id UUID NOT NULL,
  response TEXT NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Order Item Reviews
CREATE TABLE IF NOT EXISTS public.order_item_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  item_name TEXT NOT NULL,
  item_quantity INTEGER NOT NULL DEFAULT 1,
  item_price DOUBLE PRECISION NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending',
  rejection_reason TEXT,
  reviewed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Driver Store Invoices
CREATE TABLE IF NOT EXISTS public.driver_store_invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  store_id UUID NOT NULL,
  total_amount DOUBLE PRECISION NOT NULL DEFAULT 0,
  payment_method TEXT NOT NULL DEFAULT 'cash',
  status TEXT NOT NULL DEFAULT 'pending',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Messages
CREATE TABLE IF NOT EXISTS public.messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  receiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  order_id UUID,
  message TEXT NOT NULL,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Driver Locations
CREATE TABLE IF NOT EXISTS public.driver_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add address column to existing profiles table
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS address TEXT;

-- Notifications
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  type TEXT NOT NULL DEFAULT 'general',
  reference_id TEXT,
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- ENABLE RLS
-- ============================================================
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_store_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_item_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_store_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- RLS POLICIES
-- ============================================================

-- invoices
DROP POLICY IF EXISTS "Drivers can insert invoices" ON public.invoices;
CREATE POLICY "Drivers can insert invoices" ON public.invoices
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Drivers can view invoices" ON public.invoices;
CREATE POLICY "Drivers can view invoices" ON public.invoices
  FOR SELECT USING (
    driver_id = auth.uid() OR
    EXISTS (SELECT 1 FROM public.orders WHERE orders.id = invoices.order_id AND orders.driver_id = auth.uid())
  );

-- invoice_items
DROP POLICY IF EXISTS "Drivers can insert invoice items" ON public.invoice_items;
CREATE POLICY "Drivers can insert invoice items" ON public.invoice_items
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.invoices
      WHERE invoices.id = invoice_items.invoice_id
      AND invoices.driver_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Drivers can view invoice items" ON public.invoice_items;
CREATE POLICY "Drivers can view invoice items" ON public.invoice_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.invoices
      WHERE invoices.id = invoice_items.invoice_id
      AND (
        invoices.driver_id = auth.uid() OR
        EXISTS (SELECT 1 FROM public.orders WHERE orders.id = invoices.order_id AND orders.driver_id = auth.uid())
      )
    )
  );

-- invoice_store_responses
DROP POLICY IF EXISTS "Drivers can insert store responses" ON public.invoice_store_responses;
CREATE POLICY "Drivers can insert store responses" ON public.invoice_store_responses
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- order_item_reviews
DROP POLICY IF EXISTS "Drivers can insert item reviews" ON public.order_item_reviews;
CREATE POLICY "Drivers can insert item reviews" ON public.order_item_reviews
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- driver_store_invoices
DROP POLICY IF EXISTS "Drivers can insert store invoices" ON public.driver_store_invoices;
CREATE POLICY "Drivers can insert store invoices" ON public.driver_store_invoices
  FOR INSERT WITH CHECK (driver_id = auth.uid());

DROP POLICY IF EXISTS "Drivers can view their store invoices" ON public.driver_store_invoices;
CREATE POLICY "Drivers can view their store invoices" ON public.driver_store_invoices
  FOR SELECT USING (driver_id = auth.uid());

-- messages
DROP POLICY IF EXISTS "Drivers can insert messages" ON public.messages;
CREATE POLICY "Drivers can insert messages" ON public.messages
  FOR INSERT WITH CHECK (sender_id = auth.uid());

DROP POLICY IF EXISTS "Drivers can view their messages" ON public.messages;
CREATE POLICY "Drivers can view their messages" ON public.messages
  FOR SELECT USING (
    sender_id = auth.uid() OR receiver_id = auth.uid()
  );

-- driver_locations
DROP POLICY IF EXISTS "Drivers can upsert their location" ON public.driver_locations;
CREATE POLICY "Drivers can upsert their location" ON public.driver_locations
  FOR INSERT WITH CHECK (driver_id = auth.uid());

DROP POLICY IF EXISTS "Drivers can update their location" ON public.driver_locations;
CREATE POLICY "Drivers can update their location" ON public.driver_locations
  FOR UPDATE USING (driver_id = auth.uid());

DROP POLICY IF EXISTS "Anyone can view driver locations" ON public.driver_locations;
CREATE POLICY "Anyone can view driver locations" ON public.driver_locations
  FOR SELECT USING (true);

-- notifications
DROP POLICY IF EXISTS "Drivers can view their notifications" ON public.notifications;
CREATE POLICY "Drivers can view their notifications" ON public.notifications
  FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Drivers can update their notifications" ON public.notifications;
CREATE POLICY "Drivers can update their notifications" ON public.notifications
  FOR UPDATE USING (user_id = auth.uid());

-- profiles
DROP POLICY IF EXISTS "Users can view profiles" ON public.profiles;
CREATE POLICY "Users can view profiles" ON public.profiles
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Drivers can update their own profile" ON public.profiles;
CREATE POLICY "Drivers can update their own profile" ON public.profiles
  FOR UPDATE USING (id = auth.uid());

-- orders
DROP POLICY IF EXISTS "Drivers can view orders" ON public.orders;
CREATE POLICY "Drivers can view orders" ON public.orders
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Drivers can update assigned orders" ON public.orders;
CREATE POLICY "Drivers can update assigned orders" ON public.orders
  FOR UPDATE USING (driver_id = auth.uid());
