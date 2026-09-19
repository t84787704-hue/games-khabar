-- ====================================================================
-- GAMERS ID NETWORK - COMPLETE SUPABASE DATABASE SCHEMA
-- Project URL: https://dxdkitnroypbblazblja.supabase.co
-- Storage Buckets: avatars, covers, posts, team-logos, screenshots
-- Tables:
--   1. users                - Gamer profiles, rank, virtual coins
--   2. posts                - Feed posts and clips
--   3. likes                - Post likes
--   4. comments             - Post comments
--   5. teams                - Clan/Team registry
--   6. team_members         - Team rosters and roles
--   7. team_join_requests   - Team invite and join requests
--   8. team_matches         - 4v4 TDM/Custom Clan matches & status
--   9. match_chat           - Realtime in-match & dispute chat
--  10. rooms                - Tournament & Custom Match rooms
--  11. room_members         - Players registered in custom rooms
--  12. coin_transactions    - Virtual in-game coin transactions (NO cash/UC/diamonds)
--  13. notifications        - In-app alerts and notifications
-- ====================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- --------------------------------------------------------------------
-- 1. USERS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    uid TEXT UNIQUE NOT NULL,
    email TEXT,
    username TEXT UNIQUE NOT NULL,
    display_name TEXT,
    avatar_url TEXT,
    cover_url TEXT,
    bio TEXT DEFAULT '',
    game_id TEXT,
    game_name TEXT DEFAULT 'PUBG Mobile',
    gamer_rank TEXT DEFAULT 'Bronze',
    rank_proof_url TEXT,
    coins BIGINT DEFAULT 100 CHECK (coins >= 0),
    is_verified BOOLEAN DEFAULT FALSE,
    is_admin BOOLEAN DEFAULT FALSE,
    is_banned BOOLEAN DEFAULT FALSE,
    fcm_token TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 2. POSTS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id TEXT UNIQUE,
    user_id TEXT NOT NULL,
    username TEXT NOT NULL,
    user_avatar TEXT,
    content TEXT,
    media_url TEXT,
    media_type TEXT DEFAULT 'image', -- 'image' or 'video'
    game TEXT DEFAULT 'All Games',
    likes_count INT DEFAULT 0,
    comments_count INT DEFAULT 0,
    shares_count INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 3. LIKES TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    post_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    username TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(post_id, user_id)
);

-- --------------------------------------------------------------------
-- 4. COMMENTS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    comment_id TEXT UNIQUE,
    post_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    username TEXT NOT NULL,
    user_avatar TEXT,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 5. TEAMS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id TEXT UNIQUE NOT NULL,
    name TEXT UNIQUE NOT NULL,
    tag TEXT NOT NULL,
    logo_url TEXT,
    leader_id TEXT NOT NULL,
    leader_name TEXT NOT NULL,
    game TEXT DEFAULT 'PUBG Mobile',
    bio TEXT DEFAULT '',
    members JSONB DEFAULT '[]'::jsonb,
    member_count INT DEFAULT 1,
    wins INT DEFAULT 0,
    losses INT DEFAULT 0,
    matches_played INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 6. TEAM MEMBERS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.team_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    username TEXT NOT NULL,
    role TEXT DEFAULT 'Member', -- 'Leader', 'Co-Leader', 'Member'
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(team_id, user_id)
);

