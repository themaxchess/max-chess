CREATE TABLE IF NOT EXISTS public.lichess_oauth_tokens (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  lichess_user_id text NOT NULL UNIQUE,
  lichess_username text NOT NULL,
  access_token text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.lichess_oauth_tokens ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.lichess_oauth_tokens FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.lichess_oauth_tokens TO service_role;

CREATE TABLE IF NOT EXISTS public.lichess_game_imports (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  game_id uuid NOT NULL REFERENCES public.games(id) ON DELETE CASCADE,
  lichess_game_id text NOT NULL,
  lichess_url text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, game_id)
);
ALTER TABLE public.lichess_game_imports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.lichess_game_imports FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.lichess_game_imports TO service_role;