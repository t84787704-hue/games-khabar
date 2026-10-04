-- Supabase SQL to add required columns and match_messages table

ALTER TABLE public.active_matches ADD COLUMN IF NOT EXISTS proof_status TEXT DEFAULT 'pending';
ALTER TABLE public.active_matches ADD COLUMN IF NOT EXISTS submitted_by_team_id UUID;
ALTER TABLE public.active_matches ADD COLUMN IF NOT EXISTS admin_note TEXT;
ALTER TABLE public.teams ADD COLUMN IF NOT EXISTS total_matches INT DEFAULT 0;

-- Optional columns for challenges table
ALTER TABLE public.challenges ADD COLUMN IF NOT EXISTS challenger_team_id UUID;
ALTER TABLE public.challenges ADD COLUMN IF NOT EXISTS opponent_team_id UUID;
ALTER TABLE public.challenges ADD COLUMN IF NOT EXISTS game TEXT DEFAULT 'BGMI';

CREATE TABLE IF NOT EXISTS public.match_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID REFERENCES public.active_matches(id) ON DELETE CASCADE,
    sender_team_id UUID REFERENCES public.teams(id),
    message TEXT,
    message_type TEXT DEFAULT 'text',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS and permissive policies for match_messages
ALTER TABLE public.match_messages ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies WHERE tablename = 'match_messages' AND policyname = 'Allow all access to match_messages'
    ) THEN
        CREATE POLICY "Allow all access to match_messages" ON public.match_messages FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;
