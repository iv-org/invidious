-- Table: public.videos

-- DROP TABLE public.videos;

CREATE TABLE public.videos
(
    last_updated timestamp with time zone,
    video_id text COLLATE pg_catalog."default" NOT NULL,
    video_info text COLLATE pg_catalog."default",
    video_html text COLLATE pg_catalog."default",
    views bigint,
    likes integer,
    dislikes integer,
    rating double precision,
    description text COLLATE pg_catalog."default",
    CONSTRAINT videos_pkey PRIMARY KEY (video_id)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE public.videos
    OWNER to omar;

GRANT ALL ON TABLE public.videos TO kemal;

GRANT ALL ON TABLE public.videos TO omar;

-- Index: videos_video_id_idx

-- DROP INDEX public.videos_video_id_idx;

CREATE INDEX videos_video_id_idx
    ON public.videos USING btree
    (video_id COLLATE pg_catalog."default")
    TABLESPACE pg_default;