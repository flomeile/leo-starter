---
titel: Skill-Register
zweck: Zentrale Liste aller Skills mit Trigger-Wort und Dateipfad
type: skill-register
version: 1.0-starter
letzte_aenderung: 2026-07-17
---

# Skill-Register

Die Root-`AGENTS.md` verweist auf diese Datei. Wenn ein Trigger-Wort genannt wird, schau hier nach, welcher Skill gemeint ist, öffne die zugehörige Datei und führe sie gemäss ihrer Anweisung aus.

Für den Alltag reichen zwei Trigger: **"wrap up"** am Ende einer substanziellen Session, **"health check"** wann immer unklar ist, ob alles aktuell ist. Der Rest läuft automatisch (Task Scheduler täglich, optional Obsidian-Git laufend).

Namenskonvention: Alle Skill-Dateien tragen das Präfix `leo-`. Das macht sichtbar, dass der Skill in `C:\Leo` liegt und von dort aus funktioniert, unabhängig vom Harness. Trigger-Worte selbst brauchen das Präfix nicht.

| Skill | Trigger-Worte | Datei | Zweck |
|---|---|---|---|
| Leo System Health Check | "system health check", "health check", "system prüfen", "systemcheck", "ist alles gesund", "gesundheitscheck system", "alles aktuell", "system aktualisieren", "auf vordermann bringen", "index aktualisieren", "index neu bauen", "inbox aufraeumen", "ablage aufraeumen", "hygiene" | 02_Skills/leo-system-health-check.md | One-Button-Wartung: alles prüfen, sicher Behebbares selbst beheben (Index-Beschreibungen, stand-Daten, Register), Inbox behandeln, committen + pushen |
| Leo Wrap-Up | "wrap up", "session speichern", "zusammenfassen und ablegen", "session beenden" | 02_Skills/leo-wrap-up.md | Session zusammenfassen, in 03_Sessionlogs ablegen; Lernschleife: Dauerwissen in die steuernden Dateien zurückschreiben, fehlende Wissensdateien anlegen, Überholtes ersetzen, sofort indexieren; vollen Health Check nur bei Bedarf |
| Leo Themenordner anlegen | "neuer themenordner", "themenordner anlegen", "neues thema anlegen" | 02_Skills/leo-themenordner-anlegen.md | Neuen Themenordner vollständig anlegen (README, AGENTS.md, Routing, Index) |
| Leo Skill erstellen | "neuen skill", "skill erstellen", "skill bauen" | 02_Skills/leo-skill-ersteller.md | Baut einen neuen Skill normgerecht (inkl. Präfix) und trägt ihn ins Register ein |

## Regel
Wenn ein neuer Skill gebaut wird (via Skill-Ersteller), wird diese Tabelle ergänzt. Trigger-Worte müssen eindeutig bleiben. Neue Skill-Dateien tragen immer das Präfix `leo-`.

## Hinweis für den Aufbau
Dies ist der Starter-Satz mit vier Kern-Skills. Weitere nützliche Skills (Voice-Check, Faktencheck, Inbox-Ingest, First-Principles) baust du dir bei Bedarf selbst über den Skill-Ersteller ("skill erstellen"). Der Ersteller-Skill trägt die Norm dafür.
