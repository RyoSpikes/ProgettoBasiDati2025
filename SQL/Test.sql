-- #############################################################################
-- # Script di Test per il Database Hackathon
-- # Target: pgAdmin Query Tool
-- # Esecuzione: Si consiglia di eseguire un blocco alla volta per l'analisi.
-- #############################################################################

-- Imposta la lingua dei messaggi su English per garantire output di errore standard.
SET lc_messages TO 'en_US.UTF-8';

-- Inizio di una transazione. L'intero script verrà annullato tramite ROLLBACK alla fine.
BEGIN;

DO $$
BEGIN
    RAISE NOTICE '--- INIZIO DELLO SCRIPT DI TEST ---';
END
$$;

-------------------------------------------------------------------------------
-- FASE 1: PULIZIA DEL DATABASE
-------------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE 'FASE 1: Pulizia delle tabelle per rieseguire i test...';
END
$$;

-- L'ordine di eliminazione è critico per rispettare i vincoli di Foreign Key.
DELETE FROM INVITO_GIUDICE;
DELETE FROM VALUTAZIONE;
DELETE FROM VOTO;
DELETE FROM DOCUMENTO;
DELETE FROM MEMBERSHIP;
DELETE FROM TEAM;
DELETE FROM GIUDICE;
DELETE FROM HACKATHON;
DELETE FROM UTENTE;
DELETE FROM ORGANIZZATORE;

-------------------------------------------------------------------------------
-- FASE 2: TEST SU ORGANIZZATORE E UTENTE
-------------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE 'FASE 2: Test creazione utenti e organizzatori...';
END
$$;

-- Test 2.1: Inserimento standard di un record ORGANIZZATORE.
INSERT INTO ORGANIZZATORE (Username_org, Password) VALUES ('SuperAdmin', 'PasswordValida1!');
DO $$
BEGIN
    RAISE NOTICE '-> Test 2.1 SUCCESSO: Organizzatore "SuperAdmin" creato.';
END
$$;

-- Test 2.2: Inserimento in batch di record UTENTE.
INSERT INTO UTENTE (Username, Password) VALUES ('MarioRossi', 'PasswordValida1!');
INSERT INTO UTENTE (Username, Password) VALUES ('LucaLucci', 'PasswordValida2!');
INSERT INTO UTENTE (Username, Password) VALUES ('GioeleManzoni', 'PasswordValida3!');
INSERT INTO UTENTE (Username, Password) VALUES ('PaoloGialli', 'PasswordValida4!');
INSERT INTO UTENTE (Username, Password) VALUES ('FrancescaNeri', 'PasswordValida5!');
INSERT INTO UTENTE (Username, Password) VALUES ('NewUserForHackValida', 'PasswordValida6!');
DO $$
BEGIN
    RAISE NOTICE '-> Test 2.2 SUCCESSO: Utenti di test creati.';
END
$$;

-- Test 2.3: Verifica del vincolo di CHECK sulla complessità della password.
--         L'inserimento deve fallire.
DO $$
BEGIN
    RAISE NOTICE '-> Test 2.3 PREVISTO ERRORE: Provo ad inserire un utente con password debole...';
    INSERT INTO UTENTE (Username, Password) VALUES ('TestFallito', 'debole');
    RAISE EXCEPTION 'ERRORE NON PREVISTO: La password debole è stata accettata!';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '-> Test 2.3 SUCCESSO: Il vincolo sulla password ha bloccato correttamente l''inserimento.';
END
$$;

-------------------------------------------------------------------------------
-- FASE 3: TEST SU HACKATHON E VINCOLI SULLE DATE
-------------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE 'FASE 3: Test creazione Hackathon...';
END
$$;

-- Test 3.1: Inserimento standard di un record HACKATHON.
INSERT INTO HACKATHON (Titolo_identificativo, Organizzatore, Sede, DataInizio_registrazione, DataFine_registrazione, DataInizio_evento, DataFine_evento, Descrizione_problema, MaxNum_iscritti, MaxNum_membriTeam)
VALUES ('HackValida', 'SuperAdmin', 'Napoli', CURRENT_DATE, CURRENT_DATE + INTERVAL '10 days', CURRENT_DATE + INTERVAL '15 days', CURRENT_DATE + INTERVAL '17 days', 'Creare un''app innovativa.', 50, 4);
DO $$
BEGIN
    RAISE NOTICE '-> Test 3.1 SUCCESSO: Hackathon "HackValida" creato.';
END
$$;

-- Test 3.2: Verifica che il valore di DEFAULT (o un trigger) inizializzi NumIscritti_corrente a 0.
DO $$
DECLARE
    iscritti INTEGER;
BEGIN
    RAISE NOTICE '-> Test 3.2 VERIFICA: Inizializzazione NumIscritti_corrente...';
    SELECT NumIscritti_corrente INTO iscritti FROM HACKATHON WHERE Titolo_identificativo = 'HackValida';
    IF iscritti = 0 THEN
        RAISE NOTICE '-> VERIFICA 3.2 SUCCESSO: NumIscritti_corrente è stato inizializzato a 0.';
    ELSE
        RAISE EXCEPTION '-> VERIFICA 3.2 FALLITA: NumIscritti_corrente è % invece di 0!', iscritti;
    END IF;
