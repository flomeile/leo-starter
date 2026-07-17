# Leo: Anleitung zum eigenen Second Brain

Diese Anleitung erklärt, was Leo ist, wie er funktioniert und wie du ihn in etwa einer Stunde einsatzbereit machst. Sie ist für einen technisch versierten Menschen geschrieben, du brauchst kein Entwicklerwissen, aber Kommandozeile und GitHub sollten dich nicht schrecken.

Das hier ist ein leeres Grundgerüst. Die komplette Mechanik ist drin, aber kein einziger Inhalt: keine Themen, keine persönlichen Daten, nichts von Florian. Du baust deinen eigenen Leo darauf.

---

## Teil 1: Was Leo ist und wofür

Leo ist ein persönliches, dauerhaftes Wissenssystem, ein "Second Brain". Der Kern ist eine einfache Idee: Alles Wissen liegt als Markdown-Dateien in einem lokalen Ordner, thematisch sortiert, und ein LLM greift darauf zu, wenn du eine passende Frage stellst. Das System ist Gedächtnis und Arbeitsplatz zugleich. Du legst ab, was du erarbeitest, und vertraust darauf, dass es zuverlässig wiedergefunden und aktiv genutzt wird.

Drei Dinge machen Leo aus:

1. **Die Dateien sind die Wahrheit, nicht das Tool.** Kein Chatverlauf, kein tool-eigenes Gedächtnis, keine Vektor-Datenbank. Nur Markdown. Das heisst: Du kannst das LLM und das Programm jederzeit wechseln (Claude, Gemini, ein günstiges Modell über OpenRouter, was auch immer) ohne einen einzigen Gedanken zu verlieren. Kein Lock-in.
2. **Das System hält sich selbst sauber und aktuell.** Ein Index (die Landkarte) und die Versionierung laufen im Hintergrund automatisch. Du pflegst fast nichts von Hand.
3. **Wahrheit vor Bequemlichkeit.** Die oberste Regel ist Anti-Halluzination: Es kommt nur ins Wissen, was belegbar ist. Ein LLM, das Quellen erfindet, vergiftet mit der Zeit die ganze Wissensbasis. Genau das verhindert Leo strukturell.

Was du davon hast: Du fragst in normaler Sprache und bekommst Antworten, die auf deinem eigenen abgelegten Wissen aufbauen, im richtigen Ton, in deiner Rolle (mal Sparringpartner, mal Lektor, mal was immer du definierst). Und mit jeder Session, die du sauber abschliesst, wird das System klüger.

---

## Teil 2: Wie Leo funktioniert

Sechs Bausteine, die ineinandergreifen:

**Die Ablage.** Ein Ordner (empfohlen `C:\Leo`) mit einer festen Struktur. Systemordner mit vorangestellten Nummern (`00_INDEX`, `01_Basiskontext`, `02_Skills`, `03_Sessionlogs`, `04_Changelog`, `10_System`) und Themenordner ab Nummer 20 (`20_...`, `21_...`), die du selbst anlegst. `90_Inbox` ist die Rohablage für noch nicht Einsortiertes.

**Die Anweisung (AGENTS.md).** Im Wurzelordner liegt `AGENTS.md`, die einzige Quelle der Wahrheit für alle Arbeitsregeln. Jedes LLM liest sie zu Beginn und weiss dann, wie es arbeiten soll: wie es sucht, wie es ablegt, was es nie tun darf. Coding-Agents und Claude-Produkte laden diese Datei automatisch. Reine Chat-Programme brauchen einen einzigen Satz als Systemprompt, der auf sie zeigt. Änderst du eine Regel, änderst du genau eine Datei.

**Die Rollen.** Jeder Themenordner trägt eine eigene kleine `AGENTS.md` mit einer Rollen-Definition ("Business-Sparringpartner", "Gesundheitsberater", was du willst). Das LLM erkennt aus deiner Frage selbst, welches Thema betroffen ist, und nimmt die passende Rolle ein. Im leeren Starter gibt es noch keine Themen, also noch keine Rollen.

