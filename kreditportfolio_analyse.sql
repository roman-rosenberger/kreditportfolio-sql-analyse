-- ============================================
-- ABSCHLUSSPROJEKT: Datenanalyse für Finanzdienstleister
-- Modul: Datenbanken und SQL
-- Datensatz: credit_risk (32.581 Zeilen, 12 Spalten)
-- ============================================

-- ============================================
-- AUFGABE 1: Missstände in der Kreditvergabe
-- ============================================

-- --- Block 1: Datenqualitätsprobleme ---

USE credit_risk_dataset;
-- Kontrolle: Zeilenanzahl muss laut Aufgabenstellung 32581 betragen
SELECT COUNT(*) AS anzahl_zeilen
FROM credit_risk;
-- check

-- Block 1, Abfrage 1, AUFFAELLIGKEIT 1: Unrealistisches Alter (person_age)
-- Grenze 80 Jahre, da Konsumentenkredite ab diesem Alter unplausibel sind
-- Ergebnis: 7 Faelle, davon Werte 144 (3x) und 123 (2x) wiederholt
-- --> deutet auf systematischen Erfassungs-/Importfehler hin, nicht zufaellige Tippfehler
SELECT
person_age,
person_income,
person_emp_length,
loan_grade,
loan_status
FROM credit_risk
WHERE person_age > 80
ORDER BY person_age DESC;

-- Block 1, Abfrage 2, AUFFAELLIGKEIT 2: Unrealistische Beschaeftigungsdauer (person_emp_length)
-- Grenze 60 Jahre = realistisches Maximum einer Erwerbsbiografie
-- Ergebnis: 2 Faelle, beide mit Wert 123 - identisch zu Werten bei person_age
-- --> staerkt die Vermutung eines systematischen Importfehlers (Wert 123 als Fehlercode?)
SELECT
person_age,
person_income,
person_emp_length,
loan_grade,
loan_status
FROM credit_risk
WHERE person_emp_length > 60
ORDER BY person_emp_length DESC;

-- Block, 1, Abfrage 3, AUFFAELLIGKEIT 3: Fehlende Werte (NULL)
-- loan_int_rate: 3116 NULLs (9.6%) - fast jeder 10. Kredit ohne dokumentierten Zinssatz
-- person_emp_length: 895 NULLs (2.7%)
SELECT
SUM(CASE WHEN loan_int_rate IS NULL THEN 1 ELSE 0 END) AS null_zinssatz,
SUM(CASE WHEN person_emp_length IS NULL THEN 1 ELSE 0 END) AS null_beschaeftigung
FROM credit_risk;

-- Block 1, Abfrage 4, AUFFAELLIGKEIT 4: loan_percent_income = 0
-- KEIN Datenfehler, sondern Rundungsartefakt bei sehr hohem Einkommen
-- Beweis: tatsaechliches Verhaeltnis (4 Nachkommastellen) ist > 0, wird aber auf 0.00 gerundet
SELECT
person_income,
loan_amnt,
loan_percent_income AS anteil_gerundet,
ROUND(loan_amnt / person_income, 4) AS anteil_tatsaechlich
FROM credit_risk
WHERE loan_percent_income = 0
ORDER BY person_income DESC;


-- Block 1, Abfrage 5, AUFFAELLIGKEIT 5a: Gesamtzahl der Faelle mit unmoeglicher Kredithistorie
-- Ergebnis: Unmögliche Kredithistorien (Gesamtzahl): 781 Fälle (2,4% des Datensatzes).
SELECT COUNT(*) AS anzahl_unmoegliche_historien
FROM credit_risk
WHERE cb_person_cred_hist_length > (person_age - 18);

-- Block 1, Abfrage 6, AUFFAELLIGKEIT 5b: Kredithistorie laenger als rechnerisch moeglich
-- Annahme: fruehestes Alter fuer ersten Kredit = 18 Jahre
-- --> max_moegliche_historie = person_age - 18
-- Ergebnis: 781 Faelle (2.4%), Differenz max. 2 Jahre - knappe Grenzfaelle, kein grobes Problem
SELECT
person_age,
cb_person_cred_hist_length,
(person_age - 18) AS max_moegliche_historie,
(cb_person_cred_hist_length - (person_age - 18)) AS differenz_jahre
FROM credit_risk
WHERE cb_person_cred_hist_length > (person_age - 18)
ORDER BY differenz_jahre DESC
LIMIT 20;

