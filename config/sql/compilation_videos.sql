-- Table: public.compilation_videos

-- DROP TABLE public.compilation_videos;

CREATE TABLE IF NOT EXISTS public.compilation_videos
(
    title text,
    id text,
    author text,
    ucid text,
    length_seconds integer,
    starting_timestamp_seconds integer,
    ending_timestamp_seconds integer,
    published timestamptz,
    compid text references compilations(id),
    index int8,
    order_index integer,
    PRIMARY KEY (index,compid)
);

GRANT ALL ON TABLE public.compilation_videos TO current_user;
