---
titel: Mein System (persönliche Ebene)
zweck: Alles, was an diesem System dir gehört - Name, Pfad, eigene Regeln, eigene Bauten. Wird von Updates nie angefasst.
type: master-regeln
stand: 2026-08-30
---

# Mein System

Diese Datei gehört dir. **Ein Update des Grundgerüsts fasst sie nie an.** Alles, was du an diesem System persönlich einstellst, ergänzt oder anders haben willst, gehört hierher und nicht in die `AGENTS.md`.

Warum die Trennung: Die `AGENTS.md` und die Skills sind die Mechanik. Sie werden weiterentwickelt, und du kannst dir Verbesserungen jederzeit holen (Skill `leo-mechanik-update`). Das geht nur gefahrlos, solange deine eigenen Sachen nicht in denselben Dateien stehen. Steht deine Personalisierung hier, kann ein Update nichts von dir überschreiben.

**Für das LLM:** Lies diese Datei in jeder Session zusammen mit der `AGENTS.md`. Bei Widerspruch zwischen den beiden gilt, was hier steht. Diese Datei ist die Antwort auf die Frage, wer `[NAME]` ist und wie das System hier tatsächlich heisst.

---

## 1. Meine Werte

Diese Tabelle löst die Platzhalter auf, die in der `AGENTS.md` und in den Skills stehen. Fülle sie beim Einrichten einmal aus.

| Platzhalter | Bedeutung | Mein Wert |
|---|---|---|
| `[NAME]` | Die Person, der dieses Repo gehört | *(dein Name)* |
| Systemname | Wie das System heisst (im Gerüst durchgängig "Leo") | Leo |
| Skill-Präfix | Präfix der Skill-Dateien (im Gerüst `leo-`) | `leo-` |
| Repo-Pfad | Wo das Repo auf deinem Rechner liegt (im Gerüst `C:\Leo`) | `C:\Leo` |
| Kürzel | Dein Kürzel für das Feld `geprueft:` | *(z.B. deine Initialen)* |

**Wichtig:** Wenn du dein System umbenennst oder woanders ablegst, änderst du **nur diese Tabelle**, nicht die `AGENTS.md`. Dort stehen "Leo" und `C:\Leo` als generische Bezeichnung; das LLM liest hier nach, was bei dir tatsächlich gilt. Damit bleibt die `AGENTS.md` bei allen Nutzern identisch und ist gefahrlos aktualisierbar.

Die Dateinamen deiner Skills musst du beim Umbenennen allerdings selbst mitziehen, ebenso das Präfix in dieser Tabelle. Wer bei `leo-` bleibt, hat weniger Arbeit und verliert nichts.

---

## 2. Meine eigenen Regeln

Hier stehen deine Ergänzungen und Abweichungen zur `AGENTS.md`. Sie haben Vorrang. Schreibe sie hierher und nicht in die `AGENTS.md`, dann kann ein Update sie nicht anfassen.

Beispiele für das, was hierher gehört: eine Stilregel, die nur für dich gilt; ein Ablageort, den du anders handhabst; eine Regel, die du bewusst aussetzt; eine Konvention für deine Dateinamen.

*(Noch keine eigenen Regeln. Trag sie ein, sobald du welche hast.)*

---

## 3. Was ich selbst gebaut habe

Die Liste dessen, was bei dir über das Grundgerüst hinausgeht. Sie hat einen konkreten Zweck: Beim Aktualisieren der Mechanik prüft das LLM, ob deine eigenen Bauten noch zur neuen Fassung passen. Ohne diese Liste müsste es raten.

**Eigene Skills:**

*(z.B. `leo-angebot-schreiben.md`, gebaut am ..., nutzt das Frontmatter-Schema aus AGENTS.md Abschnitt 5)*

**Eigene Themenordner:**

*(werden ohnehin über die Rollen-Tabelle in der AGENTS.md sichtbar, hier nur, was dazu erwähnenswert ist)*

**Eigene Änderungen an Kern-Dateien:**

Trage hier ein, wenn du doch einmal eine Kern-Datei angepasst hast (siehe `10_System\Kern-Dateien.md`). Das ist erlaubt, aber das Update muss davon wissen, sonst geht deine Änderung verloren oder blockiert das Update unnötig.

*(Noch keine.)*

---

## 4. Stand meines Grundgerüsts

Welche Version des Grundgerüsts bei dir eingespielt ist. Der Skill `leo-mechanik-update` liest diesen Wert, um zu wissen, was sich seither geändert hat, und schreibt ihn danach fort.

| | |
|---|---|
| Eingespielte Version | 2.2 |
| Eingespielt am | *(Datum deiner Einrichtung)* |
| Quelle | https://github.com/flomeile/leo-starter |

---

## 5. Mein Setup

Kurznotizen zu deiner Umgebung, damit das LLM nicht jedes Mal nachfragt. Was hier nicht steht, ist auch nicht schlimm.

- **Nutzungsmodus:** *(`mitbauen` oder `benutzen`. `mitbauen` heisst: Du löst Wartung selbst aus, mit Trigger-Worten wie "health check" und "wrap up". `benutzen` heisst: Du arbeitest nur inhaltlich mit dem System, und das LLM fährt fällige Wartung ungefragt selbst; die Regel dazu steht in der AGENTS.md, Abschnitt 1. Wenn du das hier liest und nicht weisst, was ein Trigger-Wort ist, bist du `benutzen`.)*
- **Werkzeug:** *(z.B. Claude Code auf dem eigenen Rechner, oder ein Chat-Harness mit Dateizugriff)*
- **Fernsicherung:** *(privates GitHub-Repo? nur lokal? Wenn nur lokal: es gibt kein Netz unter dir, siehe ANLEITUNG Teil 5)*
- **Automatik:** *(läuft der tägliche Index-Sync als geplante Aufgabe? Hook aktiv?)*
- **Besonderheiten:** *(alles, was bei dir anders ist als in der Anleitung beschrieben)*
