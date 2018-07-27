-- Table: public.channel_videos

-- DROP TABLE public.channel_videos;

CREATE TABLE public.channel_videos
(
    id text COLLATE pg_catalog."default" NOT NULL,
    title text COLLATE pg_catalog."default",
    published timestamp with time zone,
    updated timestamp with time zone,
    ucid text COLLATE pg_catalog."default",
    author text COLLATE pg_catalog."default",
    CONSTRAINT channel_videos_id_key UNIQUE (id)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

GRANT ALL ON TABLE public.channel_videos TO kemal;

-- Index: channel_videos_published_idx

-- DROP INDEX public.channel_videos_published_idx;

CREATE INDEX channel_videos_published_idx
    ON public.channel_videos USING btree
    (published)
    TABLESPACE pg_default;

-- Index: channel_videos_ucid_idx

-- DROP INDEX public.channel_videos_ucid_idx;

CREATE INDEX channel_videos_ucid_idx
    ON public.channel_videos USING btree
    (ucid COLLATE pg_catalog."default")
    TABLESPACE pg_default;