BEGIN;

/* Definizione tabella Organizzatore */
CREATE TABLE ORGANIZZATORE
(
    Username_org VARCHAR(30) PRIMARY KEY,
    Password VARCHAR(30) NOT NULL,
    -- Controllo validità password
    CONSTRAINT chk_password_complexity
    CHECK (
        -- Lunghezza minima 8 caratteri
        LENGTH(Password) >= 8 AND
        -- Almeno una lettera maiuscola
        Password ~ '[A-Z]' AND
        -- Almeno una lettera minuscola
        Password ~ '[a-z]' AND
        -- Almeno un numero
        Password ~ '[0-9]' AND
        -- Almeno un carattere speciale tra quelli consentiti
        Password ~ '[!@#$%^&*()\-_=+{};:,<.>/?]'
    )
);

CREATE TABLE UTENTE
(
    Username VARCHAR(30) PRIMARY KEY,
    Password VARCHAR(30) NOT NULL,
    -- Controllo validità password
    CONSTRAINT chk_password_complexity
    CHECK (
        -- Lunghezza minima 8 caratteri
        LENGTH(Password) >= 8 AND
        -- Almeno una lettera maiuscola
        Password ~ '[A-Z]' AND
        -- Almeno una lettera minuscola
        Password ~ '[a-z]' AND
        -- Almeno un numero
        Password ~ '[0-9]' AND
        -- Almeno un carattere speciale tra quelli consentiti
        Password ~ '[!@#$%^&*()\-_=+{};:,<.>/?]'
    )
);

CREATE TABLE HACKATHON
(
    Titolo_identificativo VARCHAR(30) PRIMARY KEY,
    Organizzatore VARCHAR(30) NOT NULL,
    Sede VARCHAR(30) NOT NULL,
    Classifica TEXT,
    DataInizio_registrazione DATE NOT NULL,
    DataFine_registrazione DATE NOT NULL,
    DataInizio_evento DATE NOT NULL,
    DataFine_evento DATE NOT NULL,
    Descrizione_problema TEXT NOT NULL,
    NumIscritti_corrente INTEGER,
    MaxNum_iscritti INTEGER NOT NULL,
    MaxNum_membriTeam INTEGER NOT NULL,

    FOREIGN KEY (Organizzatore) REFERENCES ORGANIZZATORE(Username_org) ON DELETE RESTRICT,

    -- Vincolo: la registrazione termina almeno 2 giorni prima dell'inizio dell'evento
    CHECK (DataFine_registrazione <= DataInizio_evento - INTERVAL '2 days'),

    -- Vincolo: l'intera registrazione deve avvenire prima dell'evento
    CHECK (DataFine_registrazione < DataInizio_evento AND DataInizio_registrazione < DataInizio_evento),

    -- Vincolo: le date devono risultare coerenti
    CHECK (DataInizio_registrazione < DataFine_registrazione AND DataInizio_evento < DataFine_evento)
);

CREATE TABLE GIUDICE
(
    Username_utente VARCHAR(30) NOT NULL,
    Titolo_hackathon VARCHAR(30) NOT NULL,

    PRIMARY KEY (Username_utente, Titolo_hackathon),

    FOREIGN KEY (Username_utente) REFERENCES UTENTE (Username)
        ON DELETE CASCADE,
    FOREIGN KEY (Titolo_hackathon) REFERENCES HACKATHON (Titolo_identificativo)
        ON DELETE CASCADE
);

CREATE TABLE TEAM
(
    Nome_team VARCHAR(30) UNIQUE NOT NULL,
    Punteggio_finale INTEGER,
    Titolo_hackathon VARCHAR(30) NOT NULL,

    PRIMARY KEY(Nome_team, Titolo_hackathon),

    FOREIGN KEY (Titolo_hackathon) REFERENCES HACKATHON (Titolo_identificativo)
        ON DELETE CASCADE
);

CREATE TABLE DOCUMENTO
(
    ID_documento SERIAL PRIMARY KEY,
    Nome_team VARCHAR(30) NOT NULL,
    Titolo_hackathon VARCHAR(30) NOT NULL,
    Titolo_doc VARCHAR(30) NOT NULL,
    Contenuto TEXT NOT NULL,
    -- MODIFICATO: Usiamo TIMESTAMPTZ per data e ora con fuso orario
    Data_stesura TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (Nome_team, Titolo_hackathon) REFERENCES TEAM (Nome_team, Titolo_hackathon)
        ON DELETE CASCADE
);

CREATE TABLE MEMBERSHIP
(
    ID_adesione SERIAL PRIMARY KEY,
    Username_utente VARCHAR(30) NOT NULL,
    Team_appartenenza VARCHAR(30) NOT NULL,
    Titolo_hackathon VARCHAR(30) NOT NULL,
    Data_adesione DATE NOT NULL,

    UNIQUE (Username_utente, Team_appartenenza, Titolo_hackathon),

    FOREIGN KEY (Username_utente) REFERENCES UTENTE (Username) ON DELETE CASCADE,
    FOREIGN KEY (Team_appartenenza, Titolo_hackathon) REFERENCES TEAM (Nome_team, Titolo_hackathon)
        ON DELETE CASCADE
);

