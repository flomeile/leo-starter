---
titel: Index-Ordner
zweck: Zentrale Landkarte des gesamten Repos
type: readme
---

# 00_INDEX

Enthält die zentrale Landkarte des Second Brain. Der Index ist zweistufig:

- **INDEX.md** (hier): Ordnerbaum (mechanisch aktuell), Themenbereiche, Beschreibungen der Systemdateien. Zuerst lesen.
- **_INDEX.md je Themenordner** (z.B. `20_Business\_INDEX.md`): Dateiliste (mechanisch aktuell) plus kuratierte Beschreibungen der Wissensdateien dort.
- **INDEX-Geruest.md**: vollständige, deterministische Baumliste aller .md-Dateien. Sicherheitsnetz und Delta-Quelle, kein Einstiegspunkt. Wird beim ersten Skript-Lauf erzeugt.

## Pflege (Rollenteilung)

- **Mechanisch (Skript, keine Halluzination möglich):** `scripts\build-index-geruest.ps1` erzeugt das Gerüst, aktualisiert die Auto-Blöcke (Ordnerbaum, Dateilisten), legt fehlende _INDEX.md an und entfernt kuratierte Einträge zu gelöschten Dateien. Läuft automatisch per Task Scheduler.
- **Kuratiert (LLM):** Beschreibungen schreibt der Skill `leo-system-health-check` (auch Teil des Wrap-Up), rein deskriptiv, nur für neue/geänderte Dateien.

Auto-Blöcke (`<!-- AUTO:...:BEGIN/END -->`) nie von Hand ändern.
