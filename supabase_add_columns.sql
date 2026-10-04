-- Supabase SQL to add required columns for proof review & stats tracking

ALTER TABLE public.active_matches ADD COLUMN IF NOT EXISTS proof_status TEXT DEFAULT 'pending';
ALTER TABLE public.active_matches ADD COLUMN IF NOT EXISTS submitted_by_team_id UUID;
ALTER TABLE public.active_matches ADD COLUMN IF NOT EXISTS admin_note TEXT;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS total_matches INT DEFAULT 0;
