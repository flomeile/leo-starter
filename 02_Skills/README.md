---
titel: Skills-Ordner
zweck: Alle Skills als Markdown plus Skill-Register
type: readme
---

# 02_Skills

Enthält alle Skills als Markdown-Dateien sowie das Skill-Register (`Skill-Register.md`).

## Was ist ein Skill
Eine harness-neutrale Markdown-Datei mit Trigger-Worten, einer Schritt-für-Schritt-Anweisung inklusive absoluter Pfade und einer Definition of Done am Ende (überprüfbare Checkliste, wird vor der Abschluss-Bestätigung real geprüft). Läuft in jedem Harness mit Datei-Zugriff plus PowerShell (Coding-Agent oder Chat-Session). Die verbindliche Norm steht in `leo-skill-ersteller.md`.

## Skill-Register
`Skill-Register.md` listet alle Skills mit Trigger-Worten und Pfad. Die Root-`AGENTS.md` verweist darauf; bei einem Trigger-Wort schlägt das LLM dort nach und führt die Skill-Datei aus.

## Namenskonvention
Jede Skill-Datei trägt das Präfix `leo-` (z.B. `leo-wrap-up.md`). Das macht sichtbar, dass der Skill in `C:\Leo` liegt und von dort funktioniert, unabhängig vom Harness. Trigger-Worte selbst brauchen das Präfix nicht.

## Regel für das LLM
Die Repo-Skills sind die einzige Wahrheit; keine harness-spezifischen Kopien anlegen. Neue Skills mit dem Skill-Ersteller normgerecht bauen (inkl. Präfix) und ins Register eintragen. Erkannte Fehler oder Schwachstellen direkt im Skill beheben (Version hochzählen) und informieren.