END
$$;

-- Test 3.3: Verifica del vincolo di CHECK sulla coerenza delle date di registrazione.
DO $$
BEGIN
    RAISE NOTICE '-> Test 3.3 PREVISTO ERRORE: Provo ad inserire hackathon con date incoerenti...';
    INSERT INTO HACKATHON (Titolo_identificativo, Organizzatore, Sede, DataInizio_registrazione, DataFine_registrazione, DataInizio_evento, DataFine_evento, Descrizione_problema, MaxNum_iscritti, MaxNum_membriTeam)
    VALUES ('HackFallito', 'SuperAdmin', 'Milano', CURRENT_DATE, CURRENT_DATE - INTERVAL '1 day', '2025-10-20', '2025-10-22', 'Test date.', 10, 2);
    RAISE EXCEPTION 'ERRORE NON PREVISTO: L''hackathon con date incoerenti è stato accettato!';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '-> Test 3.3 SUCCESSO: Il vincolo sulle date ha bloccato correttamente l''inserimento.';
END
$$;

-- Test 3.4: Verifica del vincolo di CHECK sull'intervallo minimo tra fine registrazione e inizio evento.
DO $$
BEGIN
    RAISE NOTICE '-> Test 3.4 PREVISTO ERRORE: Provo ad inserire hackathon con meno di 2 giorni tra fine registrazione e inizio evento...';
    INSERT INTO HACKATHON (Titolo_identificativo, Organizzatore, Sede, DataInizio_registrazione, DataFine_registrazione, DataInizio_evento, DataFine_evento, Descrizione_problema, MaxNum_iscritti, MaxNum_membriTeam)
    VALUES ('HackRavvicinato', 'SuperAdmin', 'Online', CURRENT_DATE, CURRENT_DATE + INTERVAL '14 days', CURRENT_DATE + INTERVAL '15 days', CURRENT_DATE + INTERVAL '16 days', 'Test vincolo 2 giorni.', 30, 5);
    RAISE EXCEPTION 'ERRORE NON PREVISTO: L''hackathon con registrazione troppo vicina all''evento è stato accettato!';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '-> Test 3.4 SUCCESSO: Il vincolo sui 2 giorni di distanza ha bloccato correttamente l''inserimento.';
END
$$;

-------------------------------------------------------------------------------
-- FASE 4: TEST SULLA GESTIONE DEI GIUDICI (TRIGGER)
-------------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE 'FASE 4: Test gestione giudici...';
END
$$;

-- Test 4.1: Inserimento di un invito per un giudice.
INSERT INTO INVITO_GIUDICE (Username_organizzatore, Username_utente, Titolo_hackathon, Stato_invito)
VALUES ('SuperAdmin', 'LucaLucci', 'HackValida', 'Inviato');
DO $$
BEGIN
    RAISE NOTICE '-> Test 4.1 SUCCESSO: Invito inviato a "LucaLucci".';
END
$$;

-- Test 4.2: Verifica che l'accettazione dell'invito attivi un trigger per popolare la tabella GIUDICE.
UPDATE INVITO_GIUDICE SET Stato_invito = 'Accettato' WHERE Username_utente = 'LucaLucci' AND Titolo_hackathon = 'HackValida';
DO $$
BEGIN
    RAISE NOTICE '-> Test 4.2 SUCCESSO: Invito accettato. Verifico se il trigger ha funzionato...';
    IF EXISTS (SELECT 1 FROM GIUDICE WHERE Username_utente = 'LucaLucci' AND Titolo_hackathon = 'HackValida') THEN
        RAISE NOTICE '-> VERIFICA 4.2 SUCCESSO: "LucaLucci" è ora un giudice per "HackValida".';
    ELSE
        RAISE EXCEPTION '-> VERIFICA 4.2 FALLITA: Il trigger non ha inserito il giudice!';
    END IF;
END
$$;

-- Test 4.3: Verifica del trigger che impedisce a un giudice di essere assegnato a eventi con date sovrapposte.
DO $$
BEGIN
    RAISE NOTICE '-> Test 4.3 PREVISTO ERRORE: Provo a rendere "LucaLucci" giudice per un hackathon sovrapposto...';
    -- Crea un secondo hackathon con date che si sovrappongono a 'HackValida'.
    INSERT INTO HACKATHON (Titolo_identificativo, Organizzatore, Sede, DataInizio_registrazione, DataFine_registrazione, DataInizio_evento, DataFine_evento, Descrizione_problema, MaxNum_iscritti, MaxNum_membriTeam)
    VALUES ('HackOverlap', 'SuperAdmin', 'Roma', CURRENT_DATE, CURRENT_DATE + INTERVAL '10 days', CURRENT_DATE + INTERVAL '16 days', CURRENT_DATE + INTERVAL '18 days', 'Test sovrapposizione.', 20, 3);
    
    -- L'inserimento diretto in GIUDICE deve fallire.
    INSERT INTO GIUDICE (Username_utente, Titolo_hackathon) VALUES ('LucaLucci', 'HackOverlap');
    RAISE EXCEPTION 'ERRORE NON PREVISTO: Il trigger di sovrapposizione non ha funzionato!';
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE '-> Test 4.3 SUCCESSO: Il trigger "verifica_giudice_sovrapposizione" ha bloccato l''inserimento.';
END
$$;

