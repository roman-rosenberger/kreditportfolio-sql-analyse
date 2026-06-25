# Datenanalyse Kreditportfolio — Risikoklassifikation in MySQL

> SQL-basierte Analyse eines Konsumentenkredit-Portfolios (32.581 Datensätze, 12 Spalten) zur Aufdeckung von Missständen in der Kreditvergabe und zur Klassifikation der Kreditnehmer in drei Risikogruppen. Abschlussprojekt für die IHK-Weiterbildung Data Analyst bei DataSmart Point. Alle Erkenntnisse stammen direkt aus MySQL-Abfragen; Visualisierungen dienen ausschließlich der Präsentationsunterstützung.

---

## Projektüberblick

Das ist eine Projektarbeit für das Modul **Datenbanken und SQL** im Rahmen der IHK-Weiterbildung Data Analyst bei DataSmart Point (Juni 2026).

Auftrag eines fiktiven Finanzdienstleisters: Ein Bereichsvorstand vermutet Probleme in der bisherigen Kreditvergabe und benötigt eine datenbasierte Analyse, um die Kreditüberwachung zu verbessern. Auf Grundlage eines Datensatzes von 32.581 Konsumentenkrediten wurden zwei Pflichtaufgaben bearbeitet:

1. **Aufdeckung von Missständen** in der bestehenden Kreditvergabe
2. **Klassifikation der Kreditnehmer** in drei Risikogruppen mittels `CASE WHEN`

Die gesamte Analyse erfolgt ausschließlich in MySQL. Visualisierungen dienen ausschließlich der Präsentationsunterstützung; alle Kennzahlen stammen direkt aus SQL-Abfragen.

---

## Datensatz

| Kennzahl | Wert |
|---|---|
| Anzahl Datensätze | 32.581 |
| Anzahl Spalten | 12 |
| Themenbereich | Konsumentenkredite an Privatpersonen |
| Tool | MySQL Workbench |

**Spalten:** person_age, person_income, person_home_ownership, person_emp_length, loan_intent, loan_grade, loan_amnt, loan_int_rate, loan_status, loan_percent_income, cb_person_default_on_file, cb_person_cred_hist_length

---

## Methodisches Vorgehen

Die Analyse folgte einer dreistufigen Logik:

1. **Datenqualität prüfen** — NULL-Werte, Plausibilität, Duplikate
2. **Auffälligkeiten identifizieren** — Fehlgrading, Extremfälle, Kombinationsrisiken
3. **Risikoklassifikation aufbauen** — auf belegten Schwellenwerten aus Schritt 1 und 2

Insgesamt wurden **29 SQL-Abfragen** entwickelt: 21 Pflichtabfragen plus 8 Zusatzabfragen zur finanziellen Quantifizierung und Vertiefung.

---

## Kernergebnisse

### Datenqualität

| Befund | Anzahl |
|---|---|
| Unrealistisches Alter (über 80 Jahre) | 7 Fälle |
| Unplausible Beschäftigungsdauer (über 60 Jahre) | 2 Fälle |
| Fehlende Zinssätze | 3.116 (9,6 %) |
| Fehlende Beschäftigungsdauer | 895 (2,7 %) |
| Unmögliche Kredithistorien | 781 (2,4 %) |
| Vollständige Duplikate | 165 |

Die wiederholten Werte 123 und 144 in verschiedenen Spalten deuten auf einen systematischen Importfehler hin, nicht auf Zufallstreffer.

### Bestnoten-Fehlgrading

Bei Krediten mit Bestbewertung A oder B und einer Kreditbelastung über 50 Prozent des Jahreseinkommens liegt die Ausfallquote bei rund 70 Prozent — bei einer Bewertung, die per Definition niedriges Risiko signalisieren soll. Insgesamt 148 Kredite betroffen, finanzieller Schaden 1,66 Mio. EUR.

### Worst-Case-Gruppe

