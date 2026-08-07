---
name: leo-mechanik-update
trigger: '"mechanik update", "grundgeruest aktualisieren", "starter update", "update ziehen", "neue version holen"'
zweck: Verbesserungen am Grundgerüst übernehmen, ohne eigene Anpassungen und eigene Bauten zu beschädigen
type: skill
version: 1.3-starter
---

# Skill: Mechanik aktualisieren

Holt die aktuelle Fassung des Grundgerüsts von `https://github.com/flomeile/leo-starter` und arbeitet sie hier ein.

**Oberste Regel, sie steht über allem anderen in diesem Skill: Es geht nichts von `[NAME]` verloren.** Lieber ein Update, das an einer Stelle stehen bleibt und nachfragt, als eines, das durchläuft und etwas überschreibt. Wenn du an irgendeinem Punkt unsicher bist, ob eine Datei dem Nutzer gehört: Sie gehört ihm. Nicht anfassen, melden.

## Wann ausführen

Wenn `[NAME]` sagt, dass eine neue Version des Grundgerüsts verfügbar ist, oder von sich aus prüfen lassen will, ob es eine gibt. Nicht automatisch, nicht im Wrap-Up, nicht im Health-Check.

## Was du vorher gelesen haben musst

1. `10_System\Kern-Dateien.md` (welche Datei zu welcher Kategorie gehört)
2. `MEIN-SYSTEM.md` (eingespielte Version, eigene Regeln, eigene Bauten, eigene Änderungen an Kern-Dateien)

## Schritte

### 1. Sicherheitsnetz spannen

Ohne diesen Schritt wird nicht weitergearbeitet.

```powershell
cd <Repo-Pfad aus MEIN-SYSTEM.md>
git status --short
```

Ist irgendetwas offen, alles committen, bevor das Update beginnt:

```powershell
git add -A
git commit -m "Stand vor Mechanik-Update"
```

Hier ist `git add -A` ausdrücklich richtig, abweichend von der sonstigen Regel in der `AGENTS.md`, Abschnitt 12. Der Zweck ist genau, den kompletten Ist-Zustand einzufrieren, damit jeder Schritt danach rückgängig gemacht werden kann. Sag `[NAME]` in einem Satz, dass dieser Commit der Rückweg ist und wie er ihn nutzt: `git reset --hard <Commit-Hash>` stellt den Zustand von jetzt wieder her.

Gibt es kein Git-Repo in diesem Ordner, brich hier ab und sag es. Ohne Versionierung ist ein Update nicht verantwortbar; der Weg dorthin steht in `ANLEITUNG.md`, Teil 5.

### 2. Quelle anbinden und holen

Einmalig, falls noch nicht vorhanden:

```powershell
git remote add upstream https://github.com/flomeile/leo-starter.git
```

Dann immer:

```powershell
git fetch upstream --tags
```

Prüfe mit `git remote -v`, ob `upstream` schon existiert, bevor du ihn hinzufügst. Ein zweiter Versuch schlägt sonst fehl, was kein Problem ist, aber unnötig verwirrt.

### 3. Ausgangs- und Zielversion bestimmen

- **Zielversion:** der höchste Tag `vX.Y` aus `git tag -l "v*"` nach dem Fetch.
- **Ausgangsversion:** der Wert aus `MEIN-SYSTEM.md`, Abschnitt 4.

Sind beide gleich, ist nichts zu tun. Sag das und höre auf.

Fehlt die Angabe in `MEIN-SYSTEM.md` (typisch bei einem System, das vor Version 1.3 eingerichtet wurde), ermittle die Ausgangsversion selbst: Vergleiche die lokale `AGENTS.md` und die lokalen Kern-Skills nacheinander gegen `git show vX.Y:<datei>` der verfügbaren Tags und nimm die Version, die am besten passt. Findest du keine Übereinstimmung, arbeite ohne Ausgangsversion weiter und behandle in Schritt 5 jede Kern-Datei als "lokal verändert". Das ist langsamer und fragt öfter, aber es ist sicher.

### 4. Verstehen, was sich geändert hat

Lies zwei Dinge, bevor du irgendetwas schreibst:

```powershell
git diff <Ausgangsversion>..<Zielversion> --stat
```

Und den Abschnitt "Versionen dieses Pakets" in der Upstream-Fassung der Anleitung:

```powershell
git show <Zielversion>:ANLEITUNG.md
```

Fasse `[NAME]` in drei bis fünf Sätzen zusammen, was die neue Version bringt und warum es ihn interessiert. Das ist keine Höflichkeit: Wer nicht weiss, was sich ändert, kann in Schritt 5 nicht entscheiden.

### 5. Dateien einarbeiten, Kategorie für Kategorie

Gehe die Liste aus `10_System\Kern-Dateien.md` durch. Für jede Datei gilt genau einer der folgenden Fälle.

**Kategorie A, lokal unverändert.** Prüfen mit einem Vergleich der lokalen Datei gegen `git show <Ausgangsversion>:<datei>`. Sind sie inhaltlich gleich (Unterschiede innerhalb von `AUTO:...:BEGIN/END`-Blöcken zählen nicht), hat der Nutzer nie eingegriffen. Dann übernimm die neue Fassung:

```powershell
git checkout <Zielversion> -- "<datei>"
```

**Kategorie A, lokal verändert.** Der Nutzer hat eingegriffen, ob absichtlich oder nicht. Jetzt wird nicht ersetzt. Lies drei Fassungen: die lokale, die alte Upstream-Fassung, die neue Upstream-Fassung. Bestimme daraus, was die neue Version inhaltlich ändert, und trage genau diese Änderung in die lokale Fassung ein, ohne die Anpassung des Nutzers anzurühren. Berührt die Neuerung dieselbe Stelle, an der der Nutzer etwas geändert hat, entscheidest du nicht selbst: Zeig beide Fassungen und frag, welche gilt.

Melde am Ende jede Datei dieser Gruppe, auch die, die glattgegangen ist. `[NAME]` muss wissen, wo sein System vom Grundgerüst abweicht.

**Kategorie B (`CLAUDE.md`, `GEMINI.md`, `.clinerules`).** Immer einarbeiten, nie ersetzen. Der lokale Anteil sind die `@`-Importzeilen, die auf die tatsächlich vorhandenen Basiskontext-Dateien zeigen. Übernimm alles Neue aus der Zielversion, lass die Importzeilen des Nutzers unverändert stehen, auch wenn sie andere Dateinamen tragen als das Grundgerüst.

**Kategorie C.** Nicht anfassen. Kein Ausnahmefall, keine Ausrede, auch nicht "das wäre aber besser so".

**Neue Kern-Dateien.** Bringt die Zielversion eine Datei mit, die es lokal nicht gibt, leg sie an und sag, wozu sie da ist.

**Gelöschte Kern-Dateien.** Fehlt eine Datei in der Zielversion, die lokal existiert: nicht löschen, nur melden. Löschen entscheidet `[NAME]`.

### 6. Prüfen, ob die eigenen Bauten noch passen

Der Teil, den kein Git-Befehl leisten kann und der der eigentliche Grund ist, warum dieser Skill existiert.

Nimm die Liste "Was ich selbst gebaut habe" aus `MEIN-SYSTEM.md` und dazu alles, was in `02_Skills` liegt und nicht in der Kern-Liste steht. Prüfe für jeden eigenen Skill und jede eigene Konvention, ob die Änderungen aus Schritt 4 sie berühren. Typische Fälle: Das Frontmatter-Schema wurde erweitert, eine Statuszeile hat neue Token bekommen, ein Kern-Skill wurde umbenannt und ein eigener Skill verweist auf den alten Namen, eine Regel hat sich umgekehrt.

Git meldet hier nichts, weil sich die Dateien nicht berühren. Ein eigener Skill, der gegen die alte Norm arbeitet, läuft nach dem Update weiter und tut das Falsche.

Melde jeden Fund mit der konkreten Zeile und einem fertigen Vorschlag, was zu ändern wäre. Ändere die eigenen Skills des Nutzers nicht selbst, ausser er sagt es.

### 7. Nachziehen und prüfen

```powershell
powershell -File 00_INDEX\scripts\build-index-geruest.ps1
```

Das füllt die `AUTO:...`-Blöcke wieder, insbesondere die Rollen-Tabelle in der `AGENTS.md`. Danach:

```powershell
powershell -File 00_INDEX\scripts\health-check.ps1
```

Meldet der Health-Check etwas Neues, das vorher nicht da war, gehört es in den Bericht.

### 8. Stand fortschreiben und committen

In `MEIN-SYSTEM.md`, Abschnitt 4: eingespielte Version und Datum auf den neuen Stand. Trägt der Nutzer Abweichungen an Kern-Dateien mit sich, ergänze Abschnitt 3 um das, was du in Schritt 5 gefunden hast.

Dann committen, mit einer Nachricht, die den Versionssprung nennt:

```powershell
git add -A
git commit -m "Mechanik-Update auf Grundgeruest <Zielversion>"
```

Push nur, wenn ein `origin` existiert.

### 9. Bericht

Kurz und in dieser Reihenfolge:

1. Von welcher auf welche Version.
2. Was die neue Version bringt (aus Schritt 4).
3. Welche Dateien ersetzt wurden.
4. Welche Dateien eingearbeitet wurden, weil lokale Anpassungen darin standen.
5. Was an eigenen Bauten geprüft wurde und was dabei aufgefallen ist.
6. Der Commit-Hash aus Schritt 1 als Rückweg.

## Definition of Done

- Kein Inhalt aus Kategorie C wurde verändert.
- Jede lokal angepasste Kern-Datei wurde eingearbeitet statt ersetzt, und jede davon steht im Bericht.
- Die eigenen Skills wurden gegen die neuen Konventionen geprüft.
- `MEIN-SYSTEM.md`, Abschnitt 4 trägt die neue Version.
- Index-Skript und Health-Check sind gelaufen.
- `[NAME]` kennt den Commit, auf den er zurücksetzen kann.

## Wenn etwas schiefgeht

Der Zustand vor dem Update liegt im Commit aus Schritt 1. `git reset --hard <Hash>` stellt ihn vollständig wieder her, inklusive aller Dateien, die dieser Skill angefasst hat. Sag das dem Nutzer im Zweifel lieber einmal zu viel.
