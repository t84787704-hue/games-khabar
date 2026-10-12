-- Supabase SQL to add required columns and match_messages table

ALTER TABLE public.active_matches ADD COLUMN IF NOT EXISTS proof_status TEXT DEFAULT 'pending';
ALTER TABLE public.active_matches ADD COLUMN IF NOT EXISTS submitted_by_team_id UUID;
ALTER TABLE public.active_matches ADD COLUMN IF NOT EXISTS admin_note TEXT;
ALTER TABLE public.active_matches ADD COLUMN IF NOT EXISTS start_time TIMESTAMPTZ;
ALTER TABLE public.active_matches ADD COLUMN IF NOT EXISTS proof_upload_count INT DEFAULT 0;
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

-- Tournament rooms match lifecycle columns
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS win_proof_url TEXT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS proof_url TEXT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS win_proof_uploaded_at TIMESTAMPTZ;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS reward_status TEXT DEFAULT 'idle';
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS winner_id TEXT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS ocr_status TEXT DEFAULT 'none';
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS ocr_text TEXT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS ocr_score INT DEFAULT 0;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS proof_reject_count INT DEFAULT 0;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS auto_approve_at TIMESTAMPTZ;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS disputed BOOLEAN DEFAULT false;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS disputed_by TEXT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS disputed_by_name TEXT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS dispute_reason TEXT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS dispute_proof_url TEXT;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS disputed_at TIMESTAMPTZ;
ALTER TABLE public.rooms ADD COLUMN IF NOT EXISTS start_time TIMESTAMPTZ;

-- Welcome bonus claim tracking (Issue #6)
ALTER TABLE public.users ADD COLUMN IF NOT EXISTS welcome_bonus_claimed BOOLEAN DEFAULT false;
