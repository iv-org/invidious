-- Table: public.channel_videos

-- DROP TABLE public.channel_videos;

CREATE TABLE IF NOT EXISTS public.channel_videos
(
  id text NOT NULL,
  title text,
  published timestamp with time zone,
  updated timestamp with time zone,
  ucid text,
  author text,
  length_seconds integer,
  live_now boolean,
  premiere_timestamp timestamp with time zone,
  views bigint,
  CONSTRAINT channel_videos_id_key UNIQUE (id)
);

GRANT ALL ON TABLE public.channel_videos TO current_user;

-- Index: public.channel_videos_ucid_published_idx

-- DROP INDEX public.channel_videos_ucid_published_idx;

CREATE INDEX IF NOT EXISTS channel_videos_ucid_published_idx
  ON public.channel_videos
  USING btree
  (ucid COLLATE pg_catalog."default", published);

