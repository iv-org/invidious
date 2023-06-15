-- Type: public.privacy

-- DROP TYPE public.privacy;

CREATE TYPE public.privacy AS ENUM
(
    'Unlisted',
    'Private'
);

-- Table: public.compilations

-- DROP TABLE public.compilations;

CREATE TABLE IF NOT EXISTS public.compilations
(
    title text,
    id text primary key,
    author text,
    description text,
    video_count integer,
    created timestamptz,
    updated timestamptz,
    privacy privacy,
    index int8[]
);

GRANT ALL ON public.compilations TO current_user;