-- Block 1, Abfrage 7, AUFFAELLIGKEIT 6a: Beispiele fuer doppelt vorkommende Datensaetze
-- Gruppierung ueber alle 12 Spalten - identische Kombination = technisches Duplikat
SELECT
person_age, person_income, person_home_ownership, person_emp_length,
loan_intent, loan_grade, loan_amnt, loan_int_rate, loan_status,
loan_percent_income, cb_person_default_on_file, cb_person_cred_hist_length,
COUNT(*) AS anzahl
FROM credit_risk
GROUP BY
person_age, person_income, person_home_ownership, person_emp_length,
loan_intent, loan_grade, loan_amnt, loan_int_rate, loan_status,
loan_percent_income, cb_person_default_on_file, cb_person_cred_hist_length
HAVING COUNT(*) > 1
ORDER BY anzahl DESC
LIMIT 10;

-- Block 1, Abfrage 8, AUFFAELLIGKEIT 6b: Gesamtuebersicht Duplikate
-- anzahl_kombinationen = wie viele unterschiedliche Datensaetze sind doppelt
-- ueberzaehlige_zeilen = wie viele Zeilen wuerden bei Bereinigung entfernt
-- ausfallquote_duplikate = Vergleich zur Gesamtquote von 21.8%
-- 165 Kombinationen | 165 überzählige Zeilen | 38 Ausfälle 
-- | 11,5% Ausfallquote (unter Gesamtschnitt 21,8%)
SELECT
COUNT(*) AS anzahl_kombinationen,
SUM(anzahl - 1) AS ueberzaehlige_zeilen,
SUM(ausfaelle) AS gesamt_ausfaelle_duplikate,
ROUND(SUM(ausfaelle) / SUM(anzahl) * 100, 1) AS ausfallquote_duplikate
FROM (
SELECT
COUNT(*) AS anzahl,
SUM(loan_status) AS ausfaelle
FROM credit_risk
GROUP BY
person_age, person_income, person_home_ownership, person_emp_length,
loan_intent, loan_grade, loan_amnt, loan_int_rate, loan_status,
loan_percent_income, cb_person_default_on_file, cb_person_cred_hist_length
HAVING COUNT(*) > 1
) AS duplikate;

-- --- Block 2: Falsches Grading / nie zu vergebende Kredite ---

-- Block 2, Abfrage 1, AUFFAELLIGKEIT 7: Ausfallquote pro Loan Grade
-- Erwartung: kontinuierliche Steigerung A (niedrig) bis G (hoch)
-- Ergebnis: deutlicher Sprung von C (20.7%) zu D (59.1%) - fast Verdreifachung
-- Grade D-G liegen zwischen 59% und 98% Ausfallquote
-- A=10,0% | B=16,3% | C=20,7% | D=59,1% | E=64,4% 
-- | F=70,5% | G=98,4% — Sprung C→D auffällig.
SELECT
loan_grade,
COUNT(*) AS anzahl_gesamt,
SUM(loan_status) AS anzahl_ausfaelle,
ROUND(SUM(loan_status) / COUNT(*) * 100, 1) AS ausfallquote_prozent
FROM credit_risk
GROUP BY loan_grade
ORDER BY loan_grade;

-- Block 2, Abfrage 2, AUFFAELLIGKEIT 8: Durchschnittseinkommen korreliert NICHT mit Loan Grade
-- Erwartung: Einkommen sollte mit besserer Bonitaet (A) tendenziell hoeher sein
-- Ergebnis: A-D nahezu identisch (63664-66568), E-G sogar HOEHER (70873-77009)
-- --> Einkommen scheint beim Grading kaum eine Rolle zu spielen
 -- A=66.568 | B=66.355 | C=64.922 | D=63.664 | E=70.873 | F=77.009 | G=76.773 
SELECT
loan_grade,
COUNT(*) AS anzahl,
ROUND(AVG(person_income), 0) AS einkommen_avg,
ROUND(MIN(person_income), 0) AS einkommen_min,
ROUND(MAX(person_income), 0) AS einkommen_max
FROM credit_risk
GROUP BY loan_grade
ORDER BY loan_grade;

