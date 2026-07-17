---
name: leo-system-health-check
trigger: '"system health check", "health check", "system prüfen", "systemcheck", "ist alles gesund", "gesundheitscheck system", "alles aktuell", "system aktualisieren", "auf vordermann bringen", "index aktualisieren", "index neu bauen", "inbox aufraeumen", "ablage aufraeumen", "hygiene"'
zweck: One-Button-Wartung des Gesamtsystems - prüft alles, behebt sicher Behebbares selbst (Index-Beschreibungen, stand-Daten, Register), behandelt die Inbox, schreibt den Health-Check-Zeitstempel und schliesst mit Commit + Push ab
type: skill
version: 1.0-starter
---

# Skill: System Health Check

Der EINE Wartungs-Skill des Systems. Prüft das gesamte Repo (Index-Mechanik, Beschreibungen, dynamische Dokumente, Git, Automatisierung, Skill-Registry, Inbox), behebt alles sicher Behebbare direkt und committet + pusht am Ende. Nach einem Lauf gilt: Indizes aktuell, Beschreibungen vollständig, dynamische Dokumente gekennzeichnet und frisch, Inbox behandelt, alles auf GitHub. Voraussetzung: Datei-Schreibzugriff plus PowerShell.

## Wann ausführen
- Wenn ein Trigger-Wort genannt wird oder Unsicherheit besteht, ob alles aktuell ist.
- Von `leo-wrap-up` aus, aber NICHT bei jedem Wrap-Up automatisch: nur wenn dessen Schritt 5 das verlangt (letzter Lauf > 24h, oder diese Session war strukturell). Sonst macht Wrap-Up ein leichtes Update ohne diesen Skill.
- Sinnvoll nach grösseren strukturellen Änderungen (neuer Themenordner, viele verschobene/gelöschte Dateien) oder nach Änderungen an Skripten/Skills.

## Schritte

### 1. Mechanik frisch machen
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Leo\00_INDEX\scripts\build-index-geruest.ps1"
```
Damit die Diagnose den aktuellen Stand prüft. Falls das Skript einen Datei-Sperr-Fehler auf `INDEX.md` oder `AGENTS.md` meldet (z.B. weil der Scheduler-Task parallel läuft): kurz warten und nochmal ausführen. Nie den betroffenen Auto-Block von Hand nachtragen.

### 2. Diagnose
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Leo\00_INDEX\scripts\health-check.ps1"
```
Das Skript ist rein lesend und prüft deterministisch: Git/Versionierung, Scheduled Task, Auto-Block-Integrität, Themenordner-Registrierung, Index-Abdeckung (kuratierte Beschreibungen), Skill-Registry, Encoding, Inbox, Basiskontext, Portabilitätsdateien, Harness-Memory-Füllstand (meldet jeden Fund als Handlungsbedarf, weil ein harness-eigener Memory-Speicher für Leo nicht zugelassen ist: Root-`AGENTS.md` Abschnitt 1) sowie den kompletten `stand:`-Workflow für dynamische Dokumente: (a) veraltete Stände (> 60 Tage), (b) nicht nachgeführte Stände, (c) fehlende Kennzeichnung. Jede Zeile trägt `[OK]`, `[INFO]`, `[WARN]` oder `[FAIL]`; am Ende steht ein VERDIKT (Exit Code 0/1/2).

### 3. Sicher Behebbares direkt beheben (nicht fragen, machen)
Für jeden Befund zuerst einordnen: bekannte, abgestimmte Ausnahme (im Bericht kennzeichnen, keine Aktion) oder echter Handlungsbedarf. Dann direkt beheben, was mechanisch sicher ist:

- **Fehlende kuratierte Index-Beschreibungen (Delta-Verfahren):** `00_INDEX\INDEX-Geruest.md` lesen, mit den kuratierten Beschreibungen vergleichen (Root-`INDEX.md` für Systemdateien, `_INDEX.md` je Themenordner für Themendateien). Für jede Datei ohne Beschreibung oder mit neuerem Änderungsdatum: Datei lesen und beschreiben. Format: `- **Relativpfad** — Beschreibung`. Rein deskriptiv: worum es geht, welche Fragen die Datei beantwortet, welche Begriffe und Synonyme sie abdeckt. NUR beschreiben, was real in der Datei steht. Bestehende, unveränderte Beschreibungen nicht anfassen. Auto-Blöcke nie verändern. Hinweis: Die Root-`INDEX.md` enthält bei den Themenbereichen bewusst KEINE einzelnen Datei-Beschreibungen; die gehören ausschliesslich in die lokale `_INDEX.md`.
- **Fehlende `stand:`-Kennzeichnung:** Meldet der Check dynamisch klingende Dateien ohne `stand:`, die Datei kurz anlesen. Ist der Inhalt wirklich veränderlich (Aufgaben, Status, Plan, Verlauf): `stand: YYYY-MM-DD` ins Frontmatter ergänzen. Ist die Datei statisch: im Abschlussbericht zur Bestätigung vorschlagen, sie als Ausnahme in `health-check.ps1` zu führen.
- **`stand:` in dieser Session bearbeiteter Dateien:** auf das echte Tagesdatum aktualisieren, falls versäumt.
- **Gemeldeter `stand:`-Drift:** Datei kurz anlesen, `stand:` auf das Datum der letzten Git-Änderung setzen.
- **Register-/Registry-Lücken:** fehlender Registereintrag für eine existierende Skill-Datei nachtragen; kaputte Verweise korrigieren.
- **Datei-Sperr-Fehler:** Skript einfach erneut laufen lassen.
- **Bug im mechanischen Skript selbst:** beheben und die neue Logik kurz bestätigen lassen, nicht nur den Symptomausschlag wegklicken.

