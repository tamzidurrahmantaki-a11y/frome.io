-- 1. ENABLE EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. CREATE USERS TABLE (Public Profile)
-- This table syncs with Supabase Auth
CREATE TABLE IF NOT EXISTS public.users (
  id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL PRIMARY KEY,
  email TEXT UNIQUE,
  full_name TEXT,
  avatar_url TEXT,
  subscription_plan TEXT DEFAULT 'free',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 3. CREATE LINKS TABLE
CREATE TABLE IF NOT EXISTS public.links (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
  original_url TEXT NOT NULL,
  short_slug TEXT UNIQUE NOT NULL,
  title TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.links ENABLE ROW LEVEL SECURITY;

-- 4. CREATE CLICKS TABLE
CREATE TABLE IF NOT EXISTS public.clicks (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  link_id UUID REFERENCES public.links(id) ON DELETE CASCADE NOT NULL,
  country TEXT,
  city TEXT,
  device_type TEXT,
  browser TEXT,
  os TEXT,
  referrer TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.clicks ENABLE ROW LEVEL SECURITY;

-- 5. RLS POLICIES FOR LINKS
-- Policy: Users can view only their own links
CREATE POLICY "Users can view their own links" ON public.links
  FOR SELECT USING (auth.uid() = user_id);

-- Policy: Authenticated users can insert their own links
CREATE POLICY "Users can insert their own links" ON public.links
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own links
CREATE POLICY "Users can update their own links" ON public.links
  FOR UPDATE USING (auth.uid() = user_id);

-- Policy: Users can delete their own links
CREATE POLICY "Users can delete their own links" ON public.links
  FOR DELETE USING (auth.uid() = user_id);

-- 6. RLS POLICIES FOR CLICKS
CREATE POLICY "Users can view clicks of their own links" ON public.clicks
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.links
      WHERE public.links.id = public.clicks.link_id
      AND public.links.user_id = auth.uid()
    )
  );

-- Allow public insert for tracking (this is how we capture clicks)
CREATE POLICY "Allow public insert for tracking clicks" ON public.clicks
  FOR INSERT WITH CHECK (true);

-- 7. AUTH TRIGGER (OPTIONAL BUT RECOMMENDED)
-- Automatically create a profile in public.users when a user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email)
  VALUES (new.id, new.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