-- Block 2, Abfrage 3, AUFFAELLIGKEIT 9a: Kreditsumme > 50% des Jahreseinkommens - Gesamtzahl
-- Grenze 0.5 bewusst hoch gewaehlt, um nur Extremfaelle zu erfassen
-- Ergebnis: Anzahl: 248 Fälle (0,76% des Datensatzes).
SELECT COUNT(*) AS anzahl_extremfaelle
FROM credit_risk
WHERE loan_percent_income > 0.5;

-- Block 2, Abfrage 4, AUFFAELLIGKEIT 9b: Grade-Verteilung und Ausfallquote der Extremfaelle
-- KERNBEFUND: Grade A (n=53) und B (n=95) haben ~70% Ausfallquote
-- --> 148 von 248 Extremfaellen erhielten "gute" Bonitaet trotz extremer Kreditbelastung
-- --> systematisch falsches Grading bei loan_percent_income > 0.5
-- A=53/69,8% | B=95/70,5% | C=49/85,7% | D=32/96,9% | E=12/100% | F=7/85,7% 
-- — Bestnoten A/B mit ~70% Ausfallquote.
SELECT
loan_grade,
COUNT(*) AS anzahl,
SUM(loan_status) AS ausfaelle,
ROUND(SUM(loan_status) / COUNT(*) * 100, 1) AS ausfallquote_prozent
FROM credit_risk
WHERE loan_percent_income > 0.5
GROUP BY loan_grade
ORDER BY loan_grade;

-- Block 2, Abfrage 5, AUFFAELLIGKEIT 9c: Kreditnehmer mit BEIDEN Warnsignalen
-- (cb_person_default_on_file = 'Y' UND loan_percent_income > 0.5) - Grade-Verteilung
-- Verschaerfung von Auffaelligkeit 9b: zeigt ob selbst bei doppeltem Risikosignal
-- noch gute Grades (A/B/C) vergeben wurden
-- Ergebnis: C=27/77,8% | D=20/100% | E=2/100% | F=3/66,7% — kein A/B mehr vergeben, 
-- aber C mit 77,8% trotz "mittlerem Risiko".
SELECT
loan_grade,
COUNT(*) AS anzahl,
SUM(loan_status) AS ausfaelle,
ROUND(SUM(loan_status) / COUNT(*) * 100, 1) AS ausfallquote_prozent
FROM credit_risk
WHERE cb_person_default_on_file = 'Y'
AND loan_percent_income > 0.5
GROUP BY loan_grade
ORDER BY loan_grade;

-- Block 2, Abfrage 6, AUFFAELLIGKEIT 9d: Die 5 extremsten Einzelfaelle im Detail (absolute Zahlen)
-- Liefert konkrete Beispiele fuer "extrem hohe Kreditsumme bei niedrigem Einkommen"
-- fuer die Praesentation - direkter Bezug zur Formulierung der Aufgabenstellung
-- Ergebnis: Paradebeispiel: Einkommen 12.000 EUR, Kredit 9.325 EUR, Grade A, ausgefallen, kein Vorausfall.
SELECT
person_income,
loan_amnt,
loan_percent_income,
loan_grade,
loan_status,
cb_person_default_on_file
FROM credit_risk
ORDER BY loan_percent_income DESC
LIMIT 5;

-- Block 2, Abfrage 7, AUFFAELLIGKEIT 10: Zinssatz exakt 6.00 bei Grade B-E
-- Bei Grade A ist 6.00 einer von vielen Werten in einer kontinuierlichen Verteilung
-- Bei Grade B-E kommt NUR der Wert 6.00 vor, mit sehr kleinen Fallzahlen (5,3,2,1)
-- Moegliche Erklaerung: Platzhalterwert fuer urspruenglich fehlenden Zinssatz
-- (vgl. 3116 NULL-Werte bei loan_int_rate) - bei n<=5 statistisch nicht verifizierbar


SELECT
loan_grade,
loan_int_rate,
COUNT(*) AS anzahl
FROM credit_risk
WHERE loan_int_rate <= 6.5
GROUP BY loan_grade, loan_int_rate
ORDER BY loan_grade, loan_int_rate;


-- Block 3: Weitere Risikofaktoren ---

-- Block 3, Abfrage 1, AUFFAELLIGKEIT 11: Gesamt-Ausfallquote als Referenzwert
-- Dient als Vergleichsmaßstab fuer alle nachfolgenden Teilgruppen-Analysen
-- Ergebnis 32.581 Gesamt | 7.108 Ausfälle | 21,8% (deutlich über Branchenschnitt 2–5%).
SELECT
COUNT(*) AS anzahl_gesamt,
SUM(loan_status) AS anzahl_ausfaelle,
ROUND(SUM(loan_status) / COUNT(*) * 100, 1) AS ausfallquote_prozent
FROM credit_risk;

-- Block 3, Abfrage 2, AUFFAELLIGKEIT 12: Wohnsituation (person_home_ownership) - Ausfallquote und Einkommen
-- RENT=16.446/31,6% | MORTGAGE=13.444/12,6% | OWN=2.584/7,5% | OTHER=107/30,8% 
-- RENT = 50.5% des Datensatzes mit hoechster Ausfallquote (31.6%) bei niedrigstem
-- Durchschnittseinkommen (54998) - moeglicher Risikofaktor, aber vermutlich vermittelt
-- ueber Einkommen/Alter, keine isolierte Kausalaussage moeglich
SELECT
person_home_ownership,
COUNT(*) AS anzahl,
ROUND(AVG(person_income), 0) AS einkommen_avg,
SUM(loan_status) AS ausfaelle,
ROUND(SUM(loan_status) / COUNT(*) * 100, 1) AS ausfallquote_prozent
FROM credit_risk
GROUP BY person_home_ownership
ORDER BY anzahl DESC;

-- Block 3, Abfrage 3, AUFFAELLIGKEIT 13: Verwendungszweck (loan_intent) - Ausfallquote
-- Spanne von 14.8% (VENTURE) bis 28.6% (DEBTCONSOLIDATION) - fast Faktor 2
-- DEBTCONSOLIDATION/MEDICAL/HOMEIMPROVEMENT ueber Durchschnitt (21.8%)
-- VENTURE/EDUCATION unter Durchschnitt - planbarere Verwendungszwecke
SELECT
loan_intent,
COUNT(*) AS anzahl,
SUM(loan_status) AS ausfaelle,
ROUND(SUM(loan_status) / COUNT(*) * 100, 1) AS ausfallquote_prozent
FROM credit_risk
GROUP BY loan_intent
ORDER BY ausfallquote_prozent DESC;

-- Block 3, Abfrage 4, AUFFAELLIGKEIT 14: Kombination loan_percent_income + cb_person_default_on_file
-- VORSTUFE FÜR AUFGABE 2 - zeigt wie sich beide Faktoren gegenseitig verstaerken
-- Spanne: 11.7% (niedrige Belastung, kein Vorausfall) bis 86.5% (hohe Belastung + Vorausfall)
-- Schwelle 0.3 zeigt den groessten Sprung (11.7% -> 62.9% bzw. 31.9% -> 71.9%)
-- niedrig+N=11,7% | niedrig+Y=31,9% | mittel+N=62,9% | mittel+Y=71,9% | hoch+N=76,5% 
-- | hoch+Y=86,5% — Spanne Faktor 7, größter Sprung bei Schwelle 0,3.
SELECT
CASE
WHEN loan_percent_income < 0.3 THEN 'niedrig (<0.3)'
WHEN loan_percent_income BETWEEN 0.3 AND 0.5 THEN 'mittel (0.3-0.5)'
ELSE 'hoch (>0.5)'
END AS belastungsstufe,
cb_person_default_on_file,
COUNT(*) AS anzahl,
SUM(loan_status) AS ausfaelle,
ROUND(SUM(loan_status) / COUNT(*) * 100, 1) AS ausfallquote_prozent
FROM credit_risk
GROUP BY belastungsstufe, cb_person_default_on_file
ORDER BY belastungsstufe, cb_person_default_on_file;

-- ZUSATZ A1: Worst-Case-Gruppe - alle drei Warnsignale gleichzeitig
-- (Kreditbelastung > 0.3 UND Vorausfall in Historie UND schlechtes Grade D-G)
-- Liefert die Gruppe, die in Aufgabe 2 als "hohes Risiko" eingestuft werden sollte
-- Ergebnis: 387 Kredite, 322 Ausfälle, 83,2% Ausfallquote (Faktor 3,8 über Gesamtschnitt 21,8%)

