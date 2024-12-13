-- Table: public.playlist_videos

-- DROP TABLE public.playlist_videos;

CREATE TABLE IF NOT EXISTS public.playlist_videos
(
    title text,
    id text,
    author text,
    ucid text,
    length_seconds integer,
    published timestamptz,
    plid text references playlists(id),
    index int8,
    live_now boolean,
    PRIMARY KEY (index,plid)
);

GRANT ALL ON TABLE public.playlist_videos TO current_user;