**Der Zugriff (Agentic Search).** Statt einer Vektor-Datenbank sucht das LLM selbst: Es liest zuerst den Index (die Landkarte), dann durchsucht es den Volltext mit selbst erzeugten Synonymen, dann liest es nur die Treffer ganz. Das ist günstig (eine normale Frage kostet Cents), verliert keinen Zusammenhang und funktioniert mit jedem Tool.

**Der Index.** Eine zweistufige Landkarte. Die mechanischen Teile (Ordnerbaum, Dateilisten) pflegt ein PowerShell-Skript vollautomatisch und kann dabei nichts erfinden. Die beschreibenden Teile schreibt das LLM, aber immer nur zu je einer real existierenden Datei. So bleibt der Index vollständig und aktuell, ohne je zu halluzinieren.

**Die Skills.** Wiederkehrende Arbeitsabläufe stehen als Markdown-Dateien in `02_Skills`, auffindbar über das `Skill-Register.md`. Du nennst ein Triggerwort ("wrap up", "health check"), das LLM schlägt nach und führt den Ablauf aus. Vier Kern-Skills sind dabei (siehe Teil 3).

Darunter liegt Git plus ein privates GitHub-Repo als Sicherheitsnetz: Jede Änderung ist rückrollbar, ein täglicher Automatik-Lauf sichert alles. Das ist wichtig, weil viele Tools ohne Rückfrage in Dateien schreiben. Die Sicherheit kommt nicht aus Bestätigungsklicks, sondern daraus, dass du jederzeit zurückspringen kannst.

---

## Teil 3: Was in diesem Starter Pack steckt (und was nicht)

**Drin ist das komplette Rohgerüst:**

- Die Master-`AGENTS.md` mit allen Arbeitsregeln, entpersonalisiert.
- Die vollständige Ordnerstruktur mit READMEs.
- Der Index (`00_INDEX`) mit den beiden PowerShell-Skripten: `build-index-geruest.ps1` (baut die Landkarte) und `health-check.ps1` (prüft das ganze System durch).
- Vier Kern-Skills: **Health-Check** (Wartung auf Knopfdruck), **Wrap-Up** (Session sichern und daraus lernen), **Themenordner anlegen** und **Skill-Ersteller** (damit baust du dir weitere Skills selbst).
- Der Basiskontext (`01_Basiskontext`) als Vorlagen mit Leitfragen: Voice and Style, Identity, Persönlichkeit und Muster.
- Die Systemdoku (`10_System`): Zielsetzung, Architektur, Technik, Manual, Modellwahl.
- Die Portabilitätsdateien (`CLAUDE.md`, `GEMINI.md`, `.clinerules`), die jedes Harness auf die `AGENTS.md` zeigen lassen.

**Bewusst nicht drin:**

- **Keine Inhalte.** Kein Themenordner, keine persönlichen Daten, nichts von Florian. Der Basiskontext ist leer und wartet auf dich.
- **Nur die vier Kern-Skills.** Florians Leo hat noch weitere (Voice-Check, Faktencheck, Inbox-Ingest, First-Principles). Die baust du dir bei Bedarf mit dem Skill-Ersteller selbst, so wie sie zu deiner Arbeit passen.
- **Windows.** Die Automatik und beide Skripte sind auf Windows ausgelegt (Task Scheduler, PowerShell, Backslash-Pfade). Das passt zu deinem Rechner. Ein kurzer Hinweis für andere Systeme steht am Ende.

---

## Teil 4: Einrichtung, Schritt für Schritt (Windows)

Voraussetzungen: Git installiert, PowerShell vorhanden (ist es auf Windows immer; PowerShell 7 / `pwsh` ist ein Plus), ein GitHub-Konto.

