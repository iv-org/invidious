-- Table: public.invidious

-- DROP TABLE public.invidious;

CREATE TABLE public.invidious
(
    last_updated timestamp with time zone,
    video_id text COLLATE pg_catalog."default" NOT NULL,
    video_info text COLLATE pg_catalog."default",
    video_html text COLLATE pg_catalog."default",
    views bigint,
    likes integer,
    dislikes integer,
    rating double precision,
    CONSTRAINT invidious_pkey PRIMARY KEY (video_id)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE public.invidious
    OWNER to omar;

GRANT ALL ON TABLE public.invidious TO kemal;

GRANT ALL ON TABLE public.invidious TO omar;

-- Index: invidious_video_id_idx

-- DROP INDEX public.invidious_video_id_idx;

CREATE INDEX invidious_video_id_idx
    ON public.invidious USING btree
    (video_id COLLATE pg_catalog."default")
    TABLESPACE pg_default;
