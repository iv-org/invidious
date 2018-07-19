-- Table: public.users

-- DROP TABLE public.users;

CREATE TABLE public.users
(
    id text COLLATE pg_catalog."default" NOT NULL,
    updated timestamp with time zone,
    notifications text[] COLLATE pg_catalog."default",
    subscriptions text[] COLLATE pg_catalog."default",
    email text COLLATE pg_catalog."default" NOT NULL,
    preferences text COLLATE pg_catalog."default",
    CONSTRAINT users_email_key UNIQUE (email),
    CONSTRAINT users_id_key UNIQUE (id)
)
WITH (
    OIDS = FALSE
)
TABLESPACE pg_default;

GRANT ALL ON TABLE public.users TO kemal;