CREATE TABLE VOTO
(
    Username_giudice VARCHAR(30) NOT NULL,
    Titolo_hackathon VARCHAR(30) NOT NULL,
    Team_votato VARCHAR(30) NOT NULL,
    Punteggio INTEGER,

    UNIQUE (Username_giudice, Titolo_hackathon, Team_votato),

    FOREIGN KEY (Username_giudice, Titolo_hackathon) REFERENCES GIUDICE (Username_utente, Titolo_hackathon) ON DELETE CASCADE,
    FOREIGN KEY (Team_votato, Titolo_hackathon) REFERENCES TEAM (Nome_team, Titolo_hackathon) ON DELETE CASCADE,

    CHECK (Punteggio >= 0 AND Punteggio <= 10)
);

CREATE TABLE VALUTAZIONE
(
    ID_documento INTEGER,
    Username_giudice VARCHAR(30) NOT NULL,
    Titolo_hackathon VARCHAR(30) NOT NULL,
    Team_valutato VARCHAR(30) NOT NULL,
    Valutazione_giudice TEXT,

    UNIQUE(ID_documento, Username_giudice, Titolo_hackathon, Team_valutato),

    FOREIGN KEY (ID_documento) REFERENCES DOCUMENTO (ID_documento) ON DELETE CASCADE,
    FOREIGN KEY (Team_valutato, Titolo_hackathon) REFERENCES TEAM (Nome_team, Titolo_hackathon) ON DELETE CASCADE,
    FOREIGN KEY (Username_giudice, Titolo_hackathon) REFERENCES GIUDICE(Username_utente, Titolo_hackathon) ON DELETE CASCADE
);

CREATE TABLE INVITO_GIUDICE
(
    Username_organizzatore VARCHAR(30) NOT NULL,
    Username_utente VARCHAR(30) NOT NULL,
    Titolo_hackathon VARCHAR(30) NOT NULL,
    Data_invito DATE NOT NULL DEFAULT CURRENT_DATE,
    Stato_invito VARCHAR(20) NOT NULL CHECK (Stato_invito IN ('Inviato', 'Accettato', 'Rifiutato')),

    PRIMARY KEY (Username_utente, Titolo_hackathon),

    FOREIGN KEY (Username_organizzatore) REFERENCES ORGANIZZATORE(Username_org) ON DELETE CASCADE,
    FOREIGN KEY (Username_utente) REFERENCES UTENTE(Username) ON DELETE CASCADE,
    FOREIGN KEY (Titolo_hackathon) REFERENCES HACKATHON(Titolo_identificativo) ON DELETE CASCADE
);

CREATE OR REPLACE FUNCTION aggiungi_giudice()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION verifica_giudice_sovrapposizione()
RETURNS TRIGGER AS $$
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
    AND (h.DataInizio_evento <= nuovo_fine AND h.DataFine_evento >= nuovo_inizio);

    -- Se c'è sovrapposizione, genera un errore
    IF conteggio > 0 THEN
        RAISE EXCEPTION 'L''utente % non può essere giudice per questo hackathon perché è già giudice per un hackathon con date sovrapposte', NEW.Username_utente;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION verifica_adesione_valida()
RETURNS TRIGGER AS $$
DECLARE
    data_fine_registrazione DATE;
    num_membri_attuali INTEGER;
    max_membri INTEGER;
    num_iscritti_corrente INTEGER;
    max_iscritti INTEGER;
