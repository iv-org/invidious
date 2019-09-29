--SPDX-FileCopyrightText: 2019 Omar Roth <omarroth@protonmail.com>
--SPDX-License-Identifier: AGPL-3.0-or-later

-- Table: public.annotations

-- DROP TABLE public.annotations;

CREATE TABLE public.annotations
(
  id text NOT NULL,
  annotations xml,
  CONSTRAINT annotations_id_key UNIQUE (id)
);

GRANT ALL ON TABLE public.annotations TO kemal;
