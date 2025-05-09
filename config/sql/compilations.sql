-- Type: public.compilation_privacy

-- DROP TYPE public.compilation_privacy;

CREATE TYPE public.compilation_privacy AS ENUM
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
    privacy compilation_privacy,
    index int8[],
    first_video_id text,
    first_video_starting_timestamp_seconds integer,
    first_video_ending_timestamp_seconds integer
);

GRANT ALL ON public.compilations TO current_user;
