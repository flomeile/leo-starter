---
titel: Kern-Dateien
zweck: Legt fest, welche Dateien zum Grundgerüst gehören und bei einem Update ersetzt werden dürfen, und welche dir gehören
type: systemdoku
version: 1.6-starter
stand: 2026-08-07
---

# Kern-Dateien: was ein Update anfassen darf

Diese Liste ist die Grundlage für den Skill `leo-mechanik-update`. Sie beantwortet eine einzige Frage: Wenn das Grundgerüst weiterentwickelt wird, welche Dateien dürfen bei dir ersetzt werden, ohne dass etwas von dir verloren geht.

Drei Kategorien, und die Zuordnung ist bindend.

## A. Kern: wird bei einem Update ersetzt

Diese Dateien sind Mechanik. Sie sind bei allen Nutzern identisch und sollen es bleiben. **Editiere sie nicht.** Was du ändern willst, gehört nach `MEIN-SYSTEM.md`.

| Datei | Was sie tut |
|---|---|
| `AGENTS.md` | Die Arbeitsregeln. Enthält bewusst keine Namen und keine Pfade, die aufgelöst werden müssten |
| `10_System\Kern-Dateien.md` | Diese Liste |
| `02_Skills\leo-mechanik-update.md` | Der Update-Skill selbst |
| `02_Skills\leo-wrap-up.md` | Kern-Skill |
| `02_Skills\leo-system-health-check.md` | Kern-Skill |
| `02_Skills\leo-themenordner-anlegen.md` | Kern-Skill |
| `02_Skills\leo-skill-ersteller.md` | Kern-Skill |
| `02_Skills\README.md` | Erklärt, was ein Skill ist |
| `00_INDEX\scripts\build-index-geruest.ps1` | Index-Automatik |
| `00_INDEX\scripts\health-check.ps1` | Prüfskript |
| `00_INDEX\scripts\build-skill-wrapper.ps1` | Erzeugt die Skill-Zeiger für alle Werkzeuge (Abschnitt 11a) |
| `00_INDEX\githooks\pre-commit` | Schutz vor beschädigten Commits |
| `.gitattributes` | Zeilenenden-Behandlung |

Die generierten Skill-Zeiger in `.claude\skills\`, `.agents\skills\`, `.gemini\skills\`, `.cursor\skills\`, `.cline\skills\` und `.opencode\skills\` stehen bewusst in keiner der drei Kategorien: Sie werden bei jedem Health-Check neu aus deinem Register erzeugt und sind jederzeit wegwerfbar. Ein Update muss sie weder ersetzen noch schützen. Eigene Skills, die du dort liegen siehst, sind kein Verlust, wenn sie verschwinden: Die Wahrheit steht in `02_Skills`.

Ausnahme innerhalb dieser Dateien: **Inhalte von `AUTO:...:BEGIN/END`-Blöcken gehören nie zum Kern.** Sie werden maschinell erzeugt (z.B. die Rollen-Tabelle in der `AGENTS.md`) und nach einem Update ohnehin neu geschrieben, sobald das Index-Skript läuft.

## B. Kern mit lokalem Anteil: wird eingearbeitet, nie ersetzt

Diese Dateien sind Mechanik, tragen aber zwingend etwas von dir. Ein Update darf sie nur inhaltlich nachziehen und muss deinen Anteil erhalten.

| Datei | Dein Anteil |
|---|---|
| `CLAUDE.md` | Die `@`-Importzeilen, die auf deine Basiskontext-Dateien zeigen |
| `GEMINI.md` | dasselbe |
| `.clinerules` | dasselbe, hier als textliche Leseanweisung statt als Import |
| `.github\copilot-instructions.md` | dasselbe |
| `ANLEITUNG.md` | Nichts, solange du sie nicht ergänzt hast. Wenn doch, gilt sie als deine Datei |

## C. Deins: wird nie angefasst

Alles andere. Ein Update liest diese Dateien höchstens, um zu prüfen, ob deine eigenen Bauten noch zur neuen Mechanik passen, und meldet dir das. Geändert wird hier nichts.

- `MEIN-SYSTEM.md` und alles darin
- `01_Basiskontext\*` (deine Person, dein Stil, deine Ziele)
- Alle Themenordner, die du angelegt hast, samt ihrer lokalen `AGENTS.md` und `_INDEX.md`
- `10_System\*` ausser `Kern-Dateien.md` (Architektur, Technik, Manual, Modellwahl, Zielsetzung beschreiben **dein** System, sobald du es aufgebaut hast)
- Alle Skills, die du selbst gebaut hast
- `02_Skills\Skill-Register.md` (dein Verzeichnis, wächst mit deinen Skills; der Update-Skill schlägt dir nur die Zeile für neue Kern-Skills vor)
- `00_INDEX\INDEX.md`, `00_INDEX\INDEX-Geruest.md` und alle `_INDEX.md` (maschinell erzeugt, aus deinen Inhalten)
- `03_Sessionlogs\*`, `04_Changelog\*`, `90_Inbox\*`

## Wenn du doch eine Kern-Datei ändern willst

Erlaubt, aber trag es in `MEIN-SYSTEM.md`, Abschnitt 3 ein. Der Update-Skill liest das, überschreibt deine Änderung dann nicht stillschweigend, sondern legt dir die neue Fassung daneben und arbeitet deine Anpassung ein.

Ohne diesen Eintrag merkt der Skill die Abweichung trotzdem (er vergleicht), aber er muss dich dann fragen, statt es zu wissen. Das kostet dich eine Rückfrage, nicht deine Arbeit.

## Für den Fall, dass diese Liste und die Wirklichkeit auseinandergehen

Findest du eine Datei, die hier nicht steht, entscheidet die Kategorie C: Im Zweifel gehört sie dir und wird nicht angefasst. Ein Update, das eine unbekannte Datei überschreibt, ist ein Fehler, kein Feature.
