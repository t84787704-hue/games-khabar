-- ====================================================================
-- SUPABASE SQL SCRIPT: FIX RLS PERMISSIONS & MISSING COLUMNS
-- Run this in your Supabase SQL Editor (Dashboard -> SQL Editor -> New query -> Run)
-- ====================================================================

-- 1. Ensure extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Ensure columns in public.users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS id UUID PRIMARY KEY DEFAULT uuid_generate_v4();
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS uid TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS username TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS display_name TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS cover_url TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS bio TEXT DEFAULT '';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS game_id TEXT;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS game_name TEXT DEFAULT 'PUBG Mobile';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS gamer_rank TEXT DEFAULT 'Bronze';
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS coins BIGINT DEFAULT 100;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS is_banned BOOLEAN DEFAULT FALSE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- 3. Ensure columns in public.posts
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS id UUID PRIMARY KEY DEFAULT uuid_generate_v4();
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS post_id TEXT;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS user_id TEXT NOT NULL DEFAULT '';
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS username TEXT DEFAULT 'gamer';
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS user_avatar TEXT DEFAULT '';
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS content TEXT DEFAULT '';
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS media_url TEXT;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS image_url TEXT;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS video_url TEXT;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS media_type TEXT DEFAULT 'image';
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS game TEXT DEFAULT 'All Games';
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS likes_count INT DEFAULT 0;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS comments_count INT DEFAULT 0;
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

-- 4. Enable Row Level Security (RLS) on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;

-- 5. Drop any existing conflicting policies
DROP POLICY IF EXISTS "Public Read users" ON public.users;
DROP POLICY IF EXISTS "Public Insert users" ON public.users;
DROP POLICY IF EXISTS "Public Update users" ON public.users;
DROP POLICY IF EXISTS "Allow all users" ON public.users;
DROP POLICY IF EXISTS "Enable all access for users" ON public.users;

DROP POLICY IF EXISTS "Public Read posts" ON public.posts;
DROP POLICY IF EXISTS "Public Insert posts" ON public.posts;
DROP POLICY IF EXISTS "Public Update posts" ON public.posts;
DROP POLICY IF EXISTS "Public Delete posts" ON public.posts;
DROP POLICY IF EXISTS "Allow all posts" ON public.posts;
DROP POLICY IF EXISTS "Enable all access for posts" ON public.posts;

-- 6. Create clean, permissive policies for anon and authenticated users
CREATE POLICY "Enable all access for users" 
ON public.users 
FOR ALL 
TO public 
USING (true) 
WITH CHECK (true);

CREATE POLICY "Enable all access for posts" 
ON public.posts 
FOR ALL 
TO public 
USING (true) 
WITH CHECK (true);

-- 7. Grant schema and table permissions to anon & authenticated roles
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL ROUTINES IN SCHEMA public TO anon, authenticated;

-- Default privileges for future tables
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO anon, authenticated;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO anon, authenticated;
