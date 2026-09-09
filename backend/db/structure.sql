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
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: currency_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.currency_enum AS ENUM (
    'usd',
    'ars'
);


--
-- Name: day_of_week_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.day_of_week_enum AS ENUM (
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
);


--
-- Name: gift_status_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.gift_status_enum AS ENUM (
    'pending',
    'redeemed',
    'expired',
    'cancelled'
);


--
-- Name: gift_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.gift_type_enum AS ENUM (
    'classic',
    'gold',
    'black',
    'platinum'
);


--
-- Name: merchant_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.merchant_type_enum AS ENUM (
    'restaurant',
    'cafe',
    'bar',
    'dark_kitchen',
    'pizzeria',
    'brewery',
    'food_truck',
    'other'
);


--
-- Name: reward_type_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.reward_type_enum AS ENUM (
    'discount_percent',
    'free_item',
    'cashback',
    'other'
);


--
-- Name: theme_enum; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.theme_enum AS ENUM (
    'light',
    'dark',
    'system'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

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
-- Name: business_hours; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.business_hours (
    id bigint NOT NULL,
    merchant_id bigint NOT NULL,
    day_of_week public.day_of_week_enum NOT NULL,
    opens_at time without time zone,
    closes_at time without time zone,
    closed boolean DEFAULT false NOT NULL
);


--
-- Name: business_hours_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.business_hours_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: business_hours_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.business_hours_id_seq OWNED BY public.business_hours.id;


--
-- Name: consumer_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consumer_settings (
    id bigint NOT NULL,
    consumer_id uuid NOT NULL,
    theme public.theme_enum DEFAULT 'system'::public.theme_enum NOT NULL,
    notifications_enabled boolean DEFAULT true NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid
);


--
-- Name: consumer_settings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.consumer_settings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: consumer_settings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.consumer_settings_id_seq OWNED BY public.consumer_settings.id;


--
-- Name: consumers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consumers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    first_name character varying(100) NOT NULL,
    last_name character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    dni_encrypted text,
    dni_bidx character varying(255),
    phone character varying(30),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


--
-- Name: favorites; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.favorites (
    id bigint NOT NULL,
    consumer_id uuid NOT NULL,
    merchant_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid NOT NULL,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


--
-- Name: favorites_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.favorites_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: favorites_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.favorites_id_seq OWNED BY public.favorites.id;


--
-- Name: gifts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gifts (
    id bigint NOT NULL,
    sender_consumer_id uuid NOT NULL,
    recipient_consumer_id uuid,
    type public.gift_type_enum NOT NULL,
    amount numeric(10,2) NOT NULL,
    recipient_phone character varying(30) NOT NULL,
    message text,
    expires_at timestamp with time zone NOT NULL,
    status public.gift_status_enum DEFAULT 'pending'::public.gift_status_enum NOT NULL,
    status_updated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


--
-- Name: gifts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gifts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gifts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gifts_id_seq OWNED BY public.gifts.id;


--
-- Name: loyalty_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.loyalty_rules (
    id bigint NOT NULL,
    merchant_id bigint NOT NULL,
    visits_required integer NOT NULL,
    reward_type public.reward_type_enum NOT NULL,
    reward_description text NOT NULL,
    is_permanent boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


--
-- Name: loyalty_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.loyalty_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: loyalty_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.loyalty_rules_id_seq OWNED BY public.loyalty_rules.id;


--
-- Name: menu_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_items (
    id bigint NOT NULL,
    merchant_id bigint NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    price numeric(10,2) NOT NULL,
    currency public.currency_enum NOT NULL,
    section character varying(100),
    image_url text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


--
-- Name: menu_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.menu_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: menu_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.menu_items_id_seq OWNED BY public.menu_items.id;


--
-- Name: menu_items_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.menu_items_tags (
    id bigint NOT NULL,
    menu_item_id bigint NOT NULL,
    tag_id bigint NOT NULL
);


--
-- Name: menu_items_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.menu_items_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: menu_items_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.menu_items_tags_id_seq OWNED BY public.menu_items_tags.id;


--
-- Name: merchants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.merchants (
    id bigint NOT NULL,
    name character varying(200) NOT NULL,
    type public.merchant_type_enum NOT NULL,
    address character varying(255) NOT NULL,
    country character varying(100) NOT NULL,
    state character varying(100) NOT NULL,
    city character varying(100) NOT NULL,
    neighborhood character varying(100),
    zip_code character varying(20),
    latitude numeric(9,6) NOT NULL,
    longitude numeric(9,6) NOT NULL,
    cover_image_url text,
    whatsapp_number character varying(30),
    delivery_url text,
    price_per_person_min numeric(10,2),
    price_per_person_max numeric(10,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


--
-- Name: merchants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.merchants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: merchants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.merchants_id_seq OWNED BY public.merchants.id;


--
-- Name: merchants_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.merchants_tags (
    id bigint NOT NULL,
    merchant_id bigint NOT NULL,
    tag_id bigint NOT NULL
);


--
-- Name: merchants_tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.merchants_tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: merchants_tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.merchants_tags_id_seq OWNED BY public.merchants_tags.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: search_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_history (
    id bigint NOT NULL,
    consumer_id uuid NOT NULL,
    query_text text NOT NULL,
    structured_output jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


--
-- Name: search_history_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.search_history_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: search_history_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.search_history_id_seq OWNED BY public.search_history.id;


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: tags_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.tags_id_seq OWNED BY public.tags.id;


--
-- Name: visit_summaries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visit_summaries (
    id bigint NOT NULL,
    consumer_id uuid NOT NULL,
    merchant_id bigint NOT NULL,
    count integer DEFAULT 0 NOT NULL,
    current_tier character varying(100),
    last_visit_at timestamp with time zone
);


--
-- Name: visit_summaries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visit_summaries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visit_summaries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visit_summaries_id_seq OWNED BY public.visit_summaries.id;


--
-- Name: visits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.visits (
    id bigint NOT NULL,
    consumer_id uuid NOT NULL,
    merchant_id bigint NOT NULL,
    amount numeric(10,2) NOT NULL,
    reward_applied boolean DEFAULT false NOT NULL,
    reward_description_snapshot text,
    visited_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid,
    deleted_at timestamp with time zone,
    deleted_by uuid
);


--
-- Name: visits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.visits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: visits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.visits_id_seq OWNED BY public.visits.id;


--
-- Name: business_hours id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.business_hours ALTER COLUMN id SET DEFAULT nextval('public.business_hours_id_seq'::regclass);


--
-- Name: consumer_settings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consumer_settings ALTER COLUMN id SET DEFAULT nextval('public.consumer_settings_id_seq'::regclass);


--
-- Name: favorites id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites ALTER COLUMN id SET DEFAULT nextval('public.favorites_id_seq'::regclass);


--
-- Name: gifts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gifts ALTER COLUMN id SET DEFAULT nextval('public.gifts_id_seq'::regclass);


--
-- Name: loyalty_rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_rules ALTER COLUMN id SET DEFAULT nextval('public.loyalty_rules_id_seq'::regclass);


--
-- Name: menu_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items ALTER COLUMN id SET DEFAULT nextval('public.menu_items_id_seq'::regclass);


--
-- Name: menu_items_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items_tags ALTER COLUMN id SET DEFAULT nextval('public.menu_items_tags_id_seq'::regclass);


--
-- Name: merchants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merchants ALTER COLUMN id SET DEFAULT nextval('public.merchants_id_seq'::regclass);


--
-- Name: merchants_tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merchants_tags ALTER COLUMN id SET DEFAULT nextval('public.merchants_tags_id_seq'::regclass);


--
-- Name: search_history id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_history ALTER COLUMN id SET DEFAULT nextval('public.search_history_id_seq'::regclass);


--
-- Name: tags id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags ALTER COLUMN id SET DEFAULT nextval('public.tags_id_seq'::regclass);


--
-- Name: visit_summaries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visit_summaries ALTER COLUMN id SET DEFAULT nextval('public.visit_summaries_id_seq'::regclass);


--
-- Name: visits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visits ALTER COLUMN id SET DEFAULT nextval('public.visits_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: business_hours business_hours_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.business_hours
    ADD CONSTRAINT business_hours_pkey PRIMARY KEY (id);


--
-- Name: consumer_settings consumer_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consumer_settings
    ADD CONSTRAINT consumer_settings_pkey PRIMARY KEY (id);


--
-- Name: consumers consumers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consumers
    ADD CONSTRAINT consumers_pkey PRIMARY KEY (id);


--
-- Name: favorites favorites_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT favorites_pkey PRIMARY KEY (id);


--
-- Name: gifts gifts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gifts
    ADD CONSTRAINT gifts_pkey PRIMARY KEY (id);


--
-- Name: loyalty_rules loyalty_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_rules
    ADD CONSTRAINT loyalty_rules_pkey PRIMARY KEY (id);


--
-- Name: menu_items menu_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT menu_items_pkey PRIMARY KEY (id);


--
-- Name: menu_items_tags menu_items_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items_tags
    ADD CONSTRAINT menu_items_tags_pkey PRIMARY KEY (id);


--
-- Name: merchants merchants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merchants
    ADD CONSTRAINT merchants_pkey PRIMARY KEY (id);


--
-- Name: merchants_tags merchants_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merchants_tags
    ADD CONSTRAINT merchants_tags_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: search_history search_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_history
    ADD CONSTRAINT search_history_pkey PRIMARY KEY (id);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: visit_summaries visit_summaries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visit_summaries
    ADD CONSTRAINT visit_summaries_pkey PRIMARY KEY (id);


--
-- Name: visits visits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT visits_pkey PRIMARY KEY (id);


--
-- Name: idx_business_hours_merchant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_business_hours_merchant_id ON public.business_hours USING btree (merchant_id);


--
-- Name: idx_consumers_dni_bidx; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_consumers_dni_bidx ON public.consumers USING btree (dni_bidx);


--
-- Name: idx_menu_items_merchant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_menu_items_merchant_id ON public.menu_items USING btree (merchant_id);


--
-- Name: idx_merchants_geo; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_merchants_geo ON public.merchants USING btree (latitude, longitude);


--
-- Name: idx_merchants_neighborhood; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_merchants_neighborhood ON public.merchants USING btree (neighborhood);


--
-- Name: idx_merchants_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_merchants_type ON public.merchants USING btree (type);


--
-- Name: idx_search_history_consumer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_search_history_consumer_id ON public.search_history USING btree (consumer_id);


--
-- Name: idx_visits_consumer_merchant; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_visits_consumer_merchant ON public.visits USING btree (consumer_id, merchant_id);


--
-- Name: idx_visits_visited_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_visits_visited_at ON public.visits USING btree (visited_at);


--
-- Name: index_consumer_settings_on_consumer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_consumer_settings_on_consumer_id ON public.consumer_settings USING btree (consumer_id);


--
-- Name: index_consumers_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_consumers_on_email ON public.consumers USING btree (email);


--
-- Name: index_favorites_on_consumer_id_and_merchant_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_favorites_on_consumer_id_and_merchant_id ON public.favorites USING btree (consumer_id, merchant_id);


--
-- Name: index_menu_items_tags_on_menu_item_id_and_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_menu_items_tags_on_menu_item_id_and_tag_id ON public.menu_items_tags USING btree (menu_item_id, tag_id);


--
-- Name: index_merchants_tags_on_merchant_id_and_tag_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_merchants_tags_on_merchant_id_and_tag_id ON public.merchants_tags USING btree (merchant_id, tag_id);


--
-- Name: index_visit_summaries_on_merchant_id_and_consumer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_visit_summaries_on_merchant_id_and_consumer_id ON public.visit_summaries USING btree (merchant_id, consumer_id);


--
-- Name: search_history fk_rails_0452b21068; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_history
    ADD CONSTRAINT fk_rails_0452b21068 FOREIGN KEY (consumer_id) REFERENCES public.consumers(id);


--
-- Name: menu_items fk_rails_138a6e8af5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items
    ADD CONSTRAINT fk_rails_138a6e8af5 FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: gifts fk_rails_1c30aba263; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gifts
    ADD CONSTRAINT fk_rails_1c30aba263 FOREIGN KEY (recipient_consumer_id) REFERENCES public.consumers(id);


--
-- Name: consumer_settings fk_rails_3c06061050; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consumer_settings
    ADD CONSTRAINT fk_rails_3c06061050 FOREIGN KEY (consumer_id) REFERENCES public.consumers(id);


--
-- Name: loyalty_rules fk_rails_59e828b505; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.loyalty_rules
    ADD CONSTRAINT fk_rails_59e828b505 FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: merchants_tags fk_rails_5b9f08883f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merchants_tags
    ADD CONSTRAINT fk_rails_5b9f08883f FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: menu_items_tags fk_rails_63fd1d9b9f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items_tags
    ADD CONSTRAINT fk_rails_63fd1d9b9f FOREIGN KEY (menu_item_id) REFERENCES public.menu_items(id);


--
-- Name: business_hours fk_rails_67aaf1af6b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.business_hours
    ADD CONSTRAINT fk_rails_67aaf1af6b FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: visits fk_rails_7f047422ae; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT fk_rails_7f047422ae FOREIGN KEY (consumer_id) REFERENCES public.consumers(id);


--
-- Name: gifts fk_rails_8ba6d6f5ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gifts
    ADD CONSTRAINT fk_rails_8ba6d6f5ca FOREIGN KEY (sender_consumer_id) REFERENCES public.consumers(id);


--
-- Name: favorites fk_rails_8cfb8e4b8d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT fk_rails_8cfb8e4b8d FOREIGN KEY (consumer_id) REFERENCES public.consumers(id);


--
-- Name: visits fk_rails_9fdce1ab26; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visits
    ADD CONSTRAINT fk_rails_9fdce1ab26 FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: visit_summaries fk_rails_ad46aa942a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visit_summaries
    ADD CONSTRAINT fk_rails_ad46aa942a FOREIGN KEY (consumer_id) REFERENCES public.consumers(id);


--
-- Name: visit_summaries fk_rails_b6b1fc8f2d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.visit_summaries
    ADD CONSTRAINT fk_rails_b6b1fc8f2d FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: favorites fk_rails_cb0119ea7d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.favorites
    ADD CONSTRAINT fk_rails_cb0119ea7d FOREIGN KEY (merchant_id) REFERENCES public.merchants(id);


--
-- Name: menu_items_tags fk_rails_cb7eb75721; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.menu_items_tags
    ADD CONSTRAINT fk_rails_cb7eb75721 FOREIGN KEY (tag_id) REFERENCES public.tags(id);


--
-- Name: merchants_tags fk_rails_f1217ff7e9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.merchants_tags
    ADD CONSTRAINT fk_rails_f1217ff7e9 FOREIGN KEY (tag_id) REFERENCES public.tags(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260909071702'),
('20260908122100'),
('20260908122000'),
('20260908121900'),
('20260908121800'),
('20260908121700'),
('20260908121600'),
('20260908121500'),
('20260908121400'),
('20260908121300'),
('20260908121200'),
('20260908121100'),
('20260908121000'),
('20260908120900'),
('20260908120800'),
('20260908120700'),
('20260908120600'),
('20260908120500'),
('20260908120400'),
('20260908120300'),
('20260908120200'),
('20260908120100'),
('20260908120000');

