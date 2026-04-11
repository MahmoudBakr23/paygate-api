SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

-- *not* creating schema, since initdb creates it


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: api_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_keys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    merchant_id uuid NOT NULL,
    environment character varying NOT NULL,
    public_key character varying NOT NULL,
    secret_key_digest character varying NOT NULL,
    key_prefix character varying NOT NULL,
    last_used_at timestamp(6) without time zone,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: charges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.charges (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    merchant_id uuid NOT NULL,
    amount integer NOT NULL,
    currency character varying(3) DEFAULT 'SAR'::character varying NOT NULL,
    payment_method character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    provider character varying NOT NULL,
    provider_charge_id character varying,
    idempotency_key character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    failure_code character varying,
    failure_message character varying,
    environment character varying NOT NULL,
    captured_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
)
PARTITION BY RANGE (created_at);


--
-- Name: charges_default; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.charges_default (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    merchant_id uuid NOT NULL,
    amount integer NOT NULL,
    currency character varying(3) DEFAULT 'SAR'::character varying NOT NULL,
    payment_method character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    provider character varying NOT NULL,
    provider_charge_id character varying,
    idempotency_key character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    failure_code character varying,
    failure_message character varying,
    environment character varying NOT NULL,
    captured_at timestamp without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: entity_ids; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.entity_ids (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    merchant_id uuid NOT NULL,
    brand character varying NOT NULL,
    environment character varying NOT NULL,
    entity_id character varying NOT NULL,
    created_at timestamp(6) without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: ledger_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ledger_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    merchant_id uuid NOT NULL,
    charge_id uuid,
    refund_id uuid,
    entry_type character varying NOT NULL,
    amount integer NOT NULL,
    currency character varying NOT NULL,
    description character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: merchants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.merchants (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    email character varying NOT NULL,
    password_digest character varying NOT NULL,
    environment character varying DEFAULT 'sandbox'::character varying NOT NULL,
    enabled_payment_methods character varying[] DEFAULT '{card,mada,apple_pay}'::character varying[],
    webhook_url character varying,
    webhook_secret character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: refunds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.refunds (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    charge_id uuid NOT NULL,
    merchant_id uuid NOT NULL,
    amount integer NOT NULL,
    reason character varying,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    provider_refund_id character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: webhook_deliveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_deliveries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    webhook_endpoint_id uuid NOT NULL,
    charge_id character varying,
    event_type character varying NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    http_status integer,
    attempts integer DEFAULT 0 NOT NULL,
    next_retry_at timestamp without time zone,
    delivered_at timestamp without time zone,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: webhook_endpoints; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_endpoints (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    merchant_id uuid NOT NULL,
    url character varying NOT NULL,
    events character varying[] DEFAULT '{charge.captured,charge.failed,refund.created}'::character varying[],
    active boolean DEFAULT true NOT NULL,
    webhook_secret character varying NOT NULL,
    created_at timestamp without time zone NOT NULL
);


--
-- Name: charges_default; Type: TABLE ATTACH; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges ATTACH PARTITION public.charges_default DEFAULT;


--
-- Name: api_keys api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: charges charges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges
    ADD CONSTRAINT charges_pkey PRIMARY KEY (id, created_at);


--
-- Name: charges_default charges_default_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.charges_default
    ADD CONSTRAINT charges_default_pkey PRIMARY KEY (id, created_at);


--
-- Name: entity_ids entity_ids_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_ids
    ADD CONSTRAINT entity_ids_pkey PRIMARY KEY (id);


--
-- Name: ledger_entries ledger_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT ledger_entries_pkey PRIMARY KEY (id);


--
-- Name: merchants merchants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merchants
    ADD CONSTRAINT merchants_pkey PRIMARY KEY (id);


--
-- Name: refunds refunds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refunds
    ADD CONSTRAINT refunds_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: webhook_deliveries webhook_deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_deliveries
    ADD CONSTRAINT webhook_deliveries_pkey PRIMARY KEY (id);


--
-- Name: webhook_endpoints webhook_endpoints_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_endpoints
    ADD CONSTRAINT webhook_endpoints_pkey PRIMARY KEY (id);


--
-- Name: index_charges_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_created_at ON ONLY public.charges USING btree (created_at);


--
-- Name: charges_default_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX charges_default_created_at_idx ON public.charges_default USING btree (created_at);


--
-- Name: index_charges_on_environment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_environment ON ONLY public.charges USING btree (environment);


--
-- Name: charges_default_environment_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX charges_default_environment_idx ON public.charges_default USING btree (environment);


--
-- Name: index_charges_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_idempotency_key ON ONLY public.charges USING btree (idempotency_key);


--
-- Name: charges_default_idempotency_key_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX charges_default_idempotency_key_idx ON public.charges_default USING btree (idempotency_key);


--
-- Name: index_charges_on_merchant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_merchant_id ON ONLY public.charges USING btree (merchant_id);


--
-- Name: charges_default_merchant_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX charges_default_merchant_id_idx ON public.charges_default USING btree (merchant_id);


--
-- Name: index_charges_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_charges_on_status ON ONLY public.charges USING btree (status);


--
-- Name: charges_default_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX charges_default_status_idx ON public.charges_default USING btree (status);


--
-- Name: index_api_keys_on_key_prefix; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_keys_on_key_prefix ON public.api_keys USING btree (key_prefix);


--
-- Name: index_api_keys_on_merchant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_keys_on_merchant_id ON public.api_keys USING btree (merchant_id);


--
-- Name: index_api_keys_on_merchant_id_and_environment; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_api_keys_on_merchant_id_and_environment ON public.api_keys USING btree (merchant_id, environment);


--
-- Name: index_api_keys_on_public_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_api_keys_on_public_key ON public.api_keys USING btree (public_key);


--
-- Name: index_entity_ids_on_merchant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_entity_ids_on_merchant_id ON public.entity_ids USING btree (merchant_id);


--
-- Name: index_entity_ids_on_merchant_id_and_brand_and_environment; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_entity_ids_on_merchant_id_and_brand_and_environment ON public.entity_ids USING btree (merchant_id, brand, environment);


--
-- Name: index_ledger_entries_on_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_charge_id ON public.ledger_entries USING btree (charge_id);


--
-- Name: index_ledger_entries_on_merchant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_merchant_id ON public.ledger_entries USING btree (merchant_id);


--
-- Name: index_ledger_entries_on_refund_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ledger_entries_on_refund_id ON public.ledger_entries USING btree (refund_id);


--
-- Name: index_merchants_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_merchants_on_email ON public.merchants USING btree (email);


--
-- Name: index_refunds_on_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_refunds_on_charge_id ON public.refunds USING btree (charge_id);


--
-- Name: index_refunds_on_merchant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_refunds_on_merchant_id ON public.refunds USING btree (merchant_id);


--
-- Name: index_refunds_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_refunds_on_status ON public.refunds USING btree (status);


--
-- Name: index_webhook_deliveries_on_charge_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_deliveries_on_charge_id ON public.webhook_deliveries USING btree (charge_id);


--
-- Name: index_webhook_deliveries_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_deliveries_on_status ON public.webhook_deliveries USING btree (status);


--
-- Name: index_webhook_deliveries_on_webhook_endpoint_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_deliveries_on_webhook_endpoint_id ON public.webhook_deliveries USING btree (webhook_endpoint_id);


--
-- Name: index_webhook_endpoints_on_merchant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_webhook_endpoints_on_merchant_id ON public.webhook_endpoints USING btree (merchant_id);


--
-- Name: charges_default_created_at_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_charges_on_created_at ATTACH PARTITION public.charges_default_created_at_idx;


--
-- Name: charges_default_environment_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_charges_on_environment ATTACH PARTITION public.charges_default_environment_idx;


--
-- Name: charges_default_idempotency_key_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_charges_on_idempotency_key ATTACH PARTITION public.charges_default_idempotency_key_idx;


--
-- Name: charges_default_merchant_id_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_charges_on_merchant_id ATTACH PARTITION public.charges_default_merchant_id_idx;


--
-- Name: charges_default_pkey; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.charges_pkey ATTACH PARTITION public.charges_default_pkey;


--
-- Name: charges_default_status_idx; Type: INDEX ATTACH; Schema: public; Owner: -
--

ALTER INDEX public.index_charges_on_status ATTACH PARTITION public.charges_default_status_idx;


--
-- Name: charges charges_merchant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE public.charges
    ADD CONSTRAINT charges_merchant_id_fkey FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: entity_ids fk_rails_030609164f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.entity_ids
    ADD CONSTRAINT fk_rails_030609164f FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: refunds fk_rails_0f0ec6083c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refunds
    ADD CONSTRAINT fk_rails_0f0ec6083c FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: api_keys fk_rails_28b436c585; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT fk_rails_28b436c585 FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: webhook_deliveries fk_rails_392378d371; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_deliveries
    ADD CONSTRAINT fk_rails_392378d371 FOREIGN KEY (webhook_endpoint_id) REFERENCES public.webhook_endpoints(id);


--
-- Name: webhook_endpoints fk_rails_46127e0e95; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_endpoints
    ADD CONSTRAINT fk_rails_46127e0e95 FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: ledger_entries fk_rails_9d29e663c8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ledger_entries
    ADD CONSTRAINT fk_rails_9d29e663c8 FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260411073425'),
('20260411071121'),
('20260411071116'),
('20260411065858'),
('20260411065857'),
('20260410234641'),
('20260409203911'),
('20260409203856');

