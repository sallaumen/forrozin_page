--
-- PostgreSQL database dump
--

-- Dumped from database version 16.13 (Debian 16.13-1.pgdg13+1)
-- Dumped by pg_dump version 17.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: oban_job_state; Type: TYPE; Schema: public; Owner: forrozin
--

CREATE TYPE public.oban_job_state AS ENUM (
    'available',
    'scheduled',
    'executing',
    'retryable',
    'completed',
    'discarded',
    'cancelled'
);


ALTER TYPE public.oban_job_state OWNER TO forrozin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categorias; Type: TABLE; Schema: public; Owner: forrozin
--

CREATE TABLE public.categorias (
    id uuid NOT NULL,
    name character varying(255) NOT NULL,
    label character varying(255) NOT NULL,
    color character varying(255) NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


ALTER TABLE public.categorias OWNER TO forrozin;

--
-- Name: conceitos_passos; Type: TABLE; Schema: public; Owner: forrozin
--

CREATE TABLE public.conceitos_passos (
    conceito_id uuid NOT NULL,
    passo_id uuid NOT NULL
);


ALTER TABLE public.conceitos_passos OWNER TO forrozin;

--
-- Name: conceitos_tecnicos; Type: TABLE; Schema: public; Owner: forrozin
--

CREATE TABLE public.conceitos_tecnicos (
    id uuid NOT NULL,
    title character varying(255) NOT NULL,
    description text NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


ALTER TABLE public.conceitos_tecnicos OWNER TO forrozin;

--
-- Name: conexoes_passos; Type: TABLE; Schema: public; Owner: forrozin
--

CREATE TABLE public.conexoes_passos (
    id uuid NOT NULL,
    type character varying(255) NOT NULL,
    source_step_id uuid NOT NULL,
    target_step_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    label character varying(255),
    description text
);


ALTER TABLE public.conexoes_passos OWNER TO forrozin;

--
-- Name: oban_jobs; Type: TABLE; Schema: public; Owner: forrozin
--

CREATE TABLE public.oban_jobs (
    id bigint NOT NULL,
    state public.oban_job_state DEFAULT 'available'::public.oban_job_state NOT NULL,
    queue text DEFAULT 'default'::text NOT NULL,
    worker text NOT NULL,
    args jsonb DEFAULT '{}'::jsonb NOT NULL,
    errors jsonb[] DEFAULT ARRAY[]::jsonb[] NOT NULL,
    attempt integer DEFAULT 0 NOT NULL,
    max_attempts integer DEFAULT 20 NOT NULL,
    inserted_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    scheduled_at timestamp without time zone DEFAULT timezone('UTC'::text, now()) NOT NULL,
    attempted_at timestamp without time zone,
    completed_at timestamp without time zone,
    attempted_by text[],
    discarded_at timestamp without time zone,
    priority integer DEFAULT 0 NOT NULL,
    tags text[] DEFAULT ARRAY[]::text[],
    meta jsonb DEFAULT '{}'::jsonb,
    cancelled_at timestamp without time zone,
    CONSTRAINT attempt_range CHECK (((attempt >= 0) AND (attempt <= max_attempts))),
    CONSTRAINT positive_max_attempts CHECK ((max_attempts > 0)),
    CONSTRAINT queue_length CHECK (((char_length(queue) > 0) AND (char_length(queue) < 128))),
    CONSTRAINT worker_length CHECK (((char_length(worker) > 0) AND (char_length(worker) < 128)))
);


ALTER TABLE public.oban_jobs OWNER TO forrozin;

--
-- Name: TABLE oban_jobs; Type: COMMENT; Schema: public; Owner: forrozin
--

COMMENT ON TABLE public.oban_jobs IS '12';


--
-- Name: oban_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: forrozin
--

CREATE SEQUENCE public.oban_jobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.oban_jobs_id_seq OWNER TO forrozin;

--
-- Name: oban_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: forrozin
--

ALTER SEQUENCE public.oban_jobs_id_seq OWNED BY public.oban_jobs.id;


--
-- Name: oban_peers; Type: TABLE; Schema: public; Owner: forrozin
--

CREATE UNLOGGED TABLE public.oban_peers (
    name text NOT NULL,
    node text NOT NULL,
    started_at timestamp without time zone NOT NULL,
    expires_at timestamp without time zone NOT NULL
);


ALTER TABLE public.oban_peers OWNER TO forrozin;

--
-- Name: passos; Type: TABLE; Schema: public; Owner: forrozin
--

CREATE TABLE public.passos (
    id uuid NOT NULL,
    code character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    note text,
    wip boolean DEFAULT false NOT NULL,
    image_path character varying(255),
    status character varying(255) DEFAULT 'publicado'::character varying NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    category_id uuid,
    section_id uuid,
    subsection_id uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


ALTER TABLE public.passos OWNER TO forrozin;

--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: forrozin
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


ALTER TABLE public.schema_migrations OWNER TO forrozin;

--
-- Name: secoes; Type: TABLE; Schema: public; Owner: forrozin
--

CREATE TABLE public.secoes (
    id uuid NOT NULL,
    num integer,
    title character varying(255) NOT NULL,
    code character varying(255),
    description text,
    note text,
    "position" integer DEFAULT 0 NOT NULL,
    category_id uuid,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


ALTER TABLE public.secoes OWNER TO forrozin;

--
-- Name: subsecoes; Type: TABLE; Schema: public; Owner: forrozin
--

CREATE TABLE public.subsecoes (
    id uuid NOT NULL,
    title character varying(255) NOT NULL,
    note text,
    "position" integer DEFAULT 0 NOT NULL,
    section_id uuid NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL
);


ALTER TABLE public.subsecoes OWNER TO forrozin;

--
-- Name: usuarios; Type: TABLE; Schema: public; Owner: forrozin
--

CREATE TABLE public.usuarios (
    id uuid NOT NULL,
    username character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role character varying(255) DEFAULT 'user'::character varying NOT NULL,
    inserted_at timestamp(0) without time zone NOT NULL,
    updated_at timestamp(0) without time zone NOT NULL,
    email character varying(255),
    confirmation_token character varying(255),
    confirmed_at timestamp(0) without time zone
);


ALTER TABLE public.usuarios OWNER TO forrozin;

--
-- Name: oban_jobs id; Type: DEFAULT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.oban_jobs ALTER COLUMN id SET DEFAULT nextval('public.oban_jobs_id_seq'::regclass);


--
-- Name: categorias categorias_pkey; Type: CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.categorias
    ADD CONSTRAINT categorias_pkey PRIMARY KEY (id);


--
-- Name: conceitos_tecnicos conceitos_tecnicos_pkey; Type: CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.conceitos_tecnicos
    ADD CONSTRAINT conceitos_tecnicos_pkey PRIMARY KEY (id);


--
-- Name: conexoes_passos conexoes_passos_pkey; Type: CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.conexoes_passos
    ADD CONSTRAINT conexoes_passos_pkey PRIMARY KEY (id);


--
-- Name: oban_jobs non_negative_priority; Type: CHECK CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE public.oban_jobs
    ADD CONSTRAINT non_negative_priority CHECK ((priority >= 0)) NOT VALID;


--
-- Name: oban_jobs oban_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.oban_jobs
    ADD CONSTRAINT oban_jobs_pkey PRIMARY KEY (id);


--
-- Name: oban_peers oban_peers_pkey; Type: CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.oban_peers
    ADD CONSTRAINT oban_peers_pkey PRIMARY KEY (name);


--
-- Name: passos passos_pkey; Type: CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.passos
    ADD CONSTRAINT passos_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: secoes secoes_pkey; Type: CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.secoes
    ADD CONSTRAINT secoes_pkey PRIMARY KEY (id);


--
-- Name: subsecoes subsecoes_pkey; Type: CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.subsecoes
    ADD CONSTRAINT subsecoes_pkey PRIMARY KEY (id);


--
-- Name: usuarios usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);


--
-- Name: categorias_name_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE UNIQUE INDEX categorias_name_index ON public.categorias USING btree (name);


--
-- Name: conceitos_passos_conceito_id_passo_id_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE UNIQUE INDEX conceitos_passos_conceito_id_passo_id_index ON public.conceitos_passos USING btree (conceito_id, passo_id);


--
-- Name: conceitos_tecnicos_titulo_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE UNIQUE INDEX conceitos_tecnicos_titulo_index ON public.conceitos_tecnicos USING btree (title);


--
-- Name: conexoes_passos_passo_destino_id_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE INDEX conexoes_passos_passo_destino_id_index ON public.conexoes_passos USING btree (target_step_id);


--
-- Name: conexoes_passos_passo_origem_id_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE INDEX conexoes_passos_passo_origem_id_index ON public.conexoes_passos USING btree (source_step_id);


--
-- Name: conexoes_passos_source_step_id_target_step_id_type_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE UNIQUE INDEX conexoes_passos_source_step_id_target_step_id_type_index ON public.conexoes_passos USING btree (source_step_id, target_step_id, type);


--
-- Name: oban_jobs_args_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE INDEX oban_jobs_args_index ON public.oban_jobs USING gin (args);


--
-- Name: oban_jobs_meta_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE INDEX oban_jobs_meta_index ON public.oban_jobs USING gin (meta);


--
-- Name: oban_jobs_state_queue_priority_scheduled_at_id_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE INDEX oban_jobs_state_queue_priority_scheduled_at_id_index ON public.oban_jobs USING btree (state, queue, priority, scheduled_at, id);


--
-- Name: passos_categoria_id_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE INDEX passos_categoria_id_index ON public.passos USING btree (category_id);


--
-- Name: passos_code_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE UNIQUE INDEX passos_code_index ON public.passos USING btree (code);


--
-- Name: passos_secao_id_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE INDEX passos_secao_id_index ON public.passos USING btree (section_id);


--
-- Name: passos_status_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE INDEX passos_status_index ON public.passos USING btree (status);


--
-- Name: passos_subsecao_id_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE INDEX passos_subsecao_id_index ON public.passos USING btree (subsection_id);


--
-- Name: passos_wip_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE INDEX passos_wip_index ON public.passos USING btree (wip);


--
-- Name: secoes_categoria_id_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE INDEX secoes_categoria_id_index ON public.secoes USING btree (category_id);


--
-- Name: secoes_posicao_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE INDEX secoes_posicao_index ON public.secoes USING btree ("position");


--
-- Name: subsecoes_posicao_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE INDEX subsecoes_posicao_index ON public.subsecoes USING btree ("position");


--
-- Name: subsecoes_secao_id_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE INDEX subsecoes_secao_id_index ON public.subsecoes USING btree (section_id);


--
-- Name: usuarios_confirmation_token_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE UNIQUE INDEX usuarios_confirmation_token_index ON public.usuarios USING btree (confirmation_token);


--
-- Name: usuarios_email_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE UNIQUE INDEX usuarios_email_index ON public.usuarios USING btree (email);


--
-- Name: usuarios_username_index; Type: INDEX; Schema: public; Owner: forrozin
--

CREATE UNIQUE INDEX usuarios_username_index ON public.usuarios USING btree (username);


--
-- Name: conceitos_passos conceitos_passos_conceito_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.conceitos_passos
    ADD CONSTRAINT conceitos_passos_conceito_id_fkey FOREIGN KEY (conceito_id) REFERENCES public.conceitos_tecnicos(id) ON DELETE CASCADE;


--
-- Name: conceitos_passos conceitos_passos_passo_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.conceitos_passos
    ADD CONSTRAINT conceitos_passos_passo_id_fkey FOREIGN KEY (passo_id) REFERENCES public.passos(id) ON DELETE CASCADE;


--
-- Name: conexoes_passos conexoes_passos_passo_destino_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.conexoes_passos
    ADD CONSTRAINT conexoes_passos_passo_destino_id_fkey FOREIGN KEY (target_step_id) REFERENCES public.passos(id) ON DELETE CASCADE;


--
-- Name: conexoes_passos conexoes_passos_passo_origem_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.conexoes_passos
    ADD CONSTRAINT conexoes_passos_passo_origem_id_fkey FOREIGN KEY (source_step_id) REFERENCES public.passos(id) ON DELETE CASCADE;


--
-- Name: passos passos_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.passos
    ADD CONSTRAINT passos_categoria_id_fkey FOREIGN KEY (category_id) REFERENCES public.categorias(id) ON DELETE RESTRICT;


--
-- Name: passos passos_secao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.passos
    ADD CONSTRAINT passos_secao_id_fkey FOREIGN KEY (section_id) REFERENCES public.secoes(id) ON DELETE RESTRICT;


--
-- Name: passos passos_subsecao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.passos
    ADD CONSTRAINT passos_subsecao_id_fkey FOREIGN KEY (subsection_id) REFERENCES public.subsecoes(id) ON DELETE SET NULL;


--
-- Name: secoes secoes_categoria_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.secoes
    ADD CONSTRAINT secoes_categoria_id_fkey FOREIGN KEY (category_id) REFERENCES public.categorias(id) ON DELETE RESTRICT;


--
-- Name: subsecoes subsecoes_secao_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: forrozin
--

ALTER TABLE ONLY public.subsecoes
    ADD CONSTRAINT subsecoes_secao_id_fkey FOREIGN KEY (section_id) REFERENCES public.secoes(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

