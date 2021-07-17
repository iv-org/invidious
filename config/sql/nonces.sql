-- Table: public.nonces

-- DROP TABLE public.nonces;

CREATE TABLE IF NOT EXISTS public.nonces
(
  nonce text,
  expire timestamp with time zone,
  CONSTRAINT nonces_id_key UNIQUE (nonce)
);

GRANT ALL ON TABLE public.nonces TO current_user;

-- Index: public.nonces_nonce_idx

-- DROP INDEX public.nonces_nonce_idx;

CREATE INDEX IF NOT EXISTS nonces_nonce_idx
  ON public.nonces
  USING btree
  (nonce COLLATE pg_catalog."default");