-- --------------------------------------------------------------------
-- 7. TEAM JOIN REQUESTS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.team_join_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id TEXT UNIQUE,
    team_id TEXT NOT NULL,
    team_name TEXT,
    user_id TEXT NOT NULL,
    username TEXT NOT NULL,
    user_avatar TEXT,
    status TEXT DEFAULT 'pending', -- 'pending', 'accepted', 'rejected'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 8. TEAM MATCHES TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.team_matches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    match_id TEXT UNIQUE NOT NULL,
    team1_id TEXT NOT NULL,
    team1_name TEXT NOT NULL,
    team1_leader_id TEXT NOT NULL,
    team1_leader_name TEXT NOT NULL,
    team1_proof TEXT,
    team2_id TEXT NOT NULL,
    team2_name TEXT NOT NULL,
    team2_leader_id TEXT NOT NULL,
    team2_leader_name TEXT NOT NULL,
    team2_proof TEXT,
    game TEXT NOT NULL,
    mode TEXT DEFAULT 'TDM 4v4',
    status TEXT DEFAULT 'Pending', -- 'Pending', 'Accepted', 'Live', 'Proof Submitted', 'Verified', 'Disputed', 'Rejected', 'Cancelled'
    match_time TIMESTAMPTZ DEFAULT NOW(),
    admin_note TEXT,
    reject_reason TEXT,
    dispute_reason TEXT DEFAULT '',
    proof_attempts INT DEFAULT 0,
    last_proof_at TIMESTAMPTZ,
    winner_id TEXT,
    winner_name TEXT,
    verified_by TEXT,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 9. MATCH CHAT TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.match_chat (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    match_id TEXT,
    room_id TEXT,
    sender_id TEXT NOT NULL,
    sender_name TEXT NOT NULL,
    sender_avatar TEXT,
    message TEXT NOT NULL,
    image_url TEXT,
    message_type TEXT DEFAULT 'text', -- 'text', 'image', 'system'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 10. ROOMS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.rooms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id TEXT UNIQUE NOT NULL,
    title TEXT NOT NULL,
    game TEXT NOT NULL,
    mode TEXT DEFAULT 'Squad',
    map_name TEXT DEFAULT 'Erangel',
    entry_coins INT DEFAULT 0,
    prize_coins INT DEFAULT 0,
    max_players INT DEFAULT 100,
    current_players INT DEFAULT 0,
    room_code TEXT,
    password TEXT,
    host_id TEXT NOT NULL,
    host_name TEXT NOT NULL,
    status TEXT DEFAULT 'Open', -- 'Open', 'Live', 'Completed', 'Cancelled'
    scheduled_at TIMESTAMPTZ,
    winner_name TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 11. ROOM MEMBERS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.room_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    username TEXT NOT NULL,
    in_game_id TEXT,
    slot_number INT,
    team_number INT,
    joined_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(room_id, user_id)
);

-- --------------------------------------------------------------------
-- 12. COIN TRANSACTIONS TABLE (Virtual Coins Only - NO cash/UC/diamonds)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.coin_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    amount BIGINT NOT NULL, -- positive for credit, negative for debit
    type TEXT NOT NULL, -- 'daily_reward', 'match_win', 'match_entry', 'admin_adjustment'
    description TEXT,
    balance_after BIGINT,
    reference_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 13. NOTIFICATIONS TABLE
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    notification_id TEXT UNIQUE,
    user_id TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT DEFAULT 'general', -- 'match_challenge', 'team_invite', 'reward', 'admin'
    data JSONB DEFAULT '{}'::jsonb,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- INDEXES
-- --------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_users_uid ON public.users(uid);
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON public.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_likes_post ON public.likes(post_id);
CREATE INDEX IF NOT EXISTS idx_comments_post ON public.comments(post_id);
CREATE INDEX IF NOT EXISTS idx_teams_team_id ON public.teams(team_id);
CREATE INDEX IF NOT EXISTS idx_team_members_team ON public.team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_team_join_team ON public.team_join_requests(team_id);
CREATE INDEX IF NOT EXISTS idx_team_matches_match ON public.team_matches(match_id);
CREATE INDEX IF NOT EXISTS idx_team_matches_status ON public.team_matches(status);
CREATE INDEX IF NOT EXISTS idx_match_chat_match ON public.match_chat(match_id);
CREATE INDEX IF NOT EXISTS idx_rooms_status ON public.rooms(status);
CREATE INDEX IF NOT EXISTS idx_room_members_room ON public.room_members(room_id);
CREATE INDEX IF NOT EXISTS idx_coin_tx_user ON public.coin_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON public.notifications(user_id);

-- --------------------------------------------------------------------
-- REALTIME PUBLICATION
-- --------------------------------------------------------------------
ALTER PUBLICATION supabase_realtime ADD TABLE public.match_chat;
ALTER PUBLICATION supabase_realtime ADD TABLE public.team_matches;
ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- --------------------------------------------------------------------
-- ROW LEVEL SECURITY (RLS) POLICIES
-- --------------------------------------------------------------------
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_join_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.match_chat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.room_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coin_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

