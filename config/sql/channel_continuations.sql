-- Table: public.channel_continuations

-- DROP TABLE public.channel_continuations;

CREATE TABLE IF NOT EXISTS public.channel_continuations
(
  id text NOT NULL,
  page integer NOT NULL,
  sort_by text NOT NULL,
  continuation text,
  CONSTRAINT channel_continuations_id_page_sort_by_key UNIQUE (id, page, sort_by)
);

GRANT ALL ON TABLE public.channel_continuations TO default_user;

-- Index: public.channel_continuations_id_idx

-- DROP INDEX public.channel_continuations_id_idx;

CREATE INDEX IF NOT EXISTS channel_continuations_id_idx
  ON public.channel_continuations
  USING btree
  (id COLLATE pg_catalog."default");
