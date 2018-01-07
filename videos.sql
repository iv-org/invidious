-- Table: public.videos

-- DROP TABLE public.videos;

CREATE TABLE public.videos
(
    id text COLLATE pg_catalog."default" NOT NULL,
    info text COLLATE pg_catalog."default",
    html text COLLATE pg_catalog."default",
    updated timestamp with time zone,
    CONSTRAINT videos_pkey PRIMARY KEY (id)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

ALTER TABLE public.videos
    OWNER to omar;

GRANT ALL ON TABLE public.videos TO kemal;

GRANT ALL ON TABLE public.videos TO omar;

-- Index: id_idx

-- DROP INDEX public.id_idx;

CREATE UNIQUE INDEX id_idx
    ON public.videos USING btree
    (id COLLATE pg_catalog."default")
    TABLESPACE pg_default;