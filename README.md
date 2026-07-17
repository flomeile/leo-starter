---
titel: Leo
zweck: Einstiegspunkt für Menschen
type: readme
---

# Leo: Dein Second Brain

Lokales, harness-unabhängiges Wissenssystem. Alles Wissen liegt als Markdown in thematischen Ordnern; jedes LLM mit Datei- und PowerShell-Zugriff kann darauf arbeiten.

Dies ist ein leeres Grundgerüst (Starter Pack). Es enthält die komplette Mechanik, aber keine Inhalte. Du füllst es mit deinen eigenen Themen.

## Zuerst lesen

**`ANLEITUNG.md`** im Root: Sinn, Funktionsweise und die Schritt-für-Schritt-Einrichtung. Das ist dein Startpunkt.

## Einstieg (nach der Einrichtung)

- **Für LLMs und Agents:** `AGENTS.md` im Root (Master-Anweisung). Themenordner haben eigene lokale `AGENTS.md` (Rollen).
- **Für dich:** `10_System\Manual.md` (Bedienung: welches Werkzeug wofür, wie prompten, Wartung).
- **Landkarte:** `00_INDEX\INDEX.md` (Baum + Bereiche), lokale `_INDEX.md` je Themenordner.

## Struktur (Kurzfassung)

- Systemordner: `00_INDEX` Landkarte, `01_Basiskontext` Kernkontext (geschützt), `02_Skills` Skills, `03_Sessionlogs` Session-Wissen, `04_Changelog` Basiskontext-Protokoll, `10_System` Systemdoku
- Themenordner (`2X_*`): dein thematisches Wissen mit eigener Rolle, legst du selbst an. `90_Inbox` ist die Rohablage.

Versionierung: Git, automatischer Push auf ein privates GitHub-Repo (Task Scheduler + optional Obsidian-Git).
