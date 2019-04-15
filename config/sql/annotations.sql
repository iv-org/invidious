-- Table: public.annotations

-- DROP TABLE public.annotations;

CREATE TABLE public.annotations
(
  id text NOT NULL,
  annotations xml,
  CONSTRAINT annotations_id_key UNIQUE (id)
);

GRANT ALL ON TABLE public.annotations TO kemal;
