-- Table: public.playlists

-- DROP TABLE public.playlists;

CREATE TABLE public.playlists
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

GRANT ALL ON public.playlists TO kemal;
