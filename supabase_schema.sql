-- ====================================================================
-- GAMERS ID NETWORK - SUPABASE DATABASE SCHEMA
-- Project URL: https://dxdkitnroypbblazblja.supabase.co
-- Tables: users, posts, teams, team_matches, rooms, chat_messages, coin_transactions
-- Storage Buckets: gamers_uploads, match_proofs, user_avatars, user_covers
-- ====================================================================

-- Enable UUID extension if not enabled
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
-- 3. TEAMS TABLE
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
-- 4. TEAM MATCHES TABLE
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
-- 5. ROOMS TABLE (Custom matches / Game rooms)
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
-- 6. CHAT MESSAGES TABLE (Realtime chat for matches & rooms)
-- --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    room_id TEXT,
    match_id TEXT,
    sender_id TEXT NOT NULL,
    sender_name TEXT NOT NULL,
    sender_avatar TEXT,
    message TEXT NOT NULL,
    image_url TEXT,
    message_type TEXT DEFAULT 'text', -- 'text', 'image', 'system'
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- --------------------------------------------------------------------
-- 7. COIN TRANSACTIONS TABLE (Pure in-game coins, zero cash/UC/diamonds)
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
-- INDEXES FOR MAXIMUM QUERY PERFORMANCE
-- --------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_users_uid ON public.users(uid);
CREATE INDEX IF NOT EXISTS idx_posts_user_id ON public.posts(user_id);
CREATE INDEX IF NOT EXISTS idx_posts_created_at ON public.posts(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_teams_team_id ON public.teams(team_id);
CREATE INDEX IF NOT EXISTS idx_team_matches_match_id ON public.team_matches(match_id);
CREATE INDEX IF NOT EXISTS idx_team_matches_status ON public.team_matches(status);
CREATE INDEX IF NOT EXISTS idx_rooms_status ON public.rooms(status);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room_id ON public.chat_messages(room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_match_id ON public.chat_messages(match_id);
CREATE INDEX IF NOT EXISTS idx_coin_transactions_user_id ON public.coin_transactions(user_id);

-- --------------------------------------------------------------------
-- ENABLE REALTIME PUBLICATION FOR LIVE UPDATES
-- --------------------------------------------------------------------
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.team_matches;
ALTER PUBLICATION supabase_realtime ADD TABLE public.rooms;

-- --------------------------------------------------------------------
-- ROW LEVEL SECURITY (RLS) POLICIES
-- --------------------------------------------------------------------
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coin_transactions ENABLE ROW LEVEL SECURITY;

-- Allow public read & write for authorized client operations
CREATE POLICY "Allow public read users" ON public.users FOR SELECT USING (true);
CREATE POLICY "Allow public insert users" ON public.users FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update users" ON public.users FOR UPDATE USING (true);

CREATE POLICY "Allow public read posts" ON public.posts FOR SELECT USING (true);
CREATE POLICY "Allow public insert posts" ON public.posts FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update posts" ON public.posts FOR UPDATE USING (true);

CREATE POLICY "Allow public read teams" ON public.teams FOR SELECT USING (true);
CREATE POLICY "Allow public insert teams" ON public.teams FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update teams" ON public.teams FOR UPDATE USING (true);

CREATE POLICY "Allow public read team_matches" ON public.team_matches FOR SELECT USING (true);
CREATE POLICY "Allow public insert team_matches" ON public.team_matches FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update team_matches" ON public.team_matches FOR UPDATE USING (true);

CREATE POLICY "Allow public read rooms" ON public.rooms FOR SELECT USING (true);
CREATE POLICY "Allow public insert rooms" ON public.rooms FOR INSERT WITH CHECK (true);
CREATE POLICY "Allow public update rooms" ON public.rooms FOR UPDATE USING (true);

CREATE POLICY "Allow public read chat_messages" ON public.chat_messages FOR SELECT USING (true);
CREATE POLICY "Allow public insert chat_messages" ON public.chat_messages FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow public read coin_transactions" ON public.coin_transactions FOR SELECT USING (true);
CREATE POLICY "Allow public insert coin_transactions" ON public.coin_transactions FOR INSERT WITH CHECK (true);

-- --------------------------------------------------------------------
-- STORAGE BUCKETS SETUP
-- --------------------------------------------------------------------
INSERT INTO storage.buckets (id, name, public)
VALUES 
    ('gamers_uploads', 'gamers_uploads', true),
    ('match_proofs', 'match_proofs', true),
    ('user_avatars', 'user_avatars', true),
    ('user_covers', 'user_covers', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Storage RLS: Allow public access to upload and read files
CREATE POLICY "Public Access To Read Storage" 
ON storage.objects FOR SELECT 
USING (bucket_id IN ('gamers_uploads', 'match_proofs', 'user_avatars', 'user_covers'));

CREATE POLICY "Public Access To Upload Storage" 
ON storage.objects FOR INSERT 
WITH CHECK (bucket_id IN ('gamers_uploads', 'match_proofs', 'user_avatars', 'user_covers'));

CREATE POLICY "Public Access To Update Storage" 
ON storage.objects FOR UPDATE 
USING (bucket_id IN ('gamers_uploads', 'match_proofs', 'user_avatars', 'user_covers'));
