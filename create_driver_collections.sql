-- ============================================================
-- Create driver_collections table + RLS policies
-- Run this in Supabase SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS public.driver_collections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES public.profiles(id),
  type TEXT NOT NULL CHECK (type IN ('supply', 'collection')),
  amount DECIMAL NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  admin_notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.driver_collections ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Driver view own collections" ON public.driver_collections;
CREATE POLICY "Driver view own collections" ON public.driver_collections
  FOR SELECT USING (auth.uid() = driver_id);

DROP POLICY IF EXISTS "Driver insert collections" ON public.driver_collections;
CREATE POLICY "Driver insert collections" ON public.driver_collections
  FOR INSERT WITH CHECK (auth.uid() = driver_id);

DROP POLICY IF EXISTS "Admin manage collections" ON public.driver_collections;
CREATE POLICY "Admin manage collections" ON public.driver_collections
  FOR ALL USING (public.is_admin());

-- Trigger to auto-set updated_at
CREATE TRIGGER update_driver_collections_updated_at
  BEFORE UPDATE ON public.driver_collections
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();
