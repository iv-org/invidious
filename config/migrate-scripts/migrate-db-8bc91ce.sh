CREATE INDEX channel_videos_ucid_published_idx
  ON public.channel_videos
  USING btree
  (ucid COLLATE pg_catalog."default", published);

DROP INDEX channel_videos_ucid_idx;