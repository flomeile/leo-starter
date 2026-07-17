---
titel: Modellwahl
zweck: Aktuelle Modellempfehlungen für den Betrieb des Systems
type: referenz
stand: 2026-07-17
---

# Modellwahl (Stand: siehe `stand:` im Frontmatter)

Die Modell-Landschaft ändert sich schnell. Diese Datei ist bewusst datiert: Ist der Stand älter als 3 Monate, soll das LLM darauf hinweisen und auf Zuruf ("modellwahl aktualisieren") per Websuche aktualisieren (Preise pro 1M Tokens Input/Output, Tool-Calling-Qualität, neue Herausforderer; Anweisung am Ende dieser Datei). Die konkreten Modellnamen unten sind ein Ausgangspunkt vom Juli 2026, kein Dauerstand.

## Empfehlung für den Normalbetrieb (Chat-Harness, überwiegend lesend)

Anforderungen: zuverlässiges mehrstufiges Tool-Calling (Index lesen, suchen, Treffer lesen), gutes Deutsch, niedriger Preis.

1. **Claude Haiku 4.5** (sicherer Default): zuverlässiges Tool-Calling, günstig, stark mit Prompt-Caching. Bei der Agentic Search zählt Werkzeug-Zuverlässigkeit mehr als der letzte Cent, denn fehlgeschlagene Suchketten kosten mehr, als sie sparen.
2. **Günstigere Herausforderer** (z.B. offene Gewichte wie die GLM-Reihe): oft in Tool-Use-Benchmarks stark und deutlich billiger; im eigenen Betrieb testen, bevor sie zum Default werden.
3. **Budget für Massenarbeit** (z.B. DeepSeek-Klasse): sehr günstig für einfache Abfragen; bei mehrstufigen Suchketten weniger verlässlich.

## Empfehlung nach Aufgabe

| Aufgabe | Modell |
|---|---|
| Wissensfragen, Alltag (Chat-Harness) | Haiku-Klasse (Default) oder ein günstigerer Herausforderer (testen) |
| Anspruchsvolles Sparring, Redigat, Strategie | Frontier-Modell (z.B. Claude Sonnet in aktueller Version) |
| Bau-/Wartungsarbeit (Coding-Agent) | Standard-Modell des Coding-Agents; Opus-Klasse nur für echte Architekturarbeit |
| Verarbeitung von PDFs/Scans (Vision nötig) | Modell mit Vision, Sonnet-Klasse oder stärker (Bild-/Handschrift-Erkennung hängt an der Modellqualität) |
| Sensible Inhalte ohne Cloud | lokales Modell (Qualität geringer; nur wenn Datenschutz es verlangt) |

Prompt-Caching aktivieren, wo das Harness es anbietet: Bei Agentic Search wird derselbe Kontext pro Tool-Call wiederholt; ohne Caching zahlt man ihn jedes Mal voll.

## Claude-Abo (Claude Code / Desktop-App): Modell und Effort je Aufgabe

Effort-Stufen (Low, Medium, High als Default, Extra/"xhigh", Max) erhöhen Denk-Tokens und Tool-Runden, also den Verbrauch. Faustregeln:

- Innerhalb eines Modells bringt Effort über High schnell abnehmenden Ertrag. Der bessere Hebel ab dort ist die nächsthöhere Modellklasse auf Medium/High.
- Die neuesten Modelle leisten auf niedrigen Stufen bereits viel. Im Zweifel eine Effort-Stufe runter, im Zweifel beim Modell eine Klasse rauf.
- Für Sparring mit erwünschtem Widerspruch die stärkere, rigorosere Modellklasse wählen; explizite Anweisungen im Basiskontext übersteuern die Modell-Defaults ohnehin weitgehend.

| Aufgabe | Modell | Effort |
|---|---|---|
| Wissensfragen, kleine Dateipflege | Sonnet-Klasse | Medium |
| Wrap-Up, Health-Check, normale Bauarbeit | Sonnet-Klasse | High |
| Anspruchsvolles Sparring, Redigat, Strategie | Opus-Klasse | High |
| Fehler wäre sehr teuer, Kosten zweitrangig | Opus-Klasse | Max (neigt zum Überdenken, gezielt einsetzen) |

Modell-Check vor Arbeitsbeginn: siehe Root-`AGENTS.md`, Abschnitt 13 (Wechselvorschlag nur, bevor Kontext eingelesen wurde).

## Anweisung zur Aktualisierung (für das LLM)

1. Websuche: aktuelle Preise und Tool-Calling-Bewertungen der oben genannten Modellklassen plus neue Herausforderer (Quellen z.B. openrouter.ai, artificialanalysis.ai, Anbieter-Doku).
2. Empfehlungen neu begründen, Tabelle und Stand-Datum aktualisieren. Nichts ungeprüft aus dem Trainingswissen übernehmen; Preise nur mit aktueller Quelle.
3. Die Änderungen in 3 Sätzen zusammenfassen.