SELECT
COUNT(*) AS anzahl_worstcase,
SUM(loan_status) AS ausfaelle,
ROUND(SUM(loan_status) / COUNT(*) * 100, 1) AS ausfallquote_prozent
FROM credit_risk
WHERE loan_percent_income > 0.3
AND cb_person_default_on_file = 'Y'
AND loan_grade IN ('D', 'E', 'F', 'G');

-- ZUSATZ A2: Worst-Case-Gruppe aufgeschlüsselt nach Grade
-- Zeigt Verteilung innerhalb D-G
-- Ergebnis: D=273/83,2% | E=87/83,9% | F=20/75,0% | G=7/100% - Grade D dominiert (70,5% der Worst-Case-Gruppe) mit stabil hoher Quote über alle Stufen


SELECT
loan_grade,
COUNT(*) AS anzahl,
SUM(loan_status) AS ausfaelle,
ROUND(SUM(loan_status) / COUNT(*) * 100, 1) AS ausfallquote_prozent
FROM credit_risk
WHERE loan_percent_income > 0.3
AND cb_person_default_on_file = 'Y'
AND loan_grade IN ('D', 'E', 'F', 'G')
GROUP BY loan_grade
ORDER BY loan_grade;

-- ZUSATZ B1: Finanzieller Schaden der Worst-Case-Gruppe (vgl. Zusatz G)
-- Übersetzt den Anzahl-Befund in EUR-Volumen
-- Ergebnis: 387 Kredite | Volumen 6,9 Mio EUR | Ausfall 5,58 Mio EUR | 
-- Verlustquote 80,9% (leicht unter Stück-Quote 83,2% - ausgefallene Kredite tendenziell etwas kleiner)

SELECT
COUNT(*) AS anzahl_kredite,
SUM(loan_amnt) AS gesamtvolumen_eur,
SUM(CASE WHEN loan_status = 1 THEN loan_amnt ELSE 0 END) AS ausgefallenes_volumen_eur,
ROUND(SUM(CASE WHEN loan_status = 1 THEN loan_amnt ELSE 0 END) / SUM(loan_amnt) * 100, 1) AS verlustquote_volumen_prozent
FROM credit_risk
WHERE loan_percent_income > 0.3
AND cb_person_default_on_file = 'Y'
AND loan_grade IN ('D', 'E', 'F', 'G');

-- ZUSATZ B2: Finanzieller Schaden der falsch bewerteten Bestnoten
-- (Grade A oder B mit loan_percent_income > 0.5 - vgl. Abfrage 9b)
-- Übersetzt den Kernbefund aus 9b (Fehlgrading bei Extremfällen) in EUR
-- Ergebnis: 148 Kredite | Volumen 2,59 Mio EUR | Ausfall 1,66 Mio EUR 
-- | Verlustquote 64,3% (deutlich unter Stück-Quote ~70% - ausgefallene Bestnoten-Kredite kleiner als überlebende)

SELECT
COUNT(*) AS anzahl_kredite,
SUM(loan_amnt) AS gesamtvolumen_eur,
SUM(CASE WHEN loan_status = 1 THEN loan_amnt ELSE 0 END) AS ausgefallenes_volumen_eur,
ROUND(SUM(CASE WHEN loan_status = 1 THEN loan_amnt ELSE 0 END) / SUM(loan_amnt) * 100, 1) AS verlustquote_volumen_prozent
FROM credit_risk
WHERE loan_percent_income > 0.5
AND loan_grade IN ('A', 'B');

-- ZUSATZ B3: Gesamt-Ausfallvolumen über alle Kredite (Referenzwert)
-- EUR-Gegenstück zur Abfrage 11 (Gesamt-Ausfallquote 21,8%)
-- Dient als Vergleichsmassstab für H1 und H2
-- Ergebnis: Portfolio 312,4 Mio EUR | Ausfall 77,1 Mio EUR 
-- | Verlustquote 24,7% (höher als Stück-Quote 21,8% - ausgefallene Kredite tendenziell größer als überlebende)
-- Schlüsselbefund: H1+H2 = 535 Kredite (1,6% des Portfolios) = 7,24 Mio EUR Verlust = 9,4% des Gesamtschadens (sechsfache Überrepräsentation)

