---
name: leo-system-optimierung
trigger: '"system-optimierung", "system optimieren", "optimierungslauf", "pruefset fahren", "prüfset fahren", "messlauf", "regeltreue messen"'
zweck: Misst mit kalten Prüfset-Läufen, ob das System seine eigenen Regeln einhält, leitet aus Durchfallern gezielte Regel- oder Mechanik-Fixes ab und misst nach; Rollback bei sinkender Quote
type: skill
version: 1
---

# Skill: Leo System-Optimierung

Der wiederholbare Optimierungszyklus des Systems: Prüfset kalt fahren, Belege protokollieren, aus Durchfallern die richtige Sorte Fix ableiten, umbauen, nachmessen. Der Kern der Idee: Die Qualität eines Regelwerks wird gemessen, nicht behauptet, und zwar mit kalten Läufen, die nichts vom Gedächtnis der bauenden Session wissen. Voraussetzungen: eine Agent-CLI, die sich nicht-interaktiv aufrufen lässt (z.B. `claude -p`), PowerShell, Schreibzugriff aufs Repo.

**Beim ersten Lauf:** Es gibt noch kein Prüfset. Kopiere `10_System\Pruefset-Vorlage.md` im selben Ordner zur neuen Datei Pruefset.md und fülle die gekennzeichneten Platzhalter mit echten Fällen aus dem eigenen Repo (ein realer Fakt mit genau einer Fundstelle, eine echte Namens-Mehrdeutigkeit, ein realer Archiv-Wortlaut). Die generischen Fälle funktionieren unverändert.

## Wann ausführen

- Vor und nach jeder Kernänderung an Root-AGENTS.md, Basiskontext, Guard-Hook oder Skill-Mechanik: erst Ausgangswert, dann Umbau, dann Nachmessung. Sinkt die Quote, wird der Umbau zurückgerollt, nicht nachverhandelt.
- Als Stichprobe, wenn seit dem letzten Lauf mehr als 42 Tage vergangen sind.
- **Die Erinnerung ist mechanisiert:** Der System-Health-Check (Kategorie `Lean`, Messlauf-Wächter) warnt, wenn eine Kernänderung nach dem letzten protokollierten Messlauf liegt oder der letzte Lauf älter als 42 Tage ist. Der Lauf selbst startet bewusst, weil er je Fall eine kalte Session kostet.
- NICHT nach gewöhnlichen Wissens- oder Inhaltsänderungen. Über-Nutzung ist der teurere Fehler: Sie verbrennt Kontingent für unveränderte Regeln.

## Schritte

### 1. Frischecheck und Checkpoint
`git fetch origin`, `git status -sb`, `git log -1`. Bei `behind`/`diverged`: stoppen und fragen. Offene eigene Arbeit als Checkpoint committen (nur eigene Pfade), damit der Rollback jederzeit möglich ist.

### 2. Prüfset kalt fahren
Fälle und Messmechanik stehen in deinem Prüfset (Datei Pruefset.md in `10_System`). Jeder Fall ist ein eigener kalter Lauf:

```powershell
claude -p '<Eingabe im Wortlaut>' --permission-mode acceptEdits --output-format stream-json --verbose 2>&1 | Out-File "<scratchpad>\fall.jsonl" -Encoding utf8
```

Messhygiene (in der Prüfset-Datei gepflegt): Fantasienamen je Lauf wechseln, weil der Prüfling die Prüfset-Datei per Volltextsuche finden kann; Prompts mit Pfaden ausserhalb des Repos über eine Scratchpad-Datei übergeben (der eigene Guard-Hook blockiert sie sonst im Kommandotext); Fälle, die das Archiv lesen, mit `--add-dir`.

### 3. Je Fall am Beleg urteilen, sofort protokollieren
Bestanden oder durchgefallen entscheidet der Beleg (Antworttext, Werkzeug-Log aus dem JSONL, Dateizustand danach), nie die eigene Erwartung; Grenzfälle zulasten des Systems, mit Begründung. Ergebnis nach JEDEM Fall in die Lauf-Tabelle der Prüfset-Datei schreiben (Unterbrechungsresistenz), Testartefakte desselben Falls sofort zurückbauen (Dateien löschen, Test-Commits per `git reset --soft` zurücknehmen).