-------------------------------------------------------------------------------
-- FASE 5: TEST SU ISCRIZIONI E TEAM (TRIGGER)
-------------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE 'FASE 5: Test iscrizioni e team...';
END
$$;

-- Test 5.1: Creazione di un team e iscrizione di un membro.
INSERT INTO TEAM (Nome_team, Titolo_hackathon) VALUES ('CodiceFantasma', 'HackValida');
INSERT INTO MEMBERSHIP (Username_utente, Team_appartenenza, Titolo_hackathon, Data_adesione)
VALUES ('MarioRossi', 'CodiceFantasma', 'HackValida', CURRENT_DATE);
DO $$
BEGIN
    RAISE NOTICE '-> Test 5.1 SUCCESSO: "MarioRossi" si è unito al team "CodiceFantasma".';
END
$$;

-- Test 5.2: Verifica che il trigger ON INSERT su MEMBERSHIP incrementi il contatore degli iscritti.
DO $$
DECLARE
    iscritti INTEGER;
BEGIN
    SELECT NumIscritti_corrente INTO iscritti FROM HACKATHON WHERE Titolo_identificativo = 'HackValida';
    IF iscritti = 1 THEN
        RAISE NOTICE '-> Test 5.2 SUCCESSO: NumIscritti_corrente è stato aggiornato a 1.';
    ELSE
        RAISE EXCEPTION '-> Test 5.2 FALLITO: NumIscritti_corrente è % invece di 1!', iscritti;
    END IF;
END
$$;

-- Test 5.3: Verifica che il trigger ON DELETE su MEMBERSHIP decrementi il contatore degli iscritti.
DELETE FROM MEMBERSHIP WHERE Username_utente = 'MarioRossi' AND Team_appartenenza = 'CodiceFantasma';
DO $$
DECLARE
    iscritti INTEGER;
BEGIN
    RAISE NOTICE '-> Test 5.3 SUCCESSO: "MarioRossi" rimosso dal team.';
    SELECT NumIscritti_corrente INTO iscritti FROM HACKATHON WHERE Titolo_identificativo = 'HackValida';
    IF iscritti = 0 THEN
        RAISE NOTICE '-> VERIFICA 5.3 SUCCESSO: NumIscritti_corrente è stato decrementato a 0.';
    ELSE
        RAISE EXCEPTION '-> VERIFICA 5.3 FALLITA: NumIscritti_corrente è % invece di 0!', iscritti;
    END IF;
END
$$;

-- Test 5.4: Verifica del trigger che impedisce l'iscrizione a un team che ha raggiunto la capienza massima.
DO $$
BEGIN
    RAISE NOTICE '-> Test 5.4 PREVISTO ERRORE: Provo ad iscrivermi a un team pieno...';
    -- Imposta temporaneamente la capienza massima del team a 1.
    UPDATE HACKATHON SET MaxNum_membriTeam = 1 WHERE Titolo_identificativo = 'HackValida';
    -- Riempe il team.
    INSERT INTO MEMBERSHIP (Username_utente, Team_appartenenza, Titolo_hackathon, Data_adesione)
    VALUES ('MarioRossi', 'CodiceFantasma', 'HackValida', CURRENT_DATE);
    
    -- Questo inserimento deve fallire.
    INSERT INTO MEMBERSHIP (Username_utente, Team_appartenenza, Titolo_hackathon, Data_adesione)
    VALUES ('GioeleManzoni', 'CodiceFantasma', 'HackValida', CURRENT_DATE);
    RAISE EXCEPTION 'ERRORE NON PREVISTO: È stato possibile iscriversi a un team pieno!';
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE '-> Test 5.4 SUCCESSO: Il trigger ha impedito l''iscrizione al team pieno.';
END
$$;

-- Cleanup per i test successivi.
DELETE FROM MEMBERSHIP WHERE Username_utente = 'MarioRossi' AND Team_appartenenza = 'CodiceFantasma';
UPDATE HACKATHON SET MaxNum_membriTeam = 4 WHERE Titolo_identificativo = 'HackValida';

