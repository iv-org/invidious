-- Table: public.compilations

-- DROP TABLE public.compilations;

CREATE TABLE IF NOT EXISTS public.compilations
(
    title text,
    id text primary key,
    author text,
    description text,
    video_count integer,
    created timestamptz,
    updated timestamptz,
    privacy privacy,
    index int8[]
);

GRANT ALL ON public.playlists TO current_user;