387 Kredite weisen drei unabhängige Warnsignale gleichzeitig auf (Kreditbelastung über 30 Prozent, Vorausfall in der Historie, Bonitätsstufe D bis G). Ausfallquote in dieser Gruppe: 83,2 Prozent — Faktor 3,8 über dem Gesamtschnitt von 21,8 Prozent. Finanzieller Schaden: 5,58 Mio. EUR.

### Aggregat-Befund

**1,6 Prozent der Kreditnehmer verursachen 9,4 Prozent des Gesamtschadens** — eine sechsfache Überrepräsentation. Diese Gruppe ist vor Kreditvergabe anhand klar definierter SQL-Kriterien identifizierbar.

### Risikoklassifikation (Aufgabe 2)

Klassifikation über die Zählung dreier Warnsignale:

| Risikogruppe | Anteil Portfolio | Tatsächliche Ausfallquote |
|---|---|---|
| Niedriges Risiko (kein Warnsignal) | 66,8 % | 7,8 % |
| Mittleres Risiko (1 Warnsignal) | 23,3 % | 43,4 % |
| Hohes Risiko (2-3 Warnsignale) | 10,0 % | 65,3 % |

Die Klassifikation differenziert sauber: Die Ausfallquoten sind um Faktor 8 zwischen niedriger und hoher Gruppe gespreizt. **10 Prozent des Portfolios verantworten 30 Prozent aller Ausfälle.**

---

## Handlungsempfehlungen

Drei konkrete Maßnahmen wurden auf Basis der Analyse abgeleitet:

1. **Automatische Vergabesperre** für die Worst-Case-Kombination (Belastung >30 % + Vorausfall + Grade D-G)
2. **Grading-Reform** mit Hard-Constraint: Bestnoten A/B werden bei loan_percent_income über 50 % technisch blockiert
3. **Beschäftigungshistorie stärker gewichten**: Aktuell erhalten 61,6 % der Kreditnehmer ohne dokumentierte Beschäftigung Bestnoten A oder B

---

## Eingesetzte SQL-Konzepte

- Aggregatfunktionen (`COUNT`, `SUM`, `AVG`, `MIN`, `MAX`)
- Gruppierung über mehrere Spalten (`GROUP BY`)
- Gefilterte Aggregation (`HAVING`)
- Bedingte Logik (`CASE WHEN ... THEN ... ELSE ... END`)
- Subqueries (verschachtelte Aggregation)
- Berechnete Spalten und Zeilenvergleiche
- `BETWEEN`, `IN`, `IS NULL` für Filterlogik
- Volumenbasierte Auswertungen (`SUM(loan_amnt)`)

---

## Dateien im Repository

## Dateien im Repository

| Datei | Inhalt |
|---|---|
| `kreditportfolio_analyse.sql` | Vollständig kommentiertes SQL-Skript mit allen 29 Abfragen |
| `Projektarbeit_Roman_Rosenberger_Juni_2026.pdf` | 10-Slide-Präsentation mit Befunden und Handlungsempfehlungen |
| `README.md` | Diese Datei |

---

## Verwendete Tools

- **MySQL Workbench** — alle Analysen
- **PowerPoint / Gamma AI** — Präsentationserstellung
- **Datawrapper** — Grafikerstellung auf Basis der SQL-Ergebnisse

---

## Autor

**Roman Rosenberger**
Quereinsteiger Data Analyst mit über zehn Jahren Erfahrung im Immobilienvertrieb. Aktuell in der IHK-Weiterbildung Data Analyst bei DataSmart Point (Abschluss April 2027). Fokus: Real Estate Data Analytics, ESG-Reporting, Portfolioanalysen.

[LinkedIn-Profil](https://www.linkedin.com/in/roman-rosenberger/) · Frankfurt am Main · Juni 2026

---

## Hinweis

Der verwendete Datensatz ist ein öffentlich verfügbarer Übungsdatensatz aus dem Bereich Credit Risk. Die Analyse und die abgeleiteten Empfehlungen sind als methodische Übung zu verstehen — sie ersetzen keine professionelle Kreditprüfung oder regulatorische Bewertung.
