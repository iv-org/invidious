-- Table: public.users

-- DROP TABLE public.users;

CREATE TABLE IF NOT EXISTS public.users
(
  updated timestamp with time zone,
  notifications text[],
  subscriptions text[],
  email text NOT NULL,
  preferences text,
  password text,
  token text,
  watched text[],
  feed_needs_update boolean,
  CONSTRAINT users_email_key UNIQUE (email)
);

GRANT ALL ON TABLE public.users TO current_user;

-- Index: public.email_unique_idx

-- DROP INDEX public.email_unique_idx;

CREATE UNIQUE INDEX IF NOT EXISTS email_unique_idx
  ON public.users
  USING btree
  (lower(email) COLLATE pg_catalog."default");