BEGIN
    -- Recupera tutti i dati necessari dall'hackathon
    SELECT h.DataFine_registrazione, h.MaxNum_membriTeam, 
           COALESCE(h.NumIscritti_corrente, 0), h.MaxNum_iscritti
    INTO data_fine_registrazione, max_membri, num_iscritti_corrente, max_iscritti
    FROM HACKATHON h
    WHERE h.Titolo_identificativo = NEW.Titolo_hackathon;

    -- Verifica se la data attuale è successiva alla data di fine registrazione
    IF CURRENT_DATE > data_fine_registrazione THEN
        RAISE EXCEPTION 'Non è possibile aderire al team: le registrazioni per l''hackathon "%" sono chiuse dal %',
                         NEW.Titolo_hackathon, data_fine_registrazione;
    END IF;

    -- Verifica se è stato raggiunto il numero massimo di iscritti all'hackathon
    IF num_iscritti_corrente >= max_iscritti THEN
        RAISE EXCEPTION 'Non è possibile aderire al team: l''hackathon "%" ha raggiunto il numero massimo di partecipanti (%)',
                         NEW.Titolo_hackathon, max_iscritti;
    END IF;

    -- Conta il numero di membri attuali nel team
    SELECT COUNT(*)
    INTO num_membri_attuali
    FROM MEMBERSHIP m
    WHERE m.Team_appartenenza = NEW.Team_appartenenza
    AND m.Titolo_hackathon = NEW.Titolo_hackathon;

    -- Verifica se il team è già al completo
    IF num_membri_attuali >= max_membri THEN
        RAISE EXCEPTION 'Non è possibile aderire al team "%": il team ha già raggiunto il numero massimo di membri (%)',
                         NEW.Team_appartenenza, max_membri;
    END IF;

    -- Tutto ok, incrementa il contatore di iscritti
    UPDATE HACKATHON
    SET NumIscritti_corrente = COALESCE(NumIscritti_corrente, 0) + 1
    WHERE Titolo_identificativo = NEW.Titolo_hackathon;

    -- Se tutte le verifiche sono passate, permetti l'inserimento
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION gestisci_rimozione_iscritto()
RETURNS TRIGGER AS $$
BEGIN
    -- Decrementa il contatore degli iscritti correnti
    UPDATE HACKATHON
    SET NumIscritti_corrente = GREATEST(COALESCE(NumIscritti_corrente, 0) - 1, 0)
    WHERE Titolo_identificativo = OLD.Titolo_hackathon;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION gestisci_eliminazione_team()
RETURNS TRIGGER AS $$
DECLARE
    num_membri INTEGER;
BEGIN
    -- Conta quanti membri ha il team
    SELECT COUNT(*) INTO num_membri
    FROM MEMBERSHIP
    WHERE Team_appartenenza = OLD.Nome_team
    AND Titolo_hackathon = OLD.Titolo_hackathon;
    
    -- Decrementa il contatore degli iscritti per ogni membro del team
    UPDATE HACKATHON
    SET NumIscritti_corrente = GREATEST(COALESCE(NumIscritti_corrente, 0) - num_membri, 0)
    WHERE Titolo_identificativo = OLD.Titolo_hackathon;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION inizializza_contatore_iscritti()
RETURNS TRIGGER AS $$
BEGIN
    -- Imposta il contatore degli iscritti a 0 se è NULL
    NEW.NumIscritti_corrente := 0;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION elimina_team_incompleti()
RETURNS void AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION verifica_documento_caricato()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION genera_classifica_hackathon(titolo_hack VARCHAR(30))
RETURNS TEXT AS $$
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
        SELECT
            t.Nome_team,
            t.Punteggio_finale,
            MIN(d.Data_stesura) as prima_consegna
        FROM TEAM t
        LEFT JOIN DOCUMENTO d ON t.Nome_team = d.Nome_team AND t.Titolo_hackathon = d.Titolo_hackathon
        WHERE t.Titolo_hackathon = titolo_hack
        GROUP BY t.Nome_team, t.Punteggio_finale
        ORDER BY
            t.Punteggio_finale DESC, -- Regola 1: Punteggio più alto prima
            prima_consegna ASC,      -- Regola 2 (Spareggio): Timestamp di consegna anteriore prima
            t.Nome_team ASC          -- Regola 3 (Spareggio finale): Ordine alfabetico
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
$$ LANGUAGE plpgsql;


-- #############################################################################
-- ## CREAZIONE DEI TRIGGER                                                   ##
-- #############################################################################

CREATE TRIGGER trigger_aggiungi_giudice
AFTER UPDATE ON INVITO_GIUDICE
FOR EACH ROW
WHEN (OLD.Stato_invito IS DISTINCT FROM NEW.Stato_invito AND NEW.Stato_invito = 'Accettato')
EXECUTE FUNCTION aggiungi_giudice();

CREATE TRIGGER trigger_verifica_giudice_sovrapposizione
BEFORE INSERT OR UPDATE ON GIUDICE
FOR EACH ROW
EXECUTE FUNCTION verifica_giudice_sovrapposizione();

CREATE TRIGGER trigger_verifica_adesione_valida
BEFORE INSERT ON MEMBERSHIP
FOR EACH ROW
EXECUTE FUNCTION verifica_adesione_valida();

CREATE TRIGGER trigger_gestisci_rimozione_iscritto
AFTER DELETE ON MEMBERSHIP
FOR EACH ROW
EXECUTE FUNCTION gestisci_rimozione_iscritto();

CREATE TRIGGER trigger_gestisci_eliminazione_team
BEFORE DELETE ON TEAM
FOR EACH ROW
EXECUTE FUNCTION gestisci_eliminazione_team();

CREATE TRIGGER trigger_inizializza_contatore_iscritti
BEFORE INSERT ON HACKATHON
FOR EACH ROW
EXECUTE FUNCTION inizializza_contatore_iscritti();

CREATE TRIGGER trigger_verifica_documento_caricato
BEFORE INSERT ON VOTO
FOR EACH ROW
EXECUTE FUNCTION verifica_documento_caricato();


COMMIT;