### 4. Inbox behandeln
Für jede Datei in `90_Inbox` (ausser README.md): kurz anlesen und einordnen. Zwei Fälle:
- **Braucht inhaltliche Verarbeitung** (Mails, PDFs, Scans, Rohmaterial, dessen Wissen in eine konsolidierte Notiz gehört): NICHT verschieben, NICHT eigenmächtig verarbeiten. Im Abschlussbericht vorschlagen, die Datei verlustfrei in eine Wissensnotiz zu konsolidieren und die Rohquelle danach (git-gesichert) zu löschen. Der Health Check verarbeitet keine Inhalte.
- **Passt unverändert als eigenständige `.md` in einen Themenordner** (z.B. importierte Deep-Research-Berichte): Zielordner und ggf. besseren Dateinamen vorschlagen. **Verschieben NUR mit Bestätigung**, das ist die einzige Rückfrage dieses Skills. Nach Bestätigung:
```powershell
Move-Item -Path "C:\Leo\90_Inbox\<datei>" -Destination "C:\Leo\<zielordner>\<neuer-name>"
```

### 5. Entscheidungsbedarf sammeln (nicht eigenmächtig handeln)
Befunde, die eine Entscheidung brauchen, klar benennen und je einen konkreten Vorschlag machen, aber nicht selbst entscheiden: `stand:`-Daten älter als 60 Tage, git behind/Konflikte, deaktivierter Scheduled Task, Portabilitäts-Drift, grosse Aufräumaktionen, alles rund um `01_Basiskontext`. Meldet der Check, dass sich das Harness-Memory gefüllt hat (WARN Harness-Memory): **kein Repo-Mirror** (das ist bewusst ausgeschlossen, Root-`AGENTS.md` Abschnitt 1) - stattdessen jede Datei kurz lesen, Inhalt mit Dauerwert in die passende Repo-Datei migrieren (Basiskontext-Ziele mit Bestätigung, alles andere direkt), danach die Harness-Memory-Datei löschen. Im Bericht kurz auflisten, was migriert und gelöscht wurde.

### 6. Erneut prüfen
Nach Korrekturen Schritt 1 und 2 wiederholen, bis der Bericht stabil ist. Kritische FAILs (Merge-Konflikt-Marker, kaputte Auto-Blöcke, doppelte Ordnernummern, unregistrierte Themenordner) IMMER beheben oder explizit als offen benennen.

### 7. Zeitstempel schreiben
```powershell
Get-Date -Format "yyyy-MM-dd HH:mm" | Set-Content -Path "C:\Leo\10_System\health-check-last-run.txt" -Encoding UTF8
```
Damit weiss `leo-wrap-up`, wann der letzte volle Check lief. Diese Datei wird mit committet, nicht ignoriert.

### 8. Committen und pushen (ohne Rückfrage)
```powershell
cd C:\Leo
git add -A
git commit -m "System-Refresh: <Kurzbeschreibung>"
git pull --rebase
git push
```
Ruft ein anderer Skill diesen Skill auf (z.B. Wrap-Up), gilt dessen Commit-Message. Schlägt der Rebase fehl (Konflikt): nichts erzwingen, melden. Commit + Push brauchen keine Bestätigung, Sicherheit kommt aus der Versionierung.

### 9. Abschlussbericht
Drei Teile plus Verdikt:
- **Automatisch behoben:** <Liste>.
- **Bekannte Ausnahmen (keine Aktion nötig):** <Liste>.
- **Offen, braucht eine Entscheidung:** <Liste mit je einer konkreten Empfehlung>.
- Verdikt in einem Satz: "System aktuell und gepusht" / "System aktuell mit offenen Hinweisen" / "System NICHT einsatzbereit, folgendes zuerst klären: ...".

## Regeln
- Commit und Push sind Teil des Skills und brauchen keine Bestätigung. Verschieben, Löschen und Überschreiben von Wissensdateien dagegen NUR mit Bestätigung.
- Anti-Halluzination: nur melden und beschreiben, was Skript bzw. Datei real hergeben. Keine Vermutungen als Fakt.
- Basiskontext-Schutz: Befunde zu `01_Basiskontext` nur melden; Änderungen dort nur mit expliziter Bestätigung plus Changelog-Eintrag.

## Definition of Done
- [ ] Index-Skript und Diagnose-Skript sind fehlerfrei durchgelaufen (bei Datei-Sperre: wiederholt)
- [ ] Jeder Befund ist genau einer Kategorie zugeordnet: behoben, bekannte Ausnahme oder offen mit konkreter Empfehlung
- [ ] Kuratierte Beschreibungen für alle neuen oder geänderten Dateien ergänzt
- [ ] Keine kritischen FAILs unerwähnt; Diagnose nach Korrekturen wiederholt, bis der Bericht stabil ist
- [ ] Zeitstempel in `10_System\health-check-last-run.txt` geschrieben
- [ ] Committet und gepusht, oder der Konflikt ist gemeldet
- [ ] Abschlussbericht mit Verdikt geliefert
