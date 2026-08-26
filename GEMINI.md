# GEMINI.md

@./AGENTS.md
@./MEIN-SYSTEM.md
@./01_Basiskontext/Identity.md
@./01_Basiskontext/Persoenlichkeit\ und\ Muster.md
@./01_Basiskontext/Voice\ and\ Style.md

Die obigen Dateien werden per Import zwingend in jede Session geladen, nicht als Leseempfehlung. `AGENTS.md` trägt die Arbeitsregeln (Mechanik, wird bei Updates ersetzt), `MEIN-SYSTEM.md` die persönliche Ebene darüber (wer `[NAME]` ist, wie das System hier heisst, eigene Regeln; wird bei Updates nie angefasst, und bei Widerspruch gilt sie). `01_Basiskontext` ist der dauerhafte Kernkontext über dich, deinen Stil und deine laufenden Ziele (Details: `01_Basiskontext\README.md`).

Themenordner enthalten eigene lokale `AGENTS.md` mit Rollen-Definitionen: Lies die lokale AGENTS.md jedes Ordners, in dem du inhaltlich arbeitest (Details regelt die Root-AGENTS.md, Abschnitt Rollen). Diese werden NICHT automatisch importiert, da sie themenspezifisch und nicht bei jeder Session relevant sind; hier bleibt ein aktiver Lese-Schritt nötig.

**Hinweis zur Import-Syntax:** Gemini CLI unterstützt den Memory Import Processor mit `@`-Syntax; relative Pfade müssen mit `./` oder `../` beginnen, maximale Verschachtelung 5 Ebenen, `@` in Code-Blöcken wird ignoriert. Diese Datei nutzt deshalb `@./` statt der `@`-Form aus `CLAUDE.md`, die Claude Code verwendet. Offen ist, ob Gemini CLI Importpfade mit Leerzeichen im Dateinamen zuverlässig auflöst. Falls nicht, greift der Import stillschweigend nicht, und dann gilt die textliche Anweisung oben als Rückfallebene: Lies `AGENTS.md` und alle Dateien in `01_Basiskontext` vollständig, bevor du inhaltlich antwortest. Wer das erste Mal mit Gemini CLI in diesem Repo arbeitet, prüft mit `/memory show`, ob die vier Dateien wirklich geladen sind.