-- Test 5.5: Verifica del trigger che impedisce l'iscrizione a un hackathon che ha raggiunto la capienza massima.
DO $$
BEGIN
    RAISE NOTICE '-> Test 5.5 PREVISTO ERRORE: Iscrizione a hackathon con max iscritti raggiunto...';
    -- Imposta temporaneamente la capienza massima dell'hackathon a 1.
    UPDATE HACKATHON SET MaxNum_iscritti = 1 WHERE Titolo_identificativo = 'HackValida';
    -- Raggiunge il limite.
    INSERT INTO TEAM (Nome_team, Titolo_hackathon) VALUES ('TeamLimite', 'HackValida');
    INSERT INTO MEMBERSHIP (Username_utente, Team_appartenenza, Titolo_hackathon, Data_adesione)
    VALUES ('MarioRossi', 'TeamLimite', 'HackValida', CURRENT_DATE);

    -- Questo inserimento (in un team diverso) deve fallire perché supera il limite dell'hackathon.
    INSERT INTO TEAM (Nome_team, Titolo_hackathon) VALUES ('TeamOltreLimite', 'HackValida');
    INSERT INTO MEMBERSHIP (Username_utente, Team_appartenenza, Titolo_hackathon, Data_adesione)
    VALUES ('NewUserForHackValida', 'TeamOltreLimite', 'HackValida', CURRENT_DATE);
    RAISE EXCEPTION 'ERRORE NON PREVISTO: Iscrizione accettata oltre il limite massimo di iscritti!';
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE '-> Test 5.5 SUCCESSO: Il trigger ha bloccato l''iscrizione oltre il limite massimo di iscritti.';
END
$$;

-- Cleanup per i test successivi.
DELETE FROM MEMBERSHIP WHERE Username_utente = 'MarioRossi' AND Team_appartenenza = 'TeamLimite';
DELETE FROM TEAM WHERE Nome_team = 'TeamLimite';
DELETE FROM TEAM WHERE Nome_team = 'TeamOltreLimite';
UPDATE HACKATHON SET MaxNum_iscritti = 50 WHERE Titolo_identificativo = 'HackValida';

-------------------------------------------------------------------------------
-- FASE 6: TEST SULLE TABELLE DI VALUTAZIONE E VOTO
-------------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE 'FASE 6: Test su valutazioni e voti...';
END
$$;

-- Setup: Associa un utente a un team per i test di valutazione.
-- Nota: Il team 'CodiceFantasma' è un'entità preesistente dalla Fase 5.
INSERT INTO MEMBERSHIP (Username_utente, Team_appartenenza, Titolo_hackathon, Data_adesione)
VALUES ('MarioRossi', 'CodiceFantasma', 'HackValida', CURRENT_DATE);

-- Test 6.1: Verifica che un giudice non possa votare un team senza documenti sottomessi.
--         L'operazione deve fallire a causa di un trigger (verifica_documento_caricato).
DO $$
BEGIN
    RAISE NOTICE '-> Test 6.1 PREVISTO ERRORE: Tentativo di voto su team senza documenti.';
    INSERT INTO VOTO (Username_giudice, Titolo_hackathon, Team_votato, Punteggio)
    VALUES ('LucaLucci', 'HackValida', 'CodiceFantasma', 8);
    RAISE EXCEPTION 'ERRORE NON PREVISTO: Il voto è stato accettato nonostante l''assenza di documenti!';
EXCEPTION
    WHEN raise_exception THEN
        RAISE NOTICE '-> Test 6.1 SUCCESSO: Il trigger ha correttamente impedito il voto.';
END
$$;

-- Test 6.2: Sottomette un documento per il team, soddisfacendo la pre-condizione per il voto.
INSERT INTO DOCUMENTO (Nome_team, Titolo_hackathon, Titolo_doc, Contenuto, Data_stesura)
VALUES ('CodiceFantasma', 'HackValida', 'Progetto_Alpha', 'Questo è il contenuto del nostro progetto.', CURRENT_TIMESTAMP);
DO $$
BEGIN
    RAISE NOTICE '-> Test 6.2 SUCCESSO: Documento per il team "CodiceFantasma" caricato.';
END
$$;

-- Test 6.3: Inserisce una valutazione testuale (VALUTAZIONE) per il documento specifico.
DO $$
DECLARE
    doc_id INTEGER;
BEGIN
    -- Recupera l'ID del documento appena inserito per la FK.
    SELECT ID_documento INTO doc_id FROM DOCUMENTO WHERE Titolo_doc = 'Progetto_Alpha' LIMIT 1;
    INSERT INTO VALUTAZIONE(ID_documento, Username_giudice, Titolo_hackathon, Team_valutato, Valutazione_giudice)
    VALUES (doc_id, 'LucaLucci', 'HackValida', 'CodiceFantasma', 'Il documento è ben scritto ma manca di dettagli tecnici.');
    RAISE NOTICE '-> Test 6.3 SUCCESSO: Valutazione testuale inserita per il documento ID %.', doc_id;
END
$$;

-- Esegue i test con voti non validi prima di quello valido per evitare conflitti di unique constraint.

-- Test 6.4: Verifica il vincolo di CHECK sul punteggio (deve essere >= 0).
DO $$
BEGIN
    RAISE NOTICE '-> Test 6.4 PREVISTO ERRORE: Voto con punteggio negativo.';
    INSERT INTO VOTO (Username_giudice, Titolo_hackathon, Team_votato, Punteggio)
    VALUES ('LucaLucci', 'HackValida', 'CodiceFantasma', -1);
    RAISE EXCEPTION 'ERRORE NON PREVISTO: Voto con punteggio negativo accettato!';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '-> Test 6.4 SUCCESSO: Il vincolo sul punteggio minimo ha funzionato.';
END
$$;

