-- ====================================================================
-- IN-APP NOTIFICATIONS TABLE & REALTIME SCHEMA
-- Table: notifications
-- ====================================================================

CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,                    -- recipient
  sender_id uuid,                           -- who triggered (nullable for system/admin)
  sender_name text,
  sender_avatar text,
  type text NOT NULL,                       -- notification type identifier
  title text NOT NULL,
  body text NOT NULL,
  data jsonb,                               -- extra payload (post_id, room_id, etc.)
  is_read boolean DEFAULT false,
  is_seen boolean DEFAULT false,
  priority text DEFAULT 'normal',           -- 'low', 'normal', 'high'
  created_at timestamptz DEFAULT now(),
  read_at timestamptz
);

-- Indexes for lightning fast queries
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(user_id, is_read);

-- Enable realtime
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
  END IF;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

-- Row Level Security (RLS)
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
  DROP POLICY IF EXISTS "Users can read own notifications" ON notifications;
  CREATE POLICY "Users can read own notifications" 
  ON notifications FOR SELECT 
  USING (auth.uid() = user_id OR auth.uid() IS NOT NULL);

  DROP POLICY IF EXISTS "Anyone can insert notifications" ON notifications;
  CREATE POLICY "Anyone can insert notifications" 
  ON notifications FOR INSERT 
  WITH CHECK (true);

  DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
  CREATE POLICY "Users can update own notifications" 
  ON notifications FOR UPDATE 
  USING (auth.uid() = user_id OR auth.uid() IS NOT NULL);

  DROP POLICY IF EXISTS "Users can delete own notifications" ON notifications;
  CREATE POLICY "Users can delete own notifications" 
  ON notifications FOR DELETE 
  USING (auth.uid() = user_id OR auth.uid() IS NOT NULL);
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;
