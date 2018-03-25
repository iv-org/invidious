-- Table: public.channels

-- DROP TABLE public.channels;

CREATE TABLE public.channels
(
    id text COLLATE pg_catalog."default" NOT NULL,
    rss text COLLATE pg_catalog."default",
    updated timestamp with time zone,
    author text COLLATE pg_catalog."default"
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

GRANT ALL ON TABLE public.channels TO kemal;

-- Index: channel_id_idx

-- DROP INDEX public.channel_id_idx;

CREATE UNIQUE INDEX channel_id_idx
    ON public.channels USING btree
    (id COLLATE pg_catalog."default")
    TABLESPACE pg_default;