-- Test 6.5: Verifica il vincolo di CHECK sul punteggio (deve essere <= 10).
DO $$
BEGIN
    RAISE NOTICE '-> Test 6.5 PREVISTO ERRORE: Voto con punteggio fuori scala.';
    INSERT INTO VOTO (Username_giudice, Titolo_hackathon, Team_votato, Punteggio)
    VALUES ('LucaLucci', 'HackValida', 'CodiceFantasma', 11);
    RAISE EXCEPTION 'ERRORE NON PREVISTO: Voto con punteggio superiore a 10 accettato!';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '-> Test 6.5 SUCCESSO: Il vincolo sul punteggio massimo ha funzionato.';
END
$$;

-- Test 6.6: Inserisce un voto numerico valido, ora che il documento esiste.
INSERT INTO VOTO (Username_giudice, Titolo_hackathon, Team_votato, Punteggio)
VALUES ('LucaLucci', 'HackValida', 'CodiceFantasma', 8);
DO $$
BEGIN
    RAISE NOTICE '-> Test 6.6 SUCCESSO: Voto numerico valido inserito.';
END
$$;

-------------------------------------------------------------------------------
-- FASE 7: TEST SULLA GENERAZIONE DELLA CLASSIFICA
-------------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE 'FASE 7: Test generazione classifica...';
END
$$;

-- Setup: Aggiunge un secondo team e un secondo giudice per testare logiche di classifica più complesse.
INSERT INTO TEAM (Nome_team, Titolo_hackathon) VALUES ('BitWarriors', 'HackValida');
INSERT INTO MEMBERSHIP (Username_utente, Team_appartenenza, Titolo_hackathon, Data_adesione)
VALUES ('GioeleManzoni', 'BitWarriors', 'HackValida', CURRENT_DATE);
INSERT INTO MEMBERSHIP (Username_utente, Team_appartenenza, Titolo_hackathon, Data_adesione)
VALUES ('PaoloGialli', 'BitWarriors', 'HackValida', CURRENT_DATE);
-- Il trigger su INVITO_GIUDICE creerà l'entry corrispondente in GIUDICE.
INSERT INTO INVITO_GIUDICE (Username_organizzatore, Username_utente, Titolo_hackathon, Stato_invito)
VALUES ('SuperAdmin', 'FrancescaNeri', 'HackValida', 'Accettato');

-- Setup per Test 7.4: Carica documenti con timestamp differenti per testare la regola di spareggio.
DO $$
BEGIN
    RAISE NOTICE '-> Preparazione per test spareggio: caricamento documenti...';
END
$$;
INSERT INTO DOCUMENTO (Nome_team, Titolo_hackathon, Titolo_doc, Contenuto, Data_stesura)
VALUES ('BitWarriors', 'HackValida', 'Progetto_Beta', 'Contenuto del secondo progetto.', CURRENT_TIMESTAMP);
INSERT INTO DOCUMENTO (Nome_team, Titolo_hackathon, Titolo_doc, Contenuto, Data_stesura)
VALUES ('CodiceFantasma', 'HackValida', 'Progetto_Alpha_v2', 'Secondo documento.', CURRENT_TIMESTAMP + INTERVAL '1 second'); -- Offset per garantire ordine temporale.

-- Test 7.1: Verifica che la funzione `genera_classifica_hackathon` non sia eseguibile prima della fine dell'evento.
DO $$
DECLARE
    classifica TEXT;
BEGIN
    RAISE NOTICE '-> Test 7.1 PREVISTO ERRORE: Generazione classifica ante-termine.';
    UPDATE HACKATHON SET DataFine_evento = CURRENT_DATE + INTERVAL '100000 day' WHERE Titolo_identificativo = 'HackValida';
    SELECT genera_classifica_hackathon('HackValida') INTO classifica;
    IF classifica LIKE 'Errore: Non è possibile generare la classifica%' THEN
        RAISE NOTICE '-> Test 7.1 SUCCESSO: La funzione ha correttamente impedito la generazione.';
    ELSE
        RAISE EXCEPTION 'ERRORE NON PREVISTO: La classifica è stata generata in anticipo!';
    END IF;
END
$$;

-- -- Test 7.2: Verifica che la generazione della classifica fallisca se mancano dei voti.
-- DO $$
-- DECLARE
--     classifica TEXT;
--     messaggio_atteso TEXT;
-- BEGIN
--     RAISE NOTICE '-> Test 7.2 PREVISTO ERRORE: Generazione classifica con voti mancanti.';
--     -- Simula la fine dell'evento per superare il controllo precedente.
--     UPDATE HACKATHON SET DataFine_evento = CURRENT_DATE - INTERVAL '1 day' WHERE Titolo_identificativo = 'HackValida';
    
--     -- Inserisce un voto. Voti attesi: 4 (2 team * 2 giudici). Voti presenti: 2 (1 da Fase 6, 1 qui).
--     INSERT INTO VOTO (Username_giudice, Titolo_hackathon, Team_votato, Punteggio) VALUES ('LucaLucci', 'HackValida', 'BitWarriors', 10);
    
--     SELECT genera_classifica_hackathon('HackValida') INTO classifica;
    