### 4. Learnings in den richtigen Fix übersetzen
Für jeden Durchfaller die Wurzel bestimmen, denn sie entscheidet die Fix-Sorte:

- **Regel zu weich gegen einen konkreten Druck** (z.B. eine explizite Nutzerangabe überfährt sie): Regel in der AGENTS.md härten, als normativer Satz mit Datum.
- **Regel strenger als je gelebt:** prüfen, ob die Regel falsch zugeschnitten ist, und sie präzisieren, statt den Verstoss nur zu beklagen.
- **Textregel zweimal wirkungslos:** mechanisches Netz bauen (Health-Check-Prüfung, Hook), nicht dieselbe Regel ein drittes Mal umformulieren.
- **Einmaliger Ausrutscher ohne Muster:** protokollieren, nichts umbauen (kleinster Eingriff).

Jeder Fix folgt der Trennlinie steuernd/begründend (Root-AGENTS.md, Abschnitt 10): Normatives in die AGENTS.md, die Erzählung in `10_System\Detailregeln aus AGENTS.md.md`. Basiskontext-Änderungen nur mit expliziter Bestätigung plus Changelog. Regeln werden nie gelöscht oder verwässert, um Tokens zu sparen.

### 5. Nachmessen, proportional
Nach gezielten Fixes: Delta-Lauf nur über die betroffenen Fälle. Nach einem umfangreichen Umbau: volles Set erneut, und die Iteration wiederholt sich, bis die Quote hält. Sinkt die Quote gegenüber dem Ausgangswert, wird der Umbau zurückgerollt (Checkpoint aus Schritt 1).

### 6. Lean-Stand erheben
`pwsh -NoProfile -ExecutionPolicy Bypass -File "00_INDEX\scripts\health-check.ps1"` (im Repo-Root), Kategorie `Lean` ansehen. Bei WARN: Erzählungen nach der Trennlinie auslagern. Wird die Baseline durch einen bewussten Umbau verschoben, `$leanSchwelleKB` im Skript nachführen.

### 7. Abschliessen
Prüfset-Datei: Ergebnis als Zahl, Lauf-Datum, `stand:` aktualisieren. Eigene Pfade committen und pushen. Bericht: Quote vorher/nachher, jeder Durchfaller mit Wurzel und Fix, Lean-Stand in KB.

## Regeln

- Anti-Halluzination verschärft: Ein Fall gilt nur als gelaufen, wenn sein JSONL existiert; ein Urteil nennt immer den Beleg. Nie ein Ergebnis aus dem Gedächtnis der bauenden Session ableiten, die Läufe sind bewusst kalt.
- Kein Testartefakt überlebt den Lauf: Was ein Prüffall im Repo, im Archiv, im Memory-Pfad oder ausserhalb hinterlässt, wird noch im selben Schritt zurückgebaut und der Rückbau im Beleg vermerkt.
- Der Guard-Hook und seine Ausnahmeliste werden für keinen Prüffall angefasst; blockiert er die Messung selbst, wird der Prompt per Datei übergeben, nie die Sperre gelockert.
- Dieser Skill ändert Regeln, deshalb doppelt: Jede AGENTS.md-Änderung trägt Datum und Anlass, und die Nachmessung gehört zum selben Auftrag, nicht in eine spätere Session.

## Definition of Done

- [ ] Jeder gefahrene Fall hat ein JSONL im Scratchpad und eine Belegzeile in der Prüfset-Datei
- [ ] Ausgangswert und Nachmessung stehen als Zahlen im Prüfset, `stand:` aktualisiert
- [ ] Jeder Durchfaller hat eine benannte Wurzel und entweder einen umgesetzten Fix (mit Delta-Nachmessung) oder den begründeten Entscheid, nichts zu ändern
- [ ] Kein Testartefakt mehr im Repo oder ausserhalb (`git status` sauber bis auf eigene Arbeit)
- [ ] Health-Check-Kategorie `Lean` ist OK oder ihr WARN hat einen konkreten nächsten Zug
- [ ] Eigene Pfade committet und gepusht; Quote vorher/nachher berichtet
