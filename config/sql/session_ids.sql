--SPDX-FileCopyrightText: 2019 Omar Roth <omarroth@protonmail.com>
--SPDX-License-Identifier: AGPL-3.0-or-later

-- Table: public.session_ids

-- DROP TABLE public.session_ids;

CREATE TABLE public.session_ids
(
  id text NOT NULL,
  email text,
  issued timestamp with time zone,
  CONSTRAINT session_ids_pkey PRIMARY KEY (id)
);

GRANT ALL ON TABLE public.session_ids TO kemal;

-- Index: public.session_ids_id_idx

-- DROP INDEX public.session_ids_id_idx;

CREATE INDEX session_ids_id_idx
  ON public.session_ids
  USING btree
  (id COLLATE pg_catalog."default");