SELECT
SUM(loan_amnt) AS gesamtvolumen_eur,
SUM(CASE WHEN loan_status = 1 THEN loan_amnt ELSE 0 END) AS ausgefallenes_volumen_eur,
ROUND(SUM(CASE WHEN loan_status = 1 THEN loan_amnt ELSE 0 END) / SUM(loan_amnt) * 100, 1) AS verlustquote_volumen_prozent
FROM credit_risk;

-- ZUSATZ C1: Kreditnehmer mit Beschäftigungsdauer = 0 Jahre
-- Untere Grenze als eigenständige Auffälligkeit (Ergänzung zu Abfrage 2)
-- Fachlich: keine stabile Einkommenshistorie vorhanden
-- Ergebnis: 4.105 Fälle (12,6% des Datensatzes)

SELECT COUNT(*) AS anzahl_emp_length_null
FROM credit_risk
WHERE person_emp_length = 0;

-- ZUSATZ C2: Ausfallquote der Beschäftigungsdauer = 0 Gruppe
-- Vergleich zur Gesamt-Ausfallquote 21,8% (Abfrage 11)
-- Ergebnis: 4.105 Fälle | 1.147 Ausfälle | 27,9% Ausfallquote 
-- (nur Faktor 1,3 über Gesamtschnitt - moderat erhöht)

SELECT
COUNT(*) AS anzahl,
SUM(loan_status) AS ausfaelle,
ROUND(SUM(loan_status) / COUNT(*) * 100, 1) AS ausfallquote_prozent
FROM credit_risk
WHERE person_emp_length = 0;

-- ZUSATZ C3: Grade-Verteilung der Beschäftigungsdauer = 0 Gruppe
-- Erwartung: bei fehlender Beschäftigungshistorie eher schlechtere Grades
-- Auffälligkeit: falls viele A/B Grades vergeben wurden
-- -- Ergebnis: A=1304/12,7% | B=1224/19,6% | C=920/22,6% | D=456/79,0% 
-- | E=153/85,0% | F=40/87,5% | G=8/100%
-- Kernbefund: nicht die Ausfallquote, sondern die Vergabepraxis 
-- (Bestnoten ohne dokumentierte Beschäftigung)

SELECT
loan_grade,
COUNT(*) AS anzahl,
SUM(loan_status) AS ausfaelle,
ROUND(SUM(loan_status) / COUNT(*) * 100, 1) AS ausfallquote_prozent
FROM credit_risk
WHERE person_emp_length = 0
GROUP BY loan_grade
ORDER BY loan_grade;

-- ============================================
-- AUFGABE 2: Risikokategorisierung (CASE WHEN)
-- ============================================

-- Warnsignale: Belastung, Vorgeschichte, Bonität
-- Hoch    = mindestens 2 von 3 Warnsignalen aktiv
-- Mittel  = genau 1 Warnsignal aktiv
-- Niedrig = 0 Warnsignale aktiv

-- ============================================================
-- AUFGABE 2: Risikokategorisierung in 3 Gruppen (Hoch/Mittel/Niedrig)
-- Logik: Zählung der aktiven Warnsignale aus Aufgabe 1
-- Schwellenwerte aus Aufgabe 1 abgeleitet und belegt:
--   Warnsignal 1: loan_percent_income > 0.3 (Abfrage 14: Sprung 11,7% -> 62,9%)
--   Warnsignal 2: cb_person_default_on_file = 'Y' (Abfrage 14: 11,7% -> 31,9%)
--   Warnsignal 3: loan_grade IN ('D','E','F','G') (Abfrage 7: Sprung 20,7% -> 59,1%)
-- Einteilung:
--   Hoch    = mindestens 2 von 3 Warnsignalen aktiv
--   Mittel  = genau 1 Warnsignal aktiv
--   Niedrig = kein Warnsignal aktiv
-- ============================================================


-- AUFGABE 2a: Klassifikation aller Kreditnehmer in Risikogruppen
-- Liefert eine zusätzliche Spalte risiko_kategorie pro Datensatz
-- Grundlage für alle nachfolgenden Auswertungen

