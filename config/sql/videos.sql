--SPDX-FileCopyrightText: 2019 Omar Roth <omarroth@protonmail.com>
--SPDX-License-Identifier: AGPL-3.0-or-later

-- Table: public.videos

-- DROP TABLE public.videos;

CREATE TABLE public.videos
(
  id text NOT NULL,
  info text,
  updated timestamp with time zone,
  title text,
  views bigint,
  likes integer,
  dislikes integer,
  wilson_score double precision,
  published timestamp with time zone,
  description text,
  language text,
  author text,
  ucid text,
  allowed_regions text[],
  is_family_friendly boolean,
  genre text,
  genre_url text,
  license text,
  sub_count_text text,
  author_thumbnail text,
  CONSTRAINT videos_pkey PRIMARY KEY (id)
);

GRANT ALL ON TABLE public.videos TO kemal;

-- Index: public.id_idx

-- DROP INDEX public.id_idx;

CREATE UNIQUE INDEX id_idx
  ON public.videos
  USING btree
  (id COLLATE pg_catalog."default");

