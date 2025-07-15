--
-- PostgreSQL database dump
--

-- Dumped from database version 17.4
-- Dumped by pg_dump version 17.4

-- Started on 2025-07-15 20:22:57

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
-- TOC entry 5004 (class 1262 OID 17266)
-- Name: Hackathon; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE "Hackathon" WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'it-IT';


ALTER DATABASE "Hackathon" OWNER TO postgres;

\connect "Hackathon"

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
-- TOC entry 230 (class 1255 OID 17433)
-- Name: aggiungi_giudice(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.aggiungi_giudice() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Controlla se lo stato dell'invito è diventato 'Accettato'
    IF NEW.Stato_invito = 'Accettato' THEN
        -- Inserisce il nuovo giudice, solo se non esiste già
        INSERT INTO GIUDICE (Username_utente, Titolo_hackathon)
        VALUES (NEW.Username_utente, NEW.Titolo_hackathon)
        ON CONFLICT DO NOTHING; -- evita errore se già presente
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.aggiungi_giudice() OWNER TO postgres;

--
-- TOC entry 245 (class 1255 OID 17441)
-- Name: elimina_team_incompleti(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.elimina_team_incompleti() RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
    hackathon_record RECORD;
BEGIN
    -- Trova solo gli hackathon la cui data di fine registrazione è OGGI
    FOR hackathon_record IN (
        SELECT h.Titolo_identificativo 
        FROM HACKATHON h 
        WHERE h.DataFine_registrazione = CURRENT_DATE
    ) LOOP
        -- Elimina direttamente i team con meno di 2 membri
        DELETE FROM TEAM t
        WHERE t.Titolo_hackathon = hackathon_record.Titolo_identificativo
        AND (
            SELECT COUNT(*) 
            FROM MEMBERSHIP m 
            WHERE m.Team_appartenenza = t.Nome_team 
              AND m.Titolo_hackathon = t.Titolo_hackathon
        ) < 2;
        
        RAISE NOTICE 'Eliminati tutti i team incompleti per l''hackathon "%"', 
                    hackathon_record.Titolo_identificativo;
    END LOOP;
    
    RETURN;
END;
$$;


ALTER FUNCTION public.elimina_team_incompleti() OWNER TO postgres;

--
-- TOC entry 247 (class 1255 OID 17444)
-- Name: genera_classifica_hackathon(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.genera_classifica_hackathon(titolo_hack character varying) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    classifica_text TEXT := '';
    team_record RECORD;
    posizione INTEGER := 1;
    data_fine_evento DATE;
    num_giudici INTEGER;
    num_team INTEGER;
    num_voti INTEGER;
    voti_attesi INTEGER;
BEGIN
    -- Verifica che l'hackathon esista
    IF NOT EXISTS (SELECT 1 FROM HACKATHON WHERE Titolo_identificativo = titolo_hack) THEN
        RETURN 'Errore: Hackathon non trovato';
    END IF;
    
    -- Recupera la data di fine evento dell'hackathon
    SELECT DataFine_evento INTO data_fine_evento
    FROM HACKATHON
    WHERE Titolo_identificativo = titolo_hack;
    
    -- Verifica che l'hackathon sia terminato
    IF CURRENT_DATE < data_fine_evento THEN
        RETURN 'Errore: Non è possibile generare la classifica prima della fine dell''hackathon';
    END IF;
    
    -- Conta il numero di giudici per questo hackathon
    SELECT COUNT(*) INTO num_giudici
    FROM GIUDICE
    WHERE Titolo_hackathon = titolo_hack;
    
    -- Conta il numero di team per questo hackathon
    SELECT COUNT(*) INTO num_team
    FROM TEAM
    WHERE Titolo_hackathon = titolo_hack;
    
    -- Conta il numero totale di voti espressi
    SELECT COUNT(*) INTO num_voti
    FROM VOTO
    WHERE Titolo_hackathon = titolo_hack;
    
    -- Calcola il numero di voti attesi (ogni giudice deve votare ogni team)
    voti_attesi := num_giudici * num_team;
    
    -- Verifica se tutti i giudici hanno espresso il proprio voto per tutti i team
    IF num_voti < voti_attesi THEN
        RETURN 'Errore: Non è possibile generare la classifica. Mancano ' || 
                (voti_attesi - num_voti) || ' voti su ' || voti_attesi || ' attesi. Tutti i giudici devono votare tutti i team.';
    END IF;
    
    -- Aggiorna il punteggio finale di ciascun team
    UPDATE TEAM t
    SET Punteggio_finale = (
        SELECT COALESCE(SUM(v.Punteggio), 0)
        FROM VOTO v
        WHERE v.Team_votato = t.Nome_team
          AND v.Titolo_hackathon = t.Titolo_hackathon
    )
    WHERE t.Titolo_hackathon = titolo_hack;
    
    -- Costruisce la stringa della classifica
    FOR team_record IN (
        SELECT Nome_team, Punteggio_finale
        FROM TEAM
        WHERE Titolo_hackathon = titolo_hack
        ORDER BY Punteggio_finale DESC, Nome_team ASC
    ) LOOP
        classifica_text := classifica_text || 
                          posizione || ' ' || 
                          team_record.Nome_team || ' ' || 
                          COALESCE(team_record.Punteggio_finale, 0) || E'\n';
        posizione := posizione + 1;
    END LOOP;
    
    -- Rimuovi l'ultimo carattere newline se la classifica non è vuota
    IF LENGTH(classifica_text) > 0 THEN
        classifica_text := SUBSTRING(classifica_text, 1, LENGTH(classifica_text) - 1);
    END IF;
    
    -- Aggiorna il campo Classifica nella tabella HACKATHON
    UPDATE HACKATHON
    SET Classifica = classifica_text
    WHERE Titolo_identificativo = titolo_hack;
    
    -- Registra l'utente e la data/ora di generazione della classifica
    RAISE NOTICE 'Classifica generata da % il % UTC', 
                 CURRENT_USER, TO_CHAR(CURRENT_TIMESTAMP AT TIME ZONE 'UTC', 'YYYY-MM-DD HH24:MI:SS');
    
    RETURN classifica_text;
END;
$$;


ALTER FUNCTION public.genera_classifica_hackathon(titolo_hack character varying) OWNER TO postgres;

--
-- TOC entry 243 (class 1255 OID 17437)
-- Name: verifica_adesione_valida(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.verifica_adesione_valida() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    data_fine_registrazione DATE;
    num_membri_attuali INTEGER;
    max_membri INTEGER;
BEGIN
    -- Recupera la data di fine registrazione dell'hackathon
    SELECT h.DataFine_registrazione
    INTO data_fine_registrazione
    FROM HACKATHON h
    WHERE h.Titolo_identificativo = NEW.Titolo_hackathon;

    -- Verifica se la data attuale è successiva alla data di fine registrazione
    IF CURRENT_DATE > data_fine_registrazione THEN
        RAISE EXCEPTION 'Non è possibile aderire al team: le registrazioni per l''hackathon "%" sono chiuse dal %',
                        NEW.Titolo_hackathon, data_fine_registrazione;
    END IF;

    -- Conta il numero di membri attuali nel team
    SELECT COUNT(*)
    INTO num_membri_attuali
    FROM MEMBERSHIP m
    WHERE m.Team_appartenenza = NEW.Team_appartenenza
    AND m.Titolo_hackathon = NEW.Titolo_hackathon;

    -- Recupera il numero massimo di membri per team dell'hackathon
    SELECT h.MaxNum_membriTeam
    INTO max_membri
    FROM HACKATHON h
    WHERE h.Titolo_identificativo = NEW.Titolo_hackathon;

    -- Verifica se il team è già al completo
    IF num_membri_attuali >= max_membri THEN
        RAISE EXCEPTION 'Non è possibile aderire al team "%": il team ha già raggiunto il numero massimo di membri (%)',
                        NEW.Team_appartenenza, max_membri;
    END IF;

    -- Se tutte le verifiche sono passate, permetti l'inserimento
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.verifica_adesione_valida() OWNER TO postgres;

--
-- TOC entry 229 (class 1255 OID 17431)
-- Name: verifica_data_adesione(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.verifica_data_adesione() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    data_inizio DATE;
    data_fine DATE;
BEGIN
    -- Recupera le date di registrazione dall'Hackathon associato al team
    SELECT h.DataInizio_registrazione, h.DataFine_registrazione
    INTO data_inizio, data_fine
    FROM HACKATHON h
    WHERE h.Titolo_identificativo = NEW.Titolo_hackathon;

    -- Verifica se la Data_adesione è compresa tra le due date
    IF NEW.Data_adesione < data_inizio OR NEW.Data_adesione > data_fine THEN
        RAISE EXCEPTION 'Data_adesione fuori dall''intervallo di registrazione dell''hackathon (% - %)', data_inizio, data_fine;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.verifica_data_adesione() OWNER TO postgres;

--
-- TOC entry 246 (class 1255 OID 17442)
-- Name: verifica_documento_caricato(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.verifica_documento_caricato() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    documenti_count INTEGER;
BEGIN
    -- Conta quanti documenti ha caricato il team
    SELECT COUNT(*)
    INTO documenti_count
    FROM DOCUMENTO d
    WHERE d.nome_team = NEW.team_votato
      AND d.Titolo_hackathon = NEW.Titolo_hackathon;

    -- Se il team non ha caricato alcun documento, impedisci l'inserimento del voto
    IF documenti_count = 0 THEN
        RAISE EXCEPTION 'Impossibile votare il team "%": non ha caricato alcun documento per l''hackathon "%"',
                        NEW.team_votato, NEW.Titolo_hackathon;
    END IF;

    -- Se la verifica è passata, permetti l'inserimento del voto
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.verifica_documento_caricato() OWNER TO postgres;

--
-- TOC entry 231 (class 1255 OID 17435)
-- Name: verifica_giudice_sovrapposizione(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.verifica_giudice_sovrapposizione() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    nuovo_inizio DATE;
    nuovo_fine DATE;
    conteggio INTEGER;
BEGIN
    -- Recupera le date dell'evento hackathon per cui l'utente sta diventando giudice
    SELECT h.DataInizio_evento, h.DataFine_evento
    INTO nuovo_inizio, nuovo_fine
    FROM HACKATHON h
    WHERE h.Titolo_identificativo = NEW.Titolo_hackathon;

    -- Verifica se l'utente è già giudice per un altro hackathon con date sovrapposte
    SELECT COUNT(*)
    INTO conteggio
    FROM GIUDICE g
    JOIN HACKATHON h ON g.Titolo_hackathon = h.Titolo_identificativo
    WHERE g.Username_utente = NEW.Username_utente
    AND g.Titolo_hackathon <> NEW.Titolo_hackathon
    AND (
        -- Verifica sovrapposizione date
        (h.DataInizio_evento <= nuovo_fine AND h.DataFine_evento >= nuovo_inizio)
    );

    -- Se c'è sovrapposizione, genera un errore
    IF conteggio > 0 THEN
        RAISE EXCEPTION 'L''utente % non può essere giudice per questo hackathon perché è già giudice per un hackathon con date sovrapposte', NEW.Username_utente;
    END IF;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.verifica_giudice_sovrapposizione() OWNER TO postgres;

--
-- TOC entry 244 (class 1255 OID 17439)
-- Name: verifica_max_membri_team(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.verifica_max_membri_team() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    num_membri_attuali INTEGER;
    max_membri INTEGER;
BEGIN
    -- Conta il numero di membri attuali nel team (includendo il nuovo membro)
    SELECT COUNT(*)
    INTO num_membri_attuali
    FROM MEMBERSHIP m
    WHERE m.Team_appartenenza = NEW.Team_appartenenza
      AND m.Titolo_hackathon = NEW.Titolo_hackathon;

    -- Incrementa di 1 per l'inserimento in corso
    num_membri_attuali := num_membri_attuali + 1;

    -- Recupera il numero massimo di membri per team dall'hackathon
    SELECT h.MaxNum_membriTeam
    INTO max_membri
    FROM HACKATHON h
    WHERE h.Titolo_identificativo = NEW.Titolo_hackathon;

    -- Verifica se l'aggiunta del nuovo membro supererebbe il limite
    IF num_membri_attuali > max_membri THEN
        RAISE EXCEPTION 'Impossibile aggiungere il membro al team "%": il numero massimo di membri consentito (%) sarebbe superato',
                        NEW.Team_appartenenza, max_membri;
    END IF;

    -- Se la verifica è passata, permetti l'inserimento
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.verifica_max_membri_team() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 223 (class 1259 OID 17322)
-- Name: documento; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.documento (
    id_documento integer NOT NULL,
    nome_team character varying(30) NOT NULL,
    titolo_hackathon character varying(30) NOT NULL,
    titolo_doc character varying(30) NOT NULL,
    contenuto text NOT NULL,
    data_stesura date
);


ALTER TABLE public.documento OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 17321)
-- Name: documento_id_documento_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.documento_id_documento_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.documento_id_documento_seq OWNER TO postgres;

--
-- TOC entry 5005 (class 0 OID 0)
-- Dependencies: 222
-- Name: documento_id_documento_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.documento_id_documento_seq OWNED BY public.documento.id_documento;


--
-- TOC entry 220 (class 1259 OID 17294)
-- Name: giudice; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.giudice (
    username_utente character varying(30) NOT NULL,
    titolo_hackathon character varying(30) NOT NULL
);


ALTER TABLE public.giudice OWNER TO postgres;

--
-- TOC entry 219 (class 1259 OID 17279)
-- Name: hackathon; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hackathon (
    titolo_identificativo character varying(30) NOT NULL,
    organizzatore character varying(30) NOT NULL,
    sede character varying(30) NOT NULL,
    classifica text,
    datainizio_registrazione date NOT NULL,
    datafine_registrazione date NOT NULL,
    datainizio_evento date NOT NULL,
    datafine_evento date NOT NULL,
    descrizione_problema text NOT NULL,
    numiscritti_corrente integer,
    maxnum_iscritti integer NOT NULL,
    maxnum_membriteam integer NOT NULL,
    CONSTRAINT hackathon_check CHECK ((datafine_registrazione <= (datainizio_evento - '2 days'::interval))),
    CONSTRAINT hackathon_check1 CHECK (((datafine_registrazione < datainizio_evento) AND (datainizio_registrazione < datainizio_evento))),
    CONSTRAINT hackathon_check2 CHECK (((datainizio_registrazione < datafine_registrazione) AND (datainizio_evento < datafine_evento)))
);


ALTER TABLE public.hackathon OWNER TO postgres;

--
-- TOC entry 228 (class 1259 OID 17409)
-- Name: invito_giudice; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.invito_giudice (
    username_organizzatore character varying(30) NOT NULL,
    username_utente character varying(30) NOT NULL,
    titolo_hackathon character varying(30) NOT NULL,
    data_invito date DEFAULT CURRENT_DATE NOT NULL,
    stato_invito character varying(20) NOT NULL,
    CONSTRAINT invito_giudice_stato_invito_check CHECK (((stato_invito)::text = ANY ((ARRAY['Inviato'::character varying, 'Accettato'::character varying, 'Rifiutato'::character varying])::text[])))
);


ALTER TABLE public.invito_giudice OWNER TO postgres;

--
-- TOC entry 225 (class 1259 OID 17336)
-- Name: membership; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.membership (
    id_adesione integer NOT NULL,
    username_utente character varying(30) NOT NULL,
    team_appartenenza character varying(30) NOT NULL,
    titolo_hackathon character varying(30) NOT NULL,
    data_adesione date NOT NULL
);


ALTER TABLE public.membership OWNER TO postgres;

--
-- TOC entry 224 (class 1259 OID 17335)
-- Name: membership_id_adesione_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.membership_id_adesione_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.membership_id_adesione_seq OWNER TO postgres;

--
-- TOC entry 5006 (class 0 OID 0)
-- Dependencies: 224
-- Name: membership_id_adesione_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.membership_id_adesione_seq OWNED BY public.membership.id_adesione;


--
-- TOC entry 217 (class 1259 OID 17267)
-- Name: organizzatore; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.organizzatore (
    username_org character varying(30) NOT NULL,
    password character varying(30) NOT NULL,
    CONSTRAINT chk_password_complexity CHECK (((length((password)::text) >= 8) AND ((password)::text ~ '[A-Z]'::text) AND ((password)::text ~ '[a-z]'::text) AND ((password)::text ~ '[0-9]'::text) AND ((password)::text ~ '[!@#$%^&*()\-_=+{};:,<.>/?]'::text)))
);


ALTER TABLE public.organizzatore OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 17309)
-- Name: team; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.team (
    nome_team character varying(30) NOT NULL,
    punteggio_finale integer,
    titolo_hackathon character varying(30) NOT NULL
);


ALTER TABLE public.team OWNER TO postgres;

--
-- TOC entry 218 (class 1259 OID 17273)
-- Name: utente; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.utente (
    username character varying(30) NOT NULL,
    password character varying(30) NOT NULL,
    CONSTRAINT chk_password_complexity CHECK (((length((password)::text) >= 8) AND ((password)::text ~ '[A-Z]'::text) AND ((password)::text ~ '[a-z]'::text) AND ((password)::text ~ '[0-9]'::text) AND ((password)::text ~ '[!@#$%^&*()\-_=+{};:,<.>/?]'::text)))
);


ALTER TABLE public.utente OWNER TO postgres;

--
-- TOC entry 227 (class 1259 OID 17387)
-- Name: valutazione; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.valutazione (
    id_documento integer,
    username_giudice character varying(30) NOT NULL,
    titolo_hackathon character varying(30) NOT NULL,
    team_valutato character varying(30) NOT NULL,
    valutazione_giudice text
);


ALTER TABLE public.valutazione OWNER TO postgres;

--
-- TOC entry 226 (class 1259 OID 17354)
-- Name: voto; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.voto (
    username_giudice character varying(30) NOT NULL,
    titolo_hackathon character varying(30) NOT NULL,
    team_votato character varying(30) NOT NULL,
    punteggio integer,
    CONSTRAINT voto_punteggio_check CHECK (((punteggio >= 0) AND (punteggio <= 10)))
);


ALTER TABLE public.voto OWNER TO postgres;

--
-- TOC entry 4787 (class 2604 OID 17325)
-- Name: documento id_documento; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documento ALTER COLUMN id_documento SET DEFAULT nextval('public.documento_id_documento_seq'::regclass);


--
-- TOC entry 4788 (class 2604 OID 17339)
-- Name: membership id_adesione; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.membership ALTER COLUMN id_adesione SET DEFAULT nextval('public.membership_id_adesione_seq'::regclass);


--
-- TOC entry 4993 (class 0 OID 17322)
-- Dependencies: 223
-- Data for Name: documento; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.documento (id_documento, nome_team, titolo_hackathon, titolo_doc, contenuto, data_stesura) FROM stdin;
\.


--
-- TOC entry 4990 (class 0 OID 17294)
-- Dependencies: 220
-- Data for Name: giudice; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.giudice (username_utente, titolo_hackathon) FROM stdin;
\.


--
-- TOC entry 4989 (class 0 OID 17279)
-- Dependencies: 219
-- Data for Name: hackathon; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hackathon (titolo_identificativo, organizzatore, sede, classifica, datainizio_registrazione, datafine_registrazione, datainizio_evento, datafine_evento, descrizione_problema, numiscritti_corrente, maxnum_iscritti, maxnum_membriteam) FROM stdin;
\.


--
-- TOC entry 4998 (class 0 OID 17409)
-- Dependencies: 228
-- Data for Name: invito_giudice; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.invito_giudice (username_organizzatore, username_utente, titolo_hackathon, data_invito, stato_invito) FROM stdin;
\.


--
-- TOC entry 4995 (class 0 OID 17336)
-- Dependencies: 225
-- Data for Name: membership; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.membership (id_adesione, username_utente, team_appartenenza, titolo_hackathon, data_adesione) FROM stdin;
\.


--
-- TOC entry 4987 (class 0 OID 17267)
-- Dependencies: 217
-- Data for Name: organizzatore; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.organizzatore (username_org, password) FROM stdin;
\.


--
-- TOC entry 4991 (class 0 OID 17309)
-- Dependencies: 221
-- Data for Name: team; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.team (nome_team, punteggio_finale, titolo_hackathon) FROM stdin;
\.


--
-- TOC entry 4988 (class 0 OID 17273)
-- Dependencies: 218
-- Data for Name: utente; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.utente (username, password) FROM stdin;
\.


--
-- TOC entry 4997 (class 0 OID 17387)
-- Dependencies: 227
-- Data for Name: valutazione; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.valutazione (id_documento, username_giudice, titolo_hackathon, team_valutato, valutazione_giudice) FROM stdin;
\.


--
-- TOC entry 4996 (class 0 OID 17354)
-- Dependencies: 226
-- Data for Name: voto; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.voto (username_giudice, titolo_hackathon, team_votato, punteggio) FROM stdin;
\.


--
-- TOC entry 5007 (class 0 OID 0)
-- Dependencies: 222
-- Name: documento_id_documento_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.documento_id_documento_seq', 1, false);


--
-- TOC entry 5008 (class 0 OID 0)
-- Dependencies: 224
-- Name: membership_id_adesione_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.membership_id_adesione_seq', 1, false);


--
-- TOC entry 4810 (class 2606 OID 17329)
-- Name: documento documento_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documento
    ADD CONSTRAINT documento_pkey PRIMARY KEY (id_documento);


--
-- TOC entry 4804 (class 2606 OID 17298)
-- Name: giudice giudice_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.giudice
    ADD CONSTRAINT giudice_pkey PRIMARY KEY (username_utente, titolo_hackathon);


--
-- TOC entry 4802 (class 2606 OID 17288)
-- Name: hackathon hackathon_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hackathon
    ADD CONSTRAINT hackathon_pkey PRIMARY KEY (titolo_identificativo);


--
-- TOC entry 4820 (class 2606 OID 17415)
-- Name: invito_giudice invito_giudice_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invito_giudice
    ADD CONSTRAINT invito_giudice_pkey PRIMARY KEY (username_utente, titolo_hackathon);


--
-- TOC entry 4812 (class 2606 OID 17341)
-- Name: membership membership_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.membership
    ADD CONSTRAINT membership_pkey PRIMARY KEY (id_adesione);


--
-- TOC entry 4814 (class 2606 OID 17343)
-- Name: membership membership_username_utente_team_appartenenza_titolo_hackath_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.membership
    ADD CONSTRAINT membership_username_utente_team_appartenenza_titolo_hackath_key UNIQUE (username_utente, team_appartenenza, titolo_hackathon);


--
-- TOC entry 4798 (class 2606 OID 17272)
-- Name: organizzatore organizzatore_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.organizzatore
    ADD CONSTRAINT organizzatore_pkey PRIMARY KEY (username_org);


--
-- TOC entry 4806 (class 2606 OID 17315)
-- Name: team team_nome_team_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_nome_team_key UNIQUE (nome_team);


--
-- TOC entry 4808 (class 2606 OID 17313)
-- Name: team team_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_pkey PRIMARY KEY (nome_team, titolo_hackathon);


--
-- TOC entry 4800 (class 2606 OID 17278)
-- Name: utente utente_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.utente
    ADD CONSTRAINT utente_pkey PRIMARY KEY (username);


--
-- TOC entry 4818 (class 2606 OID 17393)
-- Name: valutazione valutazione_id_documento_username_giudice_titolo_hackathon__key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.valutazione
    ADD CONSTRAINT valutazione_id_documento_username_giudice_titolo_hackathon__key UNIQUE (id_documento, username_giudice, titolo_hackathon, team_valutato);


--
-- TOC entry 4816 (class 2606 OID 17359)
-- Name: voto voto_username_giudice_titolo_hackathon_team_votato_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.voto
    ADD CONSTRAINT voto_username_giudice_titolo_hackathon_team_votato_key UNIQUE (username_giudice, titolo_hackathon, team_votato);


--
-- TOC entry 4841 (class 2620 OID 17434)
-- Name: invito_giudice trigger_aggiungi_giudice; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_aggiungi_giudice AFTER UPDATE ON public.invito_giudice FOR EACH ROW WHEN ((((old.stato_invito)::text IS DISTINCT FROM (new.stato_invito)::text) AND ((new.stato_invito)::text = 'Accettato'::text))) EXECUTE FUNCTION public.aggiungi_giudice();


--
-- TOC entry 4837 (class 2620 OID 17438)
-- Name: membership trigger_verifica_adesione_valida; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_verifica_adesione_valida BEFORE INSERT ON public.membership FOR EACH ROW EXECUTE FUNCTION public.verifica_adesione_valida();


--
-- TOC entry 4838 (class 2620 OID 17432)
-- Name: membership trigger_verifica_data_adesione; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_verifica_data_adesione BEFORE INSERT OR UPDATE ON public.membership FOR EACH ROW EXECUTE FUNCTION public.verifica_data_adesione();


--
-- TOC entry 4840 (class 2620 OID 17443)
-- Name: voto trigger_verifica_documento_caricato; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_verifica_documento_caricato BEFORE INSERT ON public.voto FOR EACH ROW EXECUTE FUNCTION public.verifica_documento_caricato();


--
-- TOC entry 4836 (class 2620 OID 17436)
-- Name: giudice trigger_verifica_giudice_sovrapposizione; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_verifica_giudice_sovrapposizione BEFORE INSERT OR UPDATE ON public.giudice FOR EACH ROW EXECUTE FUNCTION public.verifica_giudice_sovrapposizione();


--
-- TOC entry 4839 (class 2620 OID 17440)
-- Name: membership trigger_verifica_max_membri_team; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_verifica_max_membri_team BEFORE INSERT ON public.membership FOR EACH ROW EXECUTE FUNCTION public.verifica_max_membri_team();


--
-- TOC entry 4825 (class 2606 OID 17330)
-- Name: documento documento_nome_team_titolo_hackathon_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documento
    ADD CONSTRAINT documento_nome_team_titolo_hackathon_fkey FOREIGN KEY (nome_team, titolo_hackathon) REFERENCES public.team(nome_team, titolo_hackathon) ON DELETE CASCADE;


--
-- TOC entry 4822 (class 2606 OID 17304)
-- Name: giudice giudice_titolo_hackathon_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.giudice
    ADD CONSTRAINT giudice_titolo_hackathon_fkey FOREIGN KEY (titolo_hackathon) REFERENCES public.hackathon(titolo_identificativo) ON DELETE CASCADE;


--
-- TOC entry 4823 (class 2606 OID 17299)
-- Name: giudice giudice_username_utente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.giudice
    ADD CONSTRAINT giudice_username_utente_fkey FOREIGN KEY (username_utente) REFERENCES public.utente(username) ON DELETE CASCADE;


--
-- TOC entry 4821 (class 2606 OID 17289)
-- Name: hackathon hackathon_organizzatore_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hackathon
    ADD CONSTRAINT hackathon_organizzatore_fkey FOREIGN KEY (organizzatore) REFERENCES public.organizzatore(username_org) ON DELETE RESTRICT;


--
-- TOC entry 4833 (class 2606 OID 17426)
-- Name: invito_giudice invito_giudice_titolo_hackathon_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invito_giudice
    ADD CONSTRAINT invito_giudice_titolo_hackathon_fkey FOREIGN KEY (titolo_hackathon) REFERENCES public.hackathon(titolo_identificativo) ON DELETE CASCADE;


--
-- TOC entry 4834 (class 2606 OID 17416)
-- Name: invito_giudice invito_giudice_username_organizzatore_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invito_giudice
    ADD CONSTRAINT invito_giudice_username_organizzatore_fkey FOREIGN KEY (username_organizzatore) REFERENCES public.organizzatore(username_org) ON DELETE CASCADE;


--
-- TOC entry 4835 (class 2606 OID 17421)
-- Name: invito_giudice invito_giudice_username_utente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.invito_giudice
    ADD CONSTRAINT invito_giudice_username_utente_fkey FOREIGN KEY (username_utente) REFERENCES public.utente(username) ON DELETE CASCADE;


--
-- TOC entry 4826 (class 2606 OID 17349)
-- Name: membership membership_team_appartenenza_titolo_hackathon_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.membership
    ADD CONSTRAINT membership_team_appartenenza_titolo_hackathon_fkey FOREIGN KEY (team_appartenenza, titolo_hackathon) REFERENCES public.team(nome_team, titolo_hackathon) ON DELETE CASCADE;


--
-- TOC entry 4827 (class 2606 OID 17344)
-- Name: membership membership_username_utente_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.membership
    ADD CONSTRAINT membership_username_utente_fkey FOREIGN KEY (username_utente) REFERENCES public.utente(username) ON DELETE CASCADE;


--
-- TOC entry 4824 (class 2606 OID 17316)
-- Name: team team_titolo_hackathon_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_titolo_hackathon_fkey FOREIGN KEY (titolo_hackathon) REFERENCES public.hackathon(titolo_identificativo) ON DELETE CASCADE;


--
-- TOC entry 4830 (class 2606 OID 17394)
-- Name: valutazione valutazione_id_documento_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.valutazione
    ADD CONSTRAINT valutazione_id_documento_fkey FOREIGN KEY (id_documento) REFERENCES public.documento(id_documento) ON DELETE CASCADE;


--
-- TOC entry 4831 (class 2606 OID 17399)
-- Name: valutazione valutazione_team_valutato_titolo_hackathon_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.valutazione
    ADD CONSTRAINT valutazione_team_valutato_titolo_hackathon_fkey FOREIGN KEY (team_valutato, titolo_hackathon) REFERENCES public.team(nome_team, titolo_hackathon) ON DELETE CASCADE;


--
-- TOC entry 4832 (class 2606 OID 17404)
-- Name: valutazione valutazione_username_giudice_titolo_hackathon_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.valutazione
    ADD CONSTRAINT valutazione_username_giudice_titolo_hackathon_fkey FOREIGN KEY (username_giudice, titolo_hackathon) REFERENCES public.giudice(username_utente, titolo_hackathon) ON DELETE CASCADE;


--
-- TOC entry 4828 (class 2606 OID 17365)
-- Name: voto voto_team_votato_titolo_hackathon_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.voto
    ADD CONSTRAINT voto_team_votato_titolo_hackathon_fkey FOREIGN KEY (team_votato, titolo_hackathon) REFERENCES public.team(nome_team, titolo_hackathon) ON DELETE CASCADE;


--
-- TOC entry 4829 (class 2606 OID 17360)
-- Name: voto voto_username_giudice_titolo_hackathon_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.voto
    ADD CONSTRAINT voto_username_giudice_titolo_hackathon_fkey FOREIGN KEY (username_giudice, titolo_hackathon) REFERENCES public.giudice(username_utente, titolo_hackathon) ON DELETE CASCADE;


-- Completed on 2025-07-15 20:22:57

--
-- PostgreSQL database dump complete
--