SELECT person_age, person_income, loan_grade,
loan_percent_income, cb_person_default_on_file,
loan_status,
CASE
WHEN (CASE WHEN loan_percent_income > 0.3 THEN 1 ELSE 0 END)
+ (CASE WHEN cb_person_default_on_file = 'Y' THEN 1 ELSE 0 END)
+ (CASE WHEN loan_grade IN ('D','E','F','G') THEN 1 ELSE 0 END) >= 2
THEN 'Hohes Risiko'
WHEN (CASE WHEN loan_percent_income > 0.3 THEN 1 ELSE 0 END)
+ (CASE WHEN cb_person_default_on_file = 'Y' THEN 1 ELSE 0 END)
+ (CASE WHEN loan_grade IN ('D','E','F','G') THEN 1 ELSE 0 END) = 1
THEN 'Mittleres Risiko'
ELSE 'Niedriges Risiko'
END AS risiko_kategorie
FROM credit_risk;


-- AUFGABE 2b: Verteilung der Risikogruppen prüfen
-- Anforderung: ausgewogen im Sinne der Bank
-- (nicht zu viele in Hoch = Geschäftsverlust, nicht zu viele in Niedrig = Risikounterschätzung)
-- Ergebnis: Niedrig 21.750/66,8% | Mittel 7.575/23,3% | Hoch 3.256/10,0% (ausgewogen)

SELECT
risiko_kategorie,
COUNT(*) AS anzahl,
ROUND(COUNT(*) / 32581 * 100, 1) AS anteil_prozent
FROM (
SELECT
CASE
WHEN (CASE WHEN loan_percent_income > 0.3 THEN 1 ELSE 0 END)
+ (CASE WHEN cb_person_default_on_file = 'Y' THEN 1 ELSE 0 END)
+ (CASE WHEN loan_grade IN ('D','E','F','G') THEN 1 ELSE 0 END) >= 2
THEN 'Hohes Risiko'
WHEN (CASE WHEN loan_percent_income > 0.3 THEN 1 ELSE 0 END)
+ (CASE WHEN cb_person_default_on_file = 'Y' THEN 1 ELSE 0 END)
+ (CASE WHEN loan_grade IN ('D','E','F','G') THEN 1 ELSE 0 END) = 1
THEN 'Mittleres Risiko'
ELSE 'Niedriges Risiko'
END AS risiko_kategorie
FROM credit_risk
) AS klassifiziert
GROUP BY risiko_kategorie
ORDER BY anzahl DESC;


-- AUFGABE 2c: Validierung - tatsächliche Ausfallquote pro Risikogruppe
-- Erwartung: Niedrig < Gesamt-Schnitt 21,8% < Mittel < Hoch (saubere Staffelung)
-- Ergebnis: Hoch 65,3% | Mittel 43,4% | Niedrig 7,8% - drei klar getrennte Stufen,
-- Hoch = 3x Gesamtschnitt, Niedrig = 1/3 Gesamtschnitt
-- Kernbefund: 10% des Portfolios (Hohes Risiko) verantwortet 30% aller Ausfälle
-- (2.126 von 7.108 Gesamtausfällen aus Abfrage 11)

SELECT
risiko_kategorie,
COUNT(*) AS anzahl,
SUM(loan_status) AS ausfaelle,
ROUND(SUM(loan_status) / COUNT(*) * 100, 1) AS ausfallquote_prozent
FROM (
SELECT
loan_status,
CASE
WHEN (CASE WHEN loan_percent_income > 0.3 THEN 1 ELSE 0 END)
+ (CASE WHEN cb_person_default_on_file = 'Y' THEN 1 ELSE 0 END)
+ (CASE WHEN loan_grade IN ('D','E','F','G') THEN 1 ELSE 0 END) >= 2
THEN 'Hohes Risiko'
WHEN (CASE WHEN loan_percent_income > 0.3 THEN 1 ELSE 0 END)
+ (CASE WHEN cb_person_default_on_file = 'Y' THEN 1 ELSE 0 END)
+ (CASE WHEN loan_grade IN ('D','E','F','G') THEN 1 ELSE 0 END) = 1
THEN 'Mittleres Risiko'
ELSE 'Niedriges Risiko'
END AS risiko_kategorie
FROM credit_risk
) AS klassifiziert
GROUP BY risiko_kategorie
ORDER BY ausfallquote_prozent DESC;
