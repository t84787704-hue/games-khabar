-- Supabase SQL to add required columns and match_messages table

ALTER TABLE public.active_matches ADD COLUMN IF NOT EXISTS proof_status TEXT DEFAULT 'pending';
ALTER TABLE public.active_matches ADD COLUMN IF NOT EXISTS submitted_by_team_id UUID;
ALTER TABLE public.active_matches ADD COLUMN IF NOT EXISTS admin_note TEXT;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS total_matches INT DEFAULT 0;

-- Optional columns for challenges table
ALTER TABLE public.challenges ADD COLUMN IF NOT EXISTS challenger_team_id UUID;
ALTER TABLE public.challenges ADD COLUMN IF NOT EXISTS opponent_team_id UUID;
ALTER TABLE public.challenges ADD COLUMN IF NOT EXISTS game TEXT DEFAULT 'BGMI';

-- match_messages table
CREATE TABLE IF NOT EXISTS public.match_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id TEXT NOT NULL,
    sender_team_id TEXT NOT NULL,
    sender_team_name TEXT,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.match_messages ADD COLUMN IF NOT EXISTS sender_team_name TEXT;
ALTER TABLE public.match_messages DISABLE ROW LEVEL SECURITY;