--     messaggio_atteso := 'Mancano 2 voti su 4 attesi';
--     IF classifica LIKE '%' || messaggio_atteso || '%' THEN
--         RAISE NOTICE '-> Test 7.2 SUCCESSO: La funzione ha rilevato correttamente i voti mancanti (messaggio: %).', classifica;
--     ELSE
--         RAISE EXCEPTION 'ERRORE NON PREVISTO: La classifica è stata generata o il messaggio di errore è incorretto! Ricevuto: %', classifica;
--     END IF;
-- END
-- $$;

-- -- Test 7.3: Inserisce i voti mancanti per creare un pareggio e genera la classifica.
-- DO $$
-- BEGIN
--     RAISE NOTICE '-> Test 7.3: Inserimento voti finali e generazione classifica.';
--     -- Voti di FrancescaNeri. Punteggio finale per entrambi i team: 18.
--     INSERT INTO VOTO (Username_giudice, Titolo_hackathon, Team_votato, Punteggio) VALUES ('FrancescaNeri', 'HackValida', 'CodiceFantasma', 10);
--     INSERT INTO VOTO (Username_giudice, Titolo_hackathon, Team_votato, Punteggio) VALUES ('FrancescaNeri', 'HackValida', 'BitWarriors', 8);
    
--     -- Esegue la funzione, il cui output viene scartato (l'effetto è l'UPDATE sulla tabella HACKATHON).
--     PERFORM genera_classifica_hackathon('HackValida');
--     RAISE NOTICE '-> Classifica generata con successo.';
-- END
-- $$;

-- -- Test 7.4: Verifica la logica di spareggio: a parità di punti, vince chi ha consegnato prima il primo documento.
-- DO $$
-- DECLARE
--     classifica_generata TEXT;
--     posizione_bitwarriors INT;
--     posizione_fantasma INT;
-- BEGIN
--     RAISE NOTICE '-> Test 7.4: Verifica regola di spareggio (timestamp consegna).';
--     SELECT Classifica INTO classifica_generata FROM HACKATHON WHERE Titolo_identificativo = 'HackValida';
    
--     -- La posizione (indice) di BitWarriors nella stringa di classifica deve essere minore di quella di CodiceFantasma.
--     posizione_bitwarriors := STRPOS(classifica_generata, 'BitWarriors');
--     posizione_fantasma := STRPOS(classifica_generata, 'CodiceFantasma');

--     RAISE NOTICE 'Classifica finale generata: %', E'\n' || classifica_generata;

--     IF posizione_bitwarriors > 0 AND posizione_fantasma > 0 AND posizione_bitwarriors < posizione_fantasma THEN
--         RAISE NOTICE '-> Test 7.4 SUCCESSO: "BitWarriors" è classificato correttamente prima di "CodiceFantasma".';
--     ELSE
--         RAISE EXCEPTION '-> Test 7.4 FALLITO: La regola di spareggio non ha funzionato! Posizione BitWarriors: %, Posizione CodiceFantasma: %', posizione_bitwarriors, posizione_fantasma;
--     END IF;
-- END
-- $$;

-- Test 7.5: Verifica che la funzione gestisca correttamente un input per un hackathon inesistente.
DO $$
DECLARE
    classifica TEXT;
BEGIN
    RAISE NOTICE '-> Test 7.5 PREVISTO ERRORE: Generazione classifica per hackathon inesistente.';
    SELECT genera_classifica_hackathon('HackInesistente') INTO classifica;
    IF classifica = 'Errore: Hackathon non trovato' THEN
        RAISE NOTICE '-> Test 7.5 SUCCESSO: La funzione ha gestito correttamente l''hackathon inesistente.';
    ELSE
        RAISE EXCEPTION 'ERRORE NON PREVISTO: La funzione non ha gestito l''hackathon inesistente!';
    END IF;
END
$$;

-------------------------------------------------------------------------------
-- FASE 8: TEST ELIMINAZIONE TEAM INCOMPLETI
-------------------------------------------------------------------------------

-- NOTICE iniziale
DO $$
BEGIN
    RAISE NOTICE 'FASE 8: Test eliminazione team incompleti...';
END
$$;


-- 1) Setup: organizzatore e utenti di prova
INSERT INTO ORGANIZZATORE (Username_org, Password)
  VALUES ('AdminDelTest', 'PwdDel@123');

INSERT INTO UTENTE (Username, Password)
  VALUES 
    ('U1', 'Pwd1@123'),
    ('U2', 'Pwd2@123'),
    ('U3', 'Pwd3@123');


-- 2) Creazione hackathon con DataFine_registrazione = oggi,
--    in modo che i team incompleti vengano rimossi
INSERT INTO HACKATHON (
    Titolo_identificativo,
    Organizzatore,
    Sede,
    DataInizio_registrazione,
    DataFine_registrazione,
    DataInizio_evento,
    DataFine_evento,
    Descrizione_problema,
    MaxNum_iscritti,
    MaxNum_membriTeam
) VALUES (
    'HackIncompleteTest',
    'AdminDelTest',
    'Roma',
    CURRENT_DATE - INTERVAL '5 days',
    CURRENT_DATE,                           -- registrazioni chiuse oggi
    CURRENT_DATE + INTERVAL '2 days',
    CURRENT_DATE + INTERVAL '4 days',
    'Test eliminazione team incompleti',
    50,
    5
);