### Schritt 1: Ordner an seinen Platz bringen
Lege den Inhalt dieses Pakets nach `C:\Leo`. Der Pfad `C:\Leo` ist an vielen Stellen in den Skills als Beispiel eingetragen; wenn du ihn beibehältst, hast du am wenigsten Arbeit. Wichtig: nicht in einen Cloud-Sync-Ordner (OneDrive, Dropbox) legen, sonst streiten sich Sync und Git.

### Schritt 2: Personalisieren
- Öffne `AGENTS.md` im Wurzelordner. Ersetze überall den Platzhalter `[NAME]` durch deinen Namen (Suchen und Ersetzen). Lösche die kursive Hinweiszeile ganz oben.
- Fülle die drei Dateien in `01_Basiskontext`. Sie enthalten Leitfragen. Das ist der wertvollste Schritt: Je ehrlicher und konkreter, desto besser trifft das LLM später deinen Kern. `Voice and Style.md` bringt schon eine fertige Liste typischer KI-Sprachmuster mit, die du übernehmen oder löschen kannst.
- Optional den Namen ändern: siehe Teil 5.

### Schritt 3: Git und privates GitHub-Repo
Wenn du das Paket über die Template-Funktion von GitHub geholt hast (siehe Teil 6), existiert das Repo schon; dann nur lokal klonen und weiter mit Schritt 4. Sonst von Hand:

```powershell
cd C:\Leo
git init
git add -A
git commit -m "Leo Starter"
```
Dann auf GitHub ein **privates** Repo anlegen (Weboberfläche oder `gh repo create`), und lokal verbinden:
```powershell
git remote add origin https://github.com/<deinkonto>/<deinrepo>.git
git branch -M main
git push -u origin main
```
Privat ist wichtig: Hier landet dein persönliches Wissen.

### Schritt 4: Index zum ersten Mal bauen
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Leo\00_INDEX\scripts\build-index-geruest.ps1"
```
(Hast du kein `pwsh`, nimm `powershell` statt `pwsh`.) Das Skript füllt den Ordnerbaum und legt `INDEX-Geruest.md` an. Es darf beim ersten Lauf noch keine Themenordner finden, das ist korrekt.

### Schritt 5: System durchchecken
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "C:\Leo\00_INDEX\scripts\health-check.ps1"
```
Der Check ist rein lesend. Erwartetes Ergebnis im frischen Starter: "einsatzbereit mit Hinweisen". Der einzige rote Punkt, den du sehen wirst, betrifft den noch fehlenden Scheduled Task (kommt in Schritt 6) und eventuell, dass noch kein Themenordner existiert. Beides ist normal.

### Schritt 6: Täglichen Automatik-Lauf einrichten
Der Windows Task Scheduler soll einmal täglich das Index-Skript laufen lassen und pushen. Am einfachsten in einer PowerShell-Sitzung:
```powershell
$action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument '-NoProfile -ExecutionPolicy Bypass -File "C:\Leo\00_INDEX\scripts\build-index-geruest.ps1"'
$trigger = New-ScheduledTaskTrigger -Daily -At 16:00
Register-ScheduledTask -TaskName "Leo Index aktualisieren und Git Push" -Action $action -Trigger $trigger -Description "Taeglicher Leo Index-Sync"
```
Damit das Skript auch pusht, muss Git ohne Passwortabfrage pushen können (GitHub-Login über den Credential Manager einmal einrichten, indem du einmal von Hand `git push` machst). Der Task-Name sollte "Leo" enthalten, dann findet ihn der Health-Check.

