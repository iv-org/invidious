-- Type: public.privacy

-- DROP TYPE public.privacy;

CREATE TYPE public.privacy AS ENUM
(
    'Public',
    'Unlisted',
    'Private'
);
