-- Table: public.videos

-- DROP TABLE public.videos;

CREATE UNLOGGED TABLE IF NOT EXISTS public.videos
(
  id text NOT NULL,
  info text,
  updated timestamp with time zone,
  CONSTRAINT videos_pkey PRIMARY KEY (id)
);

GRANT ALL ON TABLE public.videos TO current_user;

-- Index: public.id_idx

-- DROP INDEX public.id_idx;

CREATE UNIQUE INDEX IF NOT EXISTS id_idx
  ON public.videos
  USING btree
  (id COLLATE pg_catalog."default");

