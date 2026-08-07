---
titel: Leo
zweck: Einstiegspunkt für Menschen
type: readme
---

# Leo: Dein Second Brain

Harness-unabhängiges Wissenssystem. Alles Wissen liegt als Markdown in thematischen Ordnern; jedes LLM mit Datei- und Werkzeug-Zugriff kann darauf arbeiten.

Dies ist ein leeres Grundgerüst (Starter Pack, Version 1.3). Es enthält die komplette Mechanik, aber keine Inhalte. Du füllst es mit deinen eigenen Themen.

Das Gerüst wird weiterentwickelt. Verbesserungen holst du dir später mit einem Satz an deinen Agenten ("mechanik update"), ohne dass deine Inhalte, deine Personalisierung oder deine selbstgebauten Skills angetastet werden. Wie das abgesichert ist, steht in `ANLEITUNG.md`, Teil 8 und in `10_System\Kern-Dateien.md`.

## Zuerst lesen

**`ANLEITUNG.md`** im Root: Sinn, Funktionsweise und die Schritt-für-Schritt-Einrichtung. Das ist dein Startpunkt. Sie deckt zwei Wege ab, einen mit eigenem Windows-Rechner und einen ohne eigenen Rechner (nur Tablet), und markiert Erklärungen für Einsteiger als **Grundlagen**-Kästen, die ein erfahrener Leser überspringen kann.

## Einstieg (nach der Einrichtung)

- **Für LLMs und Agents:** `AGENTS.md` im Root (Master-Anweisung, Mechanik) plus `MEIN-SYSTEM.md` (deine persönliche Ebene darüber, hat bei Widerspruch Vorrang). Themenordner haben eigene lokale `AGENTS.md` (Rollen).
- **Für dich:** `10_System\Manual.md` (Bedienung: welches Werkzeug wofür, wie prompten, Wartung).
- **Landkarte:** `00_INDEX\INDEX.md` (Baum + Bereiche), lokale `_INDEX.md` je Themenordner.

## Struktur (Kurzfassung)

- Systemordner: `00_INDEX` Landkarte, `01_Basiskontext` Kernkontext (geschützt), `02_Skills` Skills, `03_Sessionlogs` Session-Wissen, `04_Changelog` Basiskontext-Protokoll, `10_System` Systemdoku
- Themenordner (`2X_*`): dein thematisches Wissen mit eigener Rolle, legst du selbst an. `90_Inbox` ist die Rohablage.

Versionierung: Git, automatischer Push auf ein privates GitHub-Repo (Task Scheduler + optional Obsidian-Git).
