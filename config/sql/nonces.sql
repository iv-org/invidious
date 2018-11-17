-- Table: public.nonces

-- DROP TABLE public.nonces;

CREATE TABLE public.nonces
(
  nonce text
)
WITH (
  OIDS=FALSE
);

GRANT ALL ON TABLE public.nonces TO kemal;