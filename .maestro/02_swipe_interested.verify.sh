#!/usr/bin/env bash
# Right-swipe (toast says "Added to My Watchlist") really records an 'interested' interaction for maya (last 3 min).
n=$(docker exec -i supabase_db_blnd_backend psql -U postgres -d postgres -tA -c "select count(*) from public.movie_interactions where user_id='00000000-0000-4000-8000-0000000000a1' and interaction_type='interested' and created_at > now() - interval '3 minutes'")
echo "recent interested interactions: $n"; [ "$n" -ge 1 ]
