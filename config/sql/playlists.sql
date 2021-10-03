-- Type: public.privacy

-- DROP TYPE public.privacy;

CREATE TYPE public.privacy AS ENUM
(
    'Public',
    'Unlisted',
    'Private'
);

-- Table: public.playlists

-- DROP TABLE public.playlists;

CREATE TABLE IF NOT EXISTS public.playlists
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
