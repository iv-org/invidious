-- Table: public.channels

-- DROP TABLE public.channels;

CREATE TABLE public.channels
(
    id text COLLATE pg_catalog."default" NOT NULL,
    author text COLLATE pg_catalog."default",
    updated timestamp with time zone
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

GRANT ALL ON TABLE public.channels TO kemal;
