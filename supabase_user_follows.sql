-- ====================================================================
-- USER FOLLOWS TABLE, TRIGGERS, RLS & REALTIME SETUP
-- Maps directly to Games Khabar terminology:
--   - "Squad"  (Followers) -> rows where following_id = user_id
--   - "Allies" (Following) -> rows where follower_id  = user_id
-- Run this script in your Supabase Dashboard -> SQL Editor.
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Ensure social counter and privacy columns exist on public.users
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS followers_count INT DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS following_count INT DEFAULT 0;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS show_followers BOOLEAN DEFAULT TRUE;
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS show_following BOOLEAN DEFAULT TRUE;

-- 2. Create user_follows table tracking follower_id and following_id
CREATE TABLE IF NOT EXISTS public.user_follows (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    follower_id UUID NOT NULL,
    following_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT user_follows_no_self_follow CHECK (follower_id <> following_id),
    CONSTRAINT user_follows_unique_pair UNIQUE (follower_id, following_id)
);

-- 3. Indexes for fast Squad (following_id) & Allies (follower_id) lookups
CREATE INDEX IF NOT EXISTS idx_user_follows_follower_id
    ON public.user_follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_user_follows_following_id
    ON public.user_follows(following_id);
CREATE INDEX IF NOT EXISTS idx_user_follows_pair
    ON public.user_follows(follower_id, following_id);

-- 4. Atomic trigger to maintain users.followers_count (Squad) and users.following_count (Allies)
CREATE OR REPLACE FUNCTION public.sync_user_follow_counts()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_target_id UUID;
    v_follower_id UUID;
BEGIN
    IF (TG_OP = 'INSERT') THEN
        v_follower_id := NEW.follower_id;
        v_target_id := NEW.following_id;
    ELSIF (TG_OP = 'DELETE') THEN
        v_follower_id := OLD.follower_id;
        v_target_id := OLD.following_id;
    ELSE
        RETURN NULL;
    END IF;

    -- Recompute Allies count (following_count) for the actor
    UPDATE public.users
    SET following_count = (
        SELECT COUNT(*)::INT
        FROM public.user_follows
        WHERE follower_id = v_follower_id
    ),
    updated_at = NOW()
    WHERE id = v_follower_id;

    -- Recompute Squad count (followers_count) for the target user (skip synthetic demo accounts)
    UPDATE public.users
    SET followers_count = (
        SELECT COUNT(*)::INT
        FROM public.user_follows
        WHERE following_id = v_target_id
    ),
    updated_at = NOW()
    WHERE id = v_target_id
      AND COALESCE((to_jsonb(users)->>'isDemoAccount')::boolean, false) = false
      AND COALESCE((to_jsonb(users)->>'is_demo_account')::boolean, false) = false;

    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_user_follow_counts ON public.user_follows;
CREATE TRIGGER trg_sync_user_follow_counts
AFTER INSERT OR DELETE ON public.user_follows
FOR EACH ROW
EXECUTE FUNCTION public.sync_user_follow_counts();

-- 5. Migrate any existing rows from legacy public.follows table (if present)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'follows'
    ) THEN
        INSERT INTO public.user_follows (follower_id, following_id, created_at)
        SELECT
            follower_id::UUID,
            following_id::UUID,
            COALESCE(created_at, NOW())
        FROM public.follows
        WHERE follower_id IS NOT NULL
          AND following_id IS NOT NULL
          AND follower_id::TEXT ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          AND following_id::TEXT ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
          AND follower_id::UUID <> following_id::UUID
        ON CONFLICT (follower_id, following_id) DO NOTHING;
    END IF;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

-- 6. Row Level Security (RLS)
ALTER TABLE public.user_follows ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public Read user_follows" ON public.user_follows;
CREATE POLICY "Public Read user_follows"
    ON public.user_follows FOR SELECT
    USING (true);

DROP POLICY IF EXISTS "Authenticated Insert user_follows" ON public.user_follows;
CREATE POLICY "Authenticated Insert user_follows"
    ON public.user_follows FOR INSERT
    WITH CHECK (true);

DROP POLICY IF EXISTS "Authenticated Delete user_follows" ON public.user_follows;
CREATE POLICY "Authenticated Delete user_follows"
    ON public.user_follows FOR DELETE
    USING (true);

GRANT SELECT, INSERT, DELETE ON public.user_follows TO anon, authenticated;

-- 7. Enable Supabase Realtime CDC on user_follows and users
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'user_follows'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.user_follows;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables
        WHERE pubname = 'supabase_realtime' AND tablename = 'users'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
    END IF;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;
