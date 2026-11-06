REVOKE ALL ON FUNCTION public.maxchess_school_create_class(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.maxchess_school_join(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.maxchess_school_my_classes() FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.maxchess_school_create_class(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.maxchess_school_join(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.maxchess_school_my_classes() TO authenticated;