-- 3) Creazione di tre team:
--    TeamSolo  → 1 membro (incompleto)
--    TeamDue   → 2 membri (completo)
--    TeamZero  → 0 membri (incompleto)
INSERT INTO TEAM (Nome_team, Titolo_hackathon)
VALUES
  ('TeamSolo', 'HackIncompleteTest'),
  ('TeamDue',  'HackIncompleteTest'),
  ('TeamZero','HackIncompleteTest');


-- 4) Aggiunta dei membri
INSERT INTO MEMBERSHIP (Username_utente, Team_appartenenza, Titolo_hackathon, Data_adesione)
VALUES
  -- TeamSolo (1 membro)
  ('U1', 'TeamSolo', 'HackIncompleteTest', CURRENT_DATE - INTERVAL '4 days'),

  -- TeamDue (2 membri)
  ('U2', 'TeamDue',  'HackIncompleteTest', CURRENT_DATE - INTERVAL '4 days'),
  ('U3', 'TeamDue',  'HackIncompleteTest', CURRENT_DATE - INTERVAL '4 days');


-- 5) Invocazione della procedura di eliminazione in un blocco PL/pgSQL
DO $$
BEGIN
    PERFORM elimina_team_incompleti();
    RAISE NOTICE '-> elimina_team_incompleti() invocata';
END
$$ LANGUAGE plpgsql;


-- 6) Verifica risultato:
--    TeamDue deve esistere, TeamSolo e TeamZero devono essere stati rimossi
DO $$
DECLARE
    cnt_due      INTEGER;
    cnt_incomple INTEGER;
BEGIN
    SELECT COUNT(*)
      INTO cnt_due
    FROM TEAM
    WHERE Titolo_hackathon = 'HackIncompleteTest'
      AND Nome_team = 'TeamDue';

    SELECT COUNT(*)
      INTO cnt_incomple
    FROM TEAM
    WHERE Titolo_hackathon = 'HackIncompleteTest'
      AND Nome_team IN ('TeamSolo','TeamZero');

    IF cnt_due = 1 AND cnt_incomple = 0 THEN
        RAISE NOTICE '-> Test 8 SUCCESSO: rimane solo TeamDue, team incompleti eliminati.';
    ELSE
        RAISE EXCEPTION '-> Test 8 FALLITO: cnt_due = %, cnt_incomple = %', cnt_due, cnt_incomple;
    END IF;
END
$$ LANGUAGE plpgsql;

-------------------------------------------------------------------------------
-- FASE 9: TEST SUL COMPORTAMENTO ON DELETE (CASCADE E RESTRICT)
-------------------------------------------------------------------------------

-- NOTICE iniziale
DO $$
BEGIN
    RAISE NOTICE 'FASE 9: Test cascata ON DELETE...';
END
$$ LANGUAGE plpgsql;


-------------------------------------------------------------------------------
-- Test 9.1: Verifica ON DELETE CASCADE da HACKATHON → tutte le tabelle figlie
-------------------------------------------------------------------------------
DO $$
DECLARE
    doc_id_temp INTEGER;
