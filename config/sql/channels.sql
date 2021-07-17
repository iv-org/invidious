-- Table: public.channels

-- DROP TABLE public.channels;

CREATE TABLE IF NOT EXISTS public.channels
(
  id text NOT NULL,
  author text,
  updated timestamp with time zone,
  deleted boolean,
  subscribed timestamp with time zone,
  CONSTRAINT channels_id_key UNIQUE (id)
);

GRANT ALL ON TABLE public.channels TO current_user;

-- Index: public.channels_id_idx

-- DROP INDEX public.channels_id_idx;

CREATE INDEX IF NOT EXISTS channels_id_idx
  ON public.channels
  USING btree
  (id COLLATE pg_catalog."default");

