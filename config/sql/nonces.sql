-- Table: public.nonces

-- DROP TABLE public.nonces;

CREATE TABLE public.nonces
(
  nonce text,
  expire timestamp with time zone
)
WITH (
  OIDS=FALSE
);

GRANT ALL ON TABLE public.nonces TO kemal;