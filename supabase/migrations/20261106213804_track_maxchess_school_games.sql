-- Count completed MaxChess online games independently of rated-game statistics.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS maxchess_games_played integer NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.profiles'::regclass
      AND conname = 'profiles_maxchess_games_played_nonnegative'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_maxchess_games_played_nonnegative
      CHECK (maxchess_games_played >= 0);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.track_maxchess_school_games()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF OLD.status = 'active'
     AND NEW.status IN ('white_won', 'black_won', 'draw') THEN
    UPDATE public.profiles
       SET maxchess_games_played = maxchess_games_played + 1
     WHERE id IN (NEW.white_player, NEW.black_player);
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.track_maxchess_school_games() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS track_maxchess_school_games ON public.games;
CREATE TRIGGER track_maxchess_school_games
AFTER UPDATE OF status ON public.games
FOR EACH ROW
WHEN (OLD.status = 'active' AND NEW.status IN ('white_won', 'black_won', 'draw'))
EXECUTE FUNCTION public.track_maxchess_school_games();

DROP FUNCTION IF EXISTS public.maxchess_school_roster(uuid);

CREATE FUNCTION public.maxchess_school_roster(p_class uuid)
RETURNS TABLE(
  student_id uuid,
  username text,
  rating integer,
  joined_at timestamptz,
  lichess_username text,
  chesscom_username text,
  maxchess_games_played integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
      FROM public.school_classes
     WHERE id = p_class
       AND teacher_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'Only the teacher who owns this class can view its roster.';
  END IF;

  RETURN QUERY
  SELECT
    m.student_id,
    p.username,
    p.rating,
    m.joined_at,
    max(CASE WHEN a.provider = 'lichess' AND a.share_with_teacher THEN a.username END),
    max(CASE WHEN a.provider = 'chesscom' AND a.share_with_teacher THEN a.username END),
    p.maxchess_games_played
  FROM public.school_members AS m
  JOIN public.profiles AS p ON p.id = m.student_id
  LEFT JOIN public.school_external_accounts AS a ON a.student_id = m.student_id
  WHERE m.class_id = p_class
  GROUP BY m.student_id, p.username, p.rating, m.joined_at, p.maxchess_games_played
  ORDER BY p.username;
END;
$$;

REVOKE ALL ON FUNCTION public.maxchess_school_roster(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.maxchess_school_roster(uuid) TO authenticated;