-- Allow public read/write with client anon key
CREATE POLICY "Public Read users" ON public.users FOR SELECT USING (true);
CREATE POLICY "Public Insert users" ON public.users FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Update users" ON public.users FOR UPDATE USING (true);

CREATE POLICY "Public Read posts" ON public.posts FOR SELECT USING (true);
CREATE POLICY "Public Insert posts" ON public.posts FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Update posts" ON public.posts FOR UPDATE USING (true);
CREATE POLICY "Public Delete posts" ON public.posts FOR DELETE USING (true);

CREATE POLICY "Public Read likes" ON public.likes FOR SELECT USING (true);
CREATE POLICY "Public Insert likes" ON public.likes FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Delete likes" ON public.likes FOR DELETE USING (true);

CREATE POLICY "Public Read comments" ON public.comments FOR SELECT USING (true);
CREATE POLICY "Public Insert comments" ON public.comments FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Delete comments" ON public.comments FOR DELETE USING (true);

CREATE POLICY "Public Read teams" ON public.teams FOR SELECT USING (true);
CREATE POLICY "Public Insert teams" ON public.teams FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Update teams" ON public.teams FOR UPDATE USING (true);

CREATE POLICY "Public Read team_members" ON public.team_members FOR SELECT USING (true);
CREATE POLICY "Public Insert team_members" ON public.team_members FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Delete team_members" ON public.team_members FOR DELETE USING (true);

CREATE POLICY "Public Read team_join_requests" ON public.team_join_requests FOR SELECT USING (true);
CREATE POLICY "Public Insert team_join_requests" ON public.team_join_requests FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Update team_join_requests" ON public.team_join_requests FOR UPDATE USING (true);

CREATE POLICY "Public Read team_matches" ON public.team_matches FOR SELECT USING (true);
CREATE POLICY "Public Insert team_matches" ON public.team_matches FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Update team_matches" ON public.team_matches FOR UPDATE USING (true);

CREATE POLICY "Public Read match_chat" ON public.match_chat FOR SELECT USING (true);
CREATE POLICY "Public Insert match_chat" ON public.match_chat FOR INSERT WITH CHECK (true);

CREATE POLICY "Public Read rooms" ON public.rooms FOR SELECT USING (true);
CREATE POLICY "Public Insert rooms" ON public.rooms FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Update rooms" ON public.rooms FOR UPDATE USING (true);

CREATE POLICY "Public Read room_members" ON public.room_members FOR SELECT USING (true);
CREATE POLICY "Public Insert room_members" ON public.room_members FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Delete room_members" ON public.room_members FOR DELETE USING (true);

CREATE POLICY "Public Read coin_transactions" ON public.coin_transactions FOR SELECT USING (true);
CREATE POLICY "Public Insert coin_transactions" ON public.coin_transactions FOR INSERT WITH CHECK (true);

CREATE POLICY "Public Read notifications" ON public.notifications FOR SELECT USING (true);
CREATE POLICY "Public Insert notifications" ON public.notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Update notifications" ON public.notifications FOR UPDATE USING (true);

-- --------------------------------------------------------------------
-- STORAGE BUCKETS SETUP (Exact requested buckets)
-- --------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('avatars', 'avatars', true),
    ('covers', 'covers', true),
    ('posts', 'posts', true),
    ('team-logos', 'team-logos', true),
    ('screenshots', 'screenshots', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage RLS Policies
CREATE POLICY "Public Read Buckets" 
ON storage.objects FOR SELECT 
USING (bucket_id IN ('avatars', 'covers', 'posts', 'team-logos', 'screenshots'));

CREATE POLICY "Public Insert Buckets" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id IN ('avatars', 'covers', 'posts', 'team-logos', 'screenshots'));

CREATE POLICY "Public Update Buckets" 
ON storage.objects FOR UPDATE 
USING (bucket_id IN ('avatars', 'covers', 'posts', 'team-logos', 'screenshots'));