BEGIN
    RAISE NOTICE '-> Test 9.1: Eliminazione Hackathon e verifica cascata.';

    -- 1) Creo l'organizzatore e un utente-giudice fresco
    INSERT INTO ORGANIZZATORE (Username_org, Password)
      VALUES ('SuperAdmin','PwdSuper!1')
      ON CONFLICT DO NOTHING;
    INSERT INTO UTENTE (Username, Password)
      VALUES ('JudgeDel','PwdDel@123')
      ON CONFLICT DO NOTHING;

    -- 2) Creo hackathon (rispetta Δ registrazione/evento ≥ 2 giorni)
    INSERT INTO HACKATHON (
        Titolo_identificativo, Organizzatore, Sede,
        DataInizio_registrazione, DataFine_registrazione,
        DataInizio_evento,        DataFine_evento,
        Descrizione_problema,
        MaxNum_iscritti, MaxNum_membriTeam
    ) VALUES (
        'HackToDelete','SuperAdmin','TestLoc',
        CURRENT_DATE - INTERVAL '1 day',   -- inizio registro ieri
        CURRENT_DATE + INTERVAL '1 day',   -- fine registro tra 1 giorno
        CURRENT_DATE + INTERVAL '3 days',  -- inizio evento fra 3 giorni
        CURRENT_DATE + INTERVAL '5 days',  -- fine evento fra 5 giorni
        'Cascading test.', 10, 2
    );

    -- 3) Team e membership
    INSERT INTO TEAM (Nome_team, Titolo_hackathon)
      VALUES ('TeamToDelete','HackToDelete');
    INSERT INTO MEMBERSHIP (Username_utente, Team_appartenenza, Titolo_hackathon, Data_adesione)
      VALUES ('JudgeDel','TeamToDelete','HackToDelete', CURRENT_DATE);

    -- 4) Documento
    INSERT INTO DOCUMENTO (Nome_team, Titolo_hackathon, Titolo_doc, Contenuto)
      VALUES ('TeamToDelete','HackToDelete','DocToDelete','Contenuto.');

    -- 5) Invito + accettazione trigger-based per creare GIUDICE
    INSERT INTO INVITO_GIUDICE (
      Username_organizzatore, Username_utente, Titolo_hackathon, Stato_invito
    ) VALUES (
      'SuperAdmin','JudgeDel','HackToDelete','Inviato'
    );
    UPDATE INVITO_GIUDICE
      SET Stato_invito = 'Accettato'
      WHERE Username_utente='JudgeDel' AND Titolo_hackathon='HackToDelete';

    -- 6) Voto (ora JudgeDel è in GIUDICE, senza date sovrapposte)
    INSERT INTO VOTO (
      Username_giudice, Titolo_hackathon, Team_votato, Punteggio
    ) VALUES (
      'JudgeDel','HackToDelete','TeamToDelete', 5
    );

    -- 7) Valutazione
    SELECT ID_documento
      INTO doc_id_temp
      FROM DOCUMENTO
     WHERE Titolo_doc = 'DocToDelete'
     LIMIT 1;
    INSERT INTO VALUTAZIONE (
      ID_documento, Username_giudice, Titolo_hackathon, Team_valutato, Valutazione_giudice
    ) VALUES (
      doc_id_temp,'JudgeDel','HackToDelete','TeamToDelete','Buono.'
    );

    -- 8) Elimino l'hackathon (ON DELETE CASCADE)
    DELETE FROM HACKATHON WHERE Titolo_identificativo = 'HackToDelete';

    -- 9) Verifico che non esistano più dati figli
    IF NOT EXISTS (SELECT 1 FROM TEAM         WHERE Titolo_hackathon='HackToDelete')
       AND NOT EXISTS (SELECT 1 FROM MEMBERSHIP  WHERE Titolo_hackathon='HackToDelete')
       AND NOT EXISTS (SELECT 1 FROM DOCUMENTO   WHERE Titolo_hackathon='HackToDelete')
       AND NOT EXISTS (SELECT 1 FROM INVITO_GIUDICE WHERE Titolo_hackathon='HackToDelete')
       AND NOT EXISTS (SELECT 1 FROM GIUDICE     WHERE Titolo_hackathon='HackToDelete')
       AND NOT EXISTS (SELECT 1 FROM VOTO        WHERE Titolo_hackathon='HackToDelete')
       AND NOT EXISTS (SELECT 1 FROM VALUTAZIONE WHERE Titolo_hackathon='HackToDelete')
    THEN
        RAISE NOTICE '-> Test 9.1 SUCCESSO: eliminazione a cascata OK.';
    ELSE
        RAISE EXCEPTION '-> Test 9.1 FALLITO: dati figli rimasti!';
    END IF;
END
$$ LANGUAGE plpgsql;


-------------------------------------------------------------------------------
-- Test 9.2: Verifica ON DELETE RESTRICT su ORGANIZZATORE → HACKATHON
-------------------------------------------------------------------------------
DO $$
BEGIN
    RAISE NOTICE '-> Test 9.2 PREVISTO ERRORE: cancellazione Organizzatore con hackathon attivi.';

    -- Setup: organizzatore e hackathon collegato
    INSERT INTO ORGANIZZATORE (Username_org, Password)
      VALUES ('OrgToDelete','PassValida1!')
      ON CONFLICT DO NOTHING;
    INSERT INTO HACKATHON (
        Titolo_identificativo, Organizzatore, Sede,
        DataInizio_registrazione, DataFine_registrazione,
        DataInizio_evento,        DataFine_evento,
        Descrizione_problema,
        MaxNum_iscritti, MaxNum_membriTeam
    ) VALUES (
        'HackOrg','OrgToDelete','Online',
        CURRENT_DATE - INTERVAL '3 days',
        CURRENT_DATE - INTERVAL '1 day',
        CURRENT_DATE + INTERVAL '1 day',
        CURRENT_DATE + INTERVAL '3 days',
        'Test restrizione.', 10, 2
    );

    -- Tentativo di cancellazione (deve fallire)
    DELETE FROM ORGANIZZATORE WHERE Username_org = 'OrgToDelete';
    RAISE EXCEPTION '-> Test 9.2 FALLITO: Organizzatore eliminato nonostante RESTRICT!';

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE '-> Test 9.2 SUCCESSO: FK RESTRICT ha impedito la cancellazione.';
END
$$ LANGUAGE plpgsql;

-- Cleanup test 9.2
DELETE FROM HACKATHON      WHERE Titolo_identificativo = 'HackOrg';
DELETE FROM ORGANIZZATORE WHERE Username_org        = 'OrgToDelete';

DO $$
BEGIN
    RAISE NOTICE '--- TUTTI I TEST SONO STATI ESEGUITI ---';
END
$$;

-- L'azione di default è annullare la transazione per non lasciare dati di test nel DB.
-- Per applicare le modifiche, decommentare COMMIT e commentare ROLLBACK.
-- COMMIT;
ROLLBACK;