#!/usr/bin/env bash
# Tapping the middle star must persist a rating for Inception for maya.
r=$(docker exec -i supabase_db_blnd_backend psql -U postgres -d postgres -tA -c "select rating from public.watched_movies where tmdb_id=27205 and user_id='00000000-0000-4000-8000-0000000000a1' limit 1")
echo "rating persisted: '$r'"; [ -n "$r" ]
