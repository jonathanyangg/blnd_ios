#!/usr/bin/env bash
# Inception must be on maya's personal watchlist after flow 08.
n=$(docker exec -i supabase_db_blnd_backend psql -U postgres -d postgres -tA -c "select count(*) from public.watchlist_movies where tmdb_id=27205 and added_by='00000000-0000-4000-8000-0000000000a1'")
echo "watchlist rows for Inception: $n"; [ "$n" -ge 1 ]
