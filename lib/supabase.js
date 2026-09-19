/**
 * Supabase Client Configuration for GAMERS ID NETWORK
 * Project URL: https://dxdkitnroypbblazblja.supabase.co
 * Publishable Key: sb_publishable_gL8ImGd6TS-gdPOr92leHQ_Cwjiw25Y
 */
import { createClient } from '@supabase/supabase-js';

export const SUPABASE_URL = 'https://dxdkitnroypbblazblja.supabase.co';
export const SUPABASE_ANON_KEY = 'sb_publishable_gL8ImGd6TS-gdPOr92leHQ_Cwjiw25Y';

// Storage Buckets
export const STORAGE_BUCKETS = {
  UPLOADS: 'gamers_uploads',
  MATCH_PROOFS: 'match_proofs',
  USER_AVATARS: 'user_avatars',
  USER_COVERS: 'user_covers',
};

// Database Tables
export const TABLES = {
  USERS: 'users',
  POSTS: 'posts',
  TEAMS: 'teams',
  TEAM_MATCHES: 'team_matches',
  ROOMS: 'rooms',
  CHAT_MESSAGES: 'chat_messages',
  COIN_TRANSACTIONS: 'coin_transactions',
};

// Initialized Supabase Client
export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: false,
  },
  realtime: {
    params: {
      eventsPerSecond: 10,
    },
  },
});

/**
 * Upload an image or file to Supabase Storage
 * @param {Blob | Buffer | File} file - File content
 * @param {string} filePath - Path inside bucket (e.g. `avatars/user123.jpg`)
 * @param {string} bucket - Bucket name (default: gamers_uploads)
 * @returns {Promise<string | null>} Public URL of uploaded asset
 */
export async function uploadToSupabaseStorage(file, filePath, bucket = STORAGE_BUCKETS.UPLOADS) {
  try {
    const { data, error } = await supabase.storage.from(bucket).upload(filePath, file, {
      upsert: true,
      contentType: 'image/jpeg',
    });

    if (error) {
      console.error('Supabase storage upload error:', error.message);
      return null;
    }

    const { data: publicUrlData } = supabase.storage.from(bucket).getPublicUrl(filePath);
    return publicUrlData?.publicUrl || null;
  } catch (err) {
    console.error('Upload to Supabase Storage exception:', err);
    return null;
  }
}

/**
 * Helper to subscribe to realtime changes for a specific room or match chat
 * @param {string} roomId
 * @param {(payload: any) => void} onMessage
 */
export function subscribeToChatMessages(roomId, onMessage) {
  return supabase
    .channel(`room-chat-${roomId}`)
    .on(
      'postgres_changes',
      {
        event: 'INSERT',
        schema: 'public',
        table: TABLES.CHAT_MESSAGES,
        filter: `room_id=eq.${roomId}`,
      },
      (payload) => {
        onMessage(payload.new);
      }
    )
    .subscribe();
}

/**
 * Helper to subscribe to realtime updates for a team match
 * @param {string} matchId
 * @param {(match: any) => void} onUpdate
 */
export function subscribeToTeamMatch(matchId, onUpdate) {
  return supabase
    .channel(`match-${matchId}`)
    .on(
      'postgres_changes',
      {
        event: 'UPDATE',
        schema: 'public',
        table: TABLES.TEAM_MATCHES,
        filter: `match_id=eq.${matchId}`,
      },
      (payload) => {
        onUpdate(payload.new);
      }
    )
    .subscribe();
}

export default supabase;