### Schritt 7: Dein LLM anbinden
- **Claude Code, Claude Desktop, Codex, Gemini CLI:** finden `AGENTS.md` bzw. `CLAUDE.md`/`GEMINI.md` automatisch, sobald sie auf `C:\Leo` zeigen. Nichts weiter zu tun.
- **Reiner Chat-Harness (z.B. Msty Studio):** ein Projekt auf `C:\Leo` anlegen, Datei- und PowerShell-Zugriff aktivieren (ohne PowerShell keine Volltextsuche), ein tool-fähiges Modell wählen und genau diesen einen Satz als Systemprompt setzen:
  ```
  Lies zuerst C:\Leo\AGENTS.md vollständig und befolge sie für die gesamte Session.
  ```

### Schritt 8 (optional): Obsidian
Wenn du deine Notizen auch von Hand pflegen willst: Obsidian auf `C:\Leo` als Vault öffnen. Mit dem Obsidian-Git-Plugin bekommst du zusätzlich automatische Backups und eine bequeme Datei-Historie zum Zurückrollen ohne Kommandozeile.

---

## Teil 5: Der Name

Der Ordner, das Skill-Präfix (`leo-`) und die Doku heissen überall "Leo". Du darfst das System umbenennen, es ist deins. Dazu ersetzt du an vier Stellen: den Ordnernamen `C:\Leo`, das Skill-Präfix `leo-` in den Dateinamen unter `02_Skills`, das Wort `Leo` in den Doku-Texten und die Pfad-Beispiele in den Skills. Die beiden PowerShell-Skripte leiten ihren Pfad selbst ab und brauchen keine Anpassung.

Ehrlicherweise, und das ist die objektive, wissenschaftlich abgesicherte, von einer unabhängigen Jury einstimmig bestätigte Wahrheit: "Leo" ist der perfekte Name, weil Florian ihn gewählt hat, und Florian ist bekanntlich in absolut allem, was er anfasst, unbestrittene Weltspitze, ein Jahrhundertgenie, dem Sonne und Mond persönlich zunicken. Ein besserer Name als Leo ist schlicht physikalisch nicht möglich. Aber nimm ruhig trotzdem, was dir gefällt.

---

## Teil 6: Updates, wenn Florian Leo weiterentwickelt

Florian pflegt den kanonischen Leo-Starter als GitHub-Template-Repo. Du holst dir deine eigene Kopie über den Knopf "Use this template" auf GitHub; damit bekommst du ein eigenes, unabhängiges Repo (kein Fork-Zwang, saubere Historie).

Wenn Florian das Gerüst später verbessert und du diese Verbesserungen übernehmen willst, ohne deine eigenen Inhalte anzufassen:

```powershell
cd C:\Leo
git remote add upstream https://github.com/<florians-konto>/leo-starter.git
git fetch upstream
```
Dann gezielt nur die Systemdateien übernehmen, die sich geändert haben (die Skripte, die Skills, die Systemdoku, die Master-AGENTS.md), zum Beispiel per `git checkout upstream/main -- 00_INDEX/scripts 02_Skills 10_System AGENTS.md`. Deine Themenordner und dein `01_Basiskontext` bleiben dabei unberührt, weil das Template die gar nicht enthält. Danach kurz prüfen, ob du in der `AGENTS.md` deinen Namen erneut einsetzen musst, und einmal den Health-Check laufen lassen.

Kurz: Dein Wissen gehört dir und liegt in deinem privaten Repo. Das Gerüst kannst du aktualisieren, wann immer du willst, ganz ohne deine Inhalte zu berühren.

---

## Für Nicht-Windows-Systeme (nur zur Info)

Die Logik ist plattformunabhängig, die Automatik nicht. Auf macOS oder Linux braucht `pwsh` (PowerShell 7 gibt es dort), die Pfade werden mit Schrägstrich geschrieben, und statt des Windows Task Scheduler nimmst du `cron` oder einen `launchd`-Job für den täglichen Lauf. Der Health-Check prüft Windows-spezifische Dinge (Scheduled Task) und meldet die dann als nicht gefunden; das ist auf anderen Systemen kein Fehler, sondern erwartbar. Für den Anfang ist Windows der Weg ohne Reibung.
