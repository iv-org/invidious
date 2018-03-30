-- Table: public.users

-- DROP TABLE public.users;

CREATE TABLE public.users
(
    id text COLLATE pg_catalog."default" NOT NULL,
    updated timestamp with time zone,
    notifications integer,
    subscriptions text[] COLLATE pg_catalog."default",
    CONSTRAINT users_id_key UNIQUE (id)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

GRANT ALL ON TABLE public.users TO kemal;
