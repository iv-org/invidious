-- Table: public.channels

-- DROP TABLE public.channels;

CREATE TABLE public.channels
(
    id text COLLATE pg_catalog."default" NOT NULL,
    author text COLLATE pg_catalog."default",
    updated timestamp with time zone,
    CONSTRAINT channels_id_key UNIQUE (id)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

GRANT ALL ON TABLE public.channels TO kemal;

-- Index: channels_id_idx

-- DROP INDEX public.channels_id_idx;

CREATE INDEX channels_id_idx
    ON public.channels USING btree
    (id COLLATE pg_catalog."default")
    TABLESPACE pg_default;