#!/usr/bin/env bash
# Put demo-account data touched by UI flows back to a known state, so flows are repeatable.
# Local Supabase only (docker exec into supabase_db_blnd_backend). Never touches real data.
set -euo pipefail
docker exec -i supabase_db_blnd_backend psql -U postgres -d postgres -q <<'SQL'
-- Inception (tmdb 27205) is the movie the flows act on
delete from public.watchlist_movies where tmdb_id = 27205
  and added_by in ('00000000-0000-4000-8000-0000000000a1','00000000-0000-4000-8000-0000000000a2','00000000-0000-4000-8000-0000000000a3');
delete from public.watched_movies where tmdb_id = 27205
  and user_id in ('00000000-0000-4000-8000-0000000000a1','00000000-0000-4000-8000-0000000000a2','00000000-0000-4000-8000-0000000000a3');
delete from public.interested_movies where tmdb_id = 27205
  and user_id in ('00000000-0000-4000-8000-0000000000a1','00000000-0000-4000-8000-0000000000a2','00000000-0000-4000-8000-0000000000a3');
-- swipes made by recent flow runs (flow 02 verifies a fresh row)
delete from public.movie_interactions where user_id='00000000-0000-4000-8000-0000000000a1' and interaction_type='interested' and created_at > now() - interval '30 minutes';
-- blends created by the flows
delete from public.groups where name = 'Maestro Blend';
SQL
