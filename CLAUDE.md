# CLAUDE.md

@AGENTS.md
@MEIN-SYSTEM.md
@01_Basiskontext/Identity.md
@01_Basiskontext/Persoenlichkeit\ und\ Muster.md
@01_Basiskontext/Voice\ and\ Style.md

**Enthält ein Dateiname ein Leerzeichen, muss es im Import mit einem Backslash maskiert werden** (`Voice\ and\ Style.md`). Ohne die Maskierung liest der Importparser den Pfad nur bis zum ersten Leerzeichen, die Datei kommt nie im Kontext an, und die Zeile sieht trotzdem richtig aus. Am 26.08.2026 empirisch nachgewiesen; der Health-Check prüft es seither. Anführungszeichen um den Pfad helfen nicht.

Die obigen Dateien werden per Import zwingend in jede Session geladen, nicht als Leseempfehlung. `AGENTS.md` trägt die Arbeitsregeln (Mechanik, wird bei Updates ersetzt), `MEIN-SYSTEM.md` die persönliche Ebene darüber (wer `[NAME]` ist, wie das System hier heisst, eigene Regeln; wird bei Updates nie angefasst, und bei Widerspruch gilt sie). `01_Basiskontext` ist der dauerhafte Kernkontext über dich, deinen Stil und deine laufenden Ziele (Details: `01_Basiskontext\README.md`).

Themenordner enthalten eigene lokale `AGENTS.md` mit Rollen-Definitionen: Lies die lokale AGENTS.md jedes Ordners, in dem du inhaltlich arbeitest (Details regelt die Root-AGENTS.md, Abschnitt Rollen). Diese werden NICHT automatisch importiert, da sie themenspezifisch und nicht bei jeder Session relevant sind; hier bleibt ein aktiver Lese-Schritt nötig.

> Hinweis für den Aufbau (diese Zeile nach dem Einrichten löschen): Wenn du Dateien in `01_Basiskontext` umbenennst oder weitere hinzufügst, ziehst du die `@`-Zeilen oben und in `GEMINI.md` mit. Der Health-Check prüft das und meldet sich, wenn eine Datei nicht importiert wird.
