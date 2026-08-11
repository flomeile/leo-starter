# health-check.ps1
# Zweck: Read-only Diagnose des gesamten KI_REPO-Systems. Veraendert NICHTS am Repo.
# Denkt NICHT selbst nach: rein deterministische, mechanische Pruefungen, keine Halluzination.
#
# WICHTIG: Vor diesem Health Check IMMER zuerst build-index-geruest.ps1 laufen lassen,
# damit hier der aktuelle Stand geprueft wird, nicht ein veralteter (siehe Skill
# leo-system-health-check.md).
#
# Manche Pruefungen (z.B. Themenordner-Erkennung) sind absichtlich UNABHAENGIG von
# build-index-geruest.ps1 neu implementiert statt von dort importiert - damit dieser
# Check auch einen Bug im Generator-Skript selbst findet (ist am 2026-07-07 passiert:
# ein hartcodierter "^2\d_"-Filter haette 3X-Themenordner unsichtbar gemacht).
#
# Aufruf: pwsh -NoProfile -ExecutionPolicy Bypass -File "<REPO>\00_INDEX\scripts\health-check.ps1"
# Exit Code: 0 = alles ok (nur OK/INFO), 1 = mind. 1 WARN, 2 = mind. 1 FAIL.
# Der Repo-Root wird automatisch aus $PSScriptRoot abgeleitet (verschiebbar, kein Hardcode).

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$results = New-Object System.Collections.Generic.List[PSCustomObject]

# Verzeichnisse, die bei JEDEM rekursiven Scan uebersprungen werden. Neben .git und
# .obsidian gehoert .claude dazu: Coding-Agents legen unter .claude\worktrees\ komplette
# Arbeitskopien des Repos an. Ohne diesen Ausschluss laeuft der Check in solche Kopien
# hinein und meldet jede Datei doppelt - inklusive Phantom-Befunden, weil die
# Ausnahmelisten unten auf Relativpfaden ab Repo-Root basieren und der Worktree-Praefix
# sie nicht mehr treffen laesst (Befund 2026-07-17: zwei bereits abgestimmte
# stand:-Ausnahmen wurden aus dem Worktree heraus erneut als WARN gemeldet).
# Die uebrigen Werkzeug-Verzeichnisse tragen die generierten Skill-Zeiger (Abschnitt 11a).
# Sie sind Konfiguration, kein Wissen, und werden weder indexiert noch auf Frontmatter,
# stand: oder tote Links geprueft. Identisch zu $excludeDirs in build-index-geruest.ps1
# und zu is_fm_exempt() im pre-commit-Hook zu halten.
$excludedDirPattern = '\\\.(git|obsidian|claude|agents|gemini|cursor|cline|opencode|github)\\'

function Add-Check([string]$Level, [string]$Category, [string]$Message) {
    $results.Add([PSCustomObject]@{ Level = $Level; Category = $Category; Message = $Message })
}

Write-Output "=== Leo System Health Check ==="
Write-Output "Start: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output ""

# ---------------------------------------------------------------------------
# 1) GIT & VERSIONIERUNG
# ---------------------------------------------------------------------------
$cat = "Git"
if (-not (Test-Path (Join-Path $repo ".git"))) {
    Add-Check "FAIL" $cat "Kein .git-Ordner gefunden unter $repo - ist das ueberhaupt das Repo-Root?"
} else {
    if (Test-Path (Join-Path $repo ".git\index.lock")) {
        Add-Check "WARN" $cat "git index.lock vorhanden - evtl. laeuft parallel ein anderer Git-Prozess (z.B. der automatische Sync-Task). Health Check ggf. gleich nochmal laufen lassen."
    }

    $statusRaw = & git -C $repo status --porcelain 2>&1
    if ($LASTEXITCODE -ne 0) {
        Add-Check "FAIL" $cat "git status fehlgeschlagen: $statusRaw"
    } else {
        $mechanicalPattern = '(^|[/\\])(_INDEX\.md|INDEX\.md|INDEX-Geruest\.md|AGENTS\.md)$'
        $unexpected = @()
        $mechanical = @()
        foreach ($line in $statusRaw) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $path = $line.Substring(3).Trim('"')
            if ($path -match $mechanicalPattern) { $mechanical += $path } else { $unexpected += $path }
        }
        if ($mechanical.Count -gt 0) {
            Add-Check "INFO" $cat "$($mechanical.Count) mechanisch gepflegte Datei(en) mit unstaged Aenderungen (erwartete Index-Drift, wird beim naechsten Commit erfasst): $($mechanical -join ', ')"
        }
        if ($unexpected.Count -gt 0) {
            Add-Check "WARN" $cat "$($unexpected.Count) unerwartete uncommitted Aenderung(en), die kein reines Index-Update sind - pruefen ob gewollt: $($unexpected -join ', ')"
        }
        if ($mechanical.Count -eq 0 -and $unexpected.Count -eq 0) {
            Add-Check "OK" $cat "Working Tree sauber, keine uncommitted Aenderungen."
        }
    }

    $null = & git -C $repo fetch --quiet 2>&1
    if ($LASTEXITCODE -ne 0) {
        Add-Check "INFO" $cat "git fetch fehlgeschlagen (evtl. offline) - Vergleich mit origin/main uebersprungen."
    } else {
        $counts = & git -C $repo rev-list --left-right --count 'origin/main...HEAD' 2>&1
        if ($LASTEXITCODE -eq 0 -and $counts -match '^(\d+)\s+(\d+)$') {
            $behind = [int]$matches[1]; $ahead = [int]$matches[2]
            if ($behind -gt 0) { Add-Check "WARN" $cat "Lokaler main ist $behind Commit(s) hinter origin/main - pull nachholen." }
            if ($ahead -gt 0) { Add-Check "WARN" $cat "Lokaler main ist $ahead Commit(s) vor origin/main - noch nicht gepusht." }
            if ($behind -eq 0 -and $ahead -eq 0) { Add-Check "OK" $cat "Lokaler main deckungsgleich mit origin/main." }
        } else {
            Add-Check "INFO" $cat "Konnte Ahead/Behind zu origin/main nicht bestimmen (evtl. kein main/origin-Tracking-Branch)."
        }
    }

    $conflicts = & git -C $repo grep -l "^<<<<<<< " -- "*.md" 2>$null
    if ($conflicts) {
        Add-Check "FAIL" $cat "Ungeloeste Merge-Konflikt-Marker gefunden in: $($conflicts -join ', ')"
    } else {
        Add-Check "OK" $cat "Keine Merge-Konflikt-Marker in .md-Dateien."
    }

    # 1b) Pre-Commit-Hook: IST core.hooksPath gesetzt, und liegt der Hook dort?
    # Der Hook ist versioniert, die EINSTELLUNG nicht: Auf einem neuen Rechner
    # (oder nach einem frischen Clone) existiert die Datei, greift aber nicht.
    # Ohne diese Pruefung waere die Durchsetzung still abwesend - ein Check, der
    # nichts prueft und trotzdem gruen meldet, ist gefaehrlicher als keiner.
    $expectedHooks = "00_INDEX/githooks"
    $hooksPath = (& git -C $repo config core.hooksPath 2>$null | Select-Object -First 1)
    $hookFile = Join-Path $repo "00_INDEX\githooks\pre-commit"
    if (-not (Test-Path $hookFile)) {
        Add-Check "FAIL" $cat "Die Hook-Datei 00_INDEX\githooks\pre-commit fehlt im Repo - der Schutz gegen Konflikt-Marker und zerstoerte AUTO-Bloecke ist weg."
    } elseif ([string]::IsNullOrWhiteSpace($hooksPath)) {
        Add-Check "FAIL" $cat "core.hooksPath ist NICHT gesetzt: der Pre-Commit-Hook liegt zwar im Repo, wird aber von Git ignoriert. Einmalig setzen mit: git config core.hooksPath $expectedHooks"
    } elseif (($hooksPath -replace '\\', '/').TrimEnd('/') -ne $expectedHooks) {
        Add-Check "WARN" $cat "core.hooksPath zeigt auf '$hooksPath' statt auf '$expectedHooks' - der Hook laeuft so nicht. Pruefen und ggf. korrigieren: git config core.hooksPath $expectedHooks"
    } else {
        Add-Check "OK" $cat "Pre-Commit-Hook aktiv (core.hooksPath = $expectedHooks, Hook-Datei vorhanden)."
    }
}
Write-Output "Git-Checks erledigt."

# ---------------------------------------------------------------------------
# 2) SCHEDULED TASKS (automatischer Sync)
# ---------------------------------------------------------------------------
$cat = "Scheduled Tasks"
try {
    $tasks = Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskName -match "(Leo|KI[-_]?REPO)" }
    if (-not $tasks -or $tasks.Count -eq 0) {
        Add-Check "WARN" $cat "Keine Scheduled Task mit 'Leo' (oder alt 'KI-REPO') im Namen gefunden - automatischer Index-Sync/Git-Push laeuft evtl. nicht (mehr)."
    } else {
        foreach ($t in $tasks) {
            $info = Get-ScheduledTaskInfo -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue
            $state = $t.State
            $lastResult = if ($info) { $info.LastTaskResult } else { $null }
            $lastRun = if ($info) { $info.LastRunTime } else { $null }
            if ($state -eq "Disabled") {
                Add-Check "WARN" $cat "Task '$($t.TaskName)' ist DEAKTIVIERT."
            } elseif ($null -ne $lastResult -and $lastResult -ne 0) {
                Add-Check "WARN" $cat "Task '$($t.TaskName)' letzter Lauf mit Fehlercode $lastResult (Stand $lastRun)."
            } else {
                Add-Check "OK" $cat "Task '$($t.TaskName)' aktiv, letzter Lauf ok ($lastRun)."
            }
        }
    }
} catch {
    Add-Check "INFO" $cat "Get-ScheduledTask nicht verfuegbar oder fehlgeschlagen ($($_.Exception.Message)) - Task-Pruefung uebersprungen."
}
Write-Output "Scheduled-Task-Checks erledigt."

# ---------------------------------------------------------------------------
# 3) AUTO-BLOCK-MARKER-INTEGRITAET
# ---------------------------------------------------------------------------
$cat = "Auto-Bloecke"
function Test-AutoBlockMarkers([string]$file, [string[]]$blockNames) {
    if (-not (Test-Path $file)) { Add-Check "FAIL" $cat "Datei fehlt: $file"; return }
    $text = Get-Content -Path $file -Raw -Encoding UTF8
    foreach ($name in $blockNames) {
        $beginTag = "<!-- AUTO:${name}:BEGIN -->"
        $endTag = "<!-- AUTO:${name}:END -->"
        $beginCount = ([regex]::Matches($text, [regex]::Escape($beginTag))).Count
        $endCount = ([regex]::Matches($text, [regex]::Escape($endTag))).Count
        $bi = $text.IndexOf($beginTag)
        $ei = $text.IndexOf($endTag)
        if ($beginCount -ne 1 -or $endCount -ne 1) {
            Add-Check "FAIL" $cat "$file : Auto-Block '$name' hat $beginCount BEGIN- und $endCount END-Marker (je genau 1 erwartet)."
        } elseif ($bi -ge $ei) {
            Add-Check "FAIL" $cat "$file : Auto-Block '$name' - BEGIN-Marker liegt nach END-Marker."
        } else {
            Add-Check "OK" $cat "$file : Auto-Block '$name' intakt."
        }
    }
}
Test-AutoBlockMarkers (Join-Path $repo "00_INDEX\INDEX.md") @("BAUM", "BEREICHE")
Test-AutoBlockMarkers (Join-Path $repo "AGENTS.md") @("ROLLEN")
Write-Output "Auto-Block-Checks erledigt."

# ---------------------------------------------------------------------------
# 4) THEMENORDNER-REGISTRIERUNG VOLLSTAENDIG (unabhaengig neu implementiert)
# ---------------------------------------------------------------------------
$cat = "Themenordner"

function Test-IsThemenordnerHC([System.IO.DirectoryInfo]$dir) {
    if ($dir.Name -notmatch "^(\d+)_") { return $false }
    $num = [int]$matches[1]
    if ($num -lt 20) { return $false }
    $agentsFile = Join-Path $dir.FullName "AGENTS.md"
    if (-not (Test-Path $agentsFile)) { return $false }
    $hasRolle = (Get-Content -Path $agentsFile -Encoding UTF8 -ErrorAction SilentlyContinue | Select-String -Pattern "^#\s+Rolle:").Count -gt 0
    return $hasRolle
}

$allNumberedDirs = Get-ChildItem -Path $repo -Directory | Where-Object { $_.Name -match "^(\d+)_" }
$dupGroups = $allNumberedDirs | Group-Object { [regex]::Match($_.Name, "^(\d+)_").Groups[1].Value } | Where-Object { $_.Count -gt 1 }
foreach ($g in $dupGroups) {
    Add-Check "FAIL" $cat "Doppelt vergebene Ordnernummer '$($g.Name)': $($g.Group.Name -join ', ')"
}

$themen = $allNumberedDirs | Where-Object { Test-IsThemenordnerHC $_ }
if ($themen.Count -eq 0) {
    Add-Check "WARN" $cat "Kein einziger Themenordner erkannt - pruefen, ob das plausibel ist."
}

$indexText = Get-Content -Path (Join-Path $repo "00_INDEX\INDEX.md") -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
$agentsText = Get-Content -Path (Join-Path $repo "AGENTS.md") -Raw -Encoding UTF8 -ErrorAction SilentlyContinue

foreach ($t in $themen) {
    $name = $t.Name
    $missing = @()
    if (-not (Test-Path (Join-Path $t.FullName "_INDEX.md"))) { $missing += "_INDEX.md fehlt" }
    if (-not (Test-Path (Join-Path $t.FullName "README.md"))) { $missing += "README.md fehlt" }
    if ($agentsText -notmatch [regex]::Escape("| $name |")) { $missing += "kein Eintrag in AGENTS.md ROLLEN-Tabelle" }
    if ($indexText -notmatch [regex]::Escape("**$name**")) { $missing += "kein Eintrag in INDEX.md Themenbereiche" }
    if ($missing.Count -gt 0) {
        Add-Check "FAIL" $cat "$name : $($missing -join '; ')"
    } else {
        Add-Check "OK" $cat "$name vollstaendig registriert (Rolle, README, lokaler Index, INDEX.md-Eintrag)."
    }
}
Write-Output "Themenordner-Checks erledigt."

# ---------------------------------------------------------------------------
# 5) LOKALE INDEX-ABDECKUNG (kuratierte Beschreibungen)
# ---------------------------------------------------------------------------
$cat = "Index-Abdeckung"
$excludedMeta = @("AGENTS.md", "README.md", "_INDEX.md")
# Dauer-Ausnahmen von der Beschreibungspflicht: Dateien/Ordner, die zu gross oder zu
# zahlreich fuer sinnvolle Einzelbeschreibungen sind (z.B. ein langes Manuskript, ein
# Archiv-Ordner). Hier bewusst leer; bei Bedarf selbst eintragen. Format:
# "Themenordner/relativer Pfad" oder "Themenordner/Unterordner/*" (Wildcard).
$knownCoverageExclusions = @(
)

foreach ($t in $themen) {
    $idx = Join-Path $t.FullName "_INDEX.md"
    if (-not (Test-Path $idx)) { continue }

    $onDisk = Get-ChildItem -Path $t.FullName -Recurse -File -Filter "*.md" |
        Where-Object { $excludedMeta -notcontains $_.Name } |
        ForEach-Object { $_.FullName.Substring($t.FullName.Length + 1).Replace('\', '/') } |
        Where-Object {
            $rel = "$($t.Name)/$_"
            -not ($knownCoverageExclusions | Where-Object { $rel -like $_ })
        }

    $idxText = Get-Content -Path $idx -Raw -Encoding UTF8
    $describedPaths = [regex]::Matches($idxText, '(?m)^- \*\*(.+?)\*\*') | ForEach-Object { $_.Groups[1].Value.Replace('\', '/') }

    $missing = $onDisk | Where-Object { $describedPaths -notcontains $_ }
    if ($missing.Count -gt 0) {
        $shown = $missing | Select-Object -First 15
        $suffix = if ($missing.Count -gt 15) { " (+$($missing.Count - 15) weitere)" } else { "" }
        Add-Check "WARN" $cat "$($t.Name): $($missing.Count) Datei(en) ohne kuratierte Beschreibung: $($shown -join ', ')$suffix"
    } else {
        Add-Check "OK" $cat "$($t.Name): alle Dateien (ausser AGENTS.md/README.md) kuratiert beschrieben."
    }

    $orphaned = $describedPaths | Where-Object { -not (Test-Path (Join-Path $t.FullName $_)) }
    if ($orphaned.Count -gt 0) {
        Add-Check "WARN" $cat "$($t.Name): $($orphaned.Count) kuratierte Beschreibung(en) verweisen auf nicht mehr existierende Dateien (sollte das Generator-Skript eigentlich entfernt haben): $($orphaned -join ', ')"
    }
}

# ---------------------------------------------------------------------------
# 5b) ROOT-INDEX-ABDECKUNG DER SYSTEMORDNER
# ---------------------------------------------------------------------------
# Pruefung 5) oben deckt NUR Themenordner ab (Nummer >= 20, je eigene lokale
# _INDEX.md). Die Systemordner darunter haben keine lokale _INDEX.md; ihre
# kuratierten Beschreibungen stehen in den Abschnitten der Root-INDEX.md. Ohne
# diese Pruefung bleibt dort jede Luecke mechanisch unsichtbar - Befund
# 2026-07-17: leo-markt-monitor.md war seit dem 2026-07-14 unbeschrieben, ohne
# dass ein einziger Health-Check-Lauf das gemeldet haette.
# 03_Sessionlogs und 04_Changelog stehen bewusst NICHT in dieser Liste: sie sind
# in der Root-INDEX.md absichtlich als Sammeleintrag ("03_Sessionlogs\...")
# gefuehrt statt Datei fuer Datei.
$systemCoverageDirs = @("01_Basiskontext", "02_Skills", "10_System")

$describedInRoot = @([regex]::Matches($indexText, '(?m)^- \*\*(.+?\.md)\*\*') | ForEach-Object { $_.Groups[1].Value })

foreach ($sd in $systemCoverageDirs) {
    $sdPath = Join-Path $repo $sd
    if (-not (Test-Path $sdPath)) {
        Add-Check "WARN" $cat "Systemordner $sd wird erwartet, ist aber nicht vorhanden."
        continue
    }
    $onDiskSys = @(Get-ChildItem -Path $sdPath -File -Filter "*.md" |
        Where-Object { $_.Name -ne "README.md" } |
        ForEach-Object { "$sd\$($_.Name)" })

    $missingSys = @($onDiskSys | Where-Object { $describedInRoot -notcontains $_ })
    if ($missingSys.Count -gt 0) {
        Add-Check "WARN" $cat "$sd : $($missingSys.Count) Datei(en) ohne kuratierte Beschreibung in 00_INDEX\INDEX.md: $($missingSys -join ', ')"
    } else {
        Add-Check "OK" $cat "$sd : alle Dateien (ausser README.md) in der Root-INDEX.md kuratiert beschrieben."
    }
}

# Gegenrichtung: eine kuratierte Beschreibung verweist auf eine Datei, die es gar
# nicht gibt. Das faellt sonst niemandem auf, weil der Eintrag ja "da" ist - der
# Verweis laeuft aber ins Leere und keine Agentic Search findet die Datei je.
# Typischer Ausloeser: Eine Datei wird umbenannt (z.B. Umlaut-Korrektur), der
# Index-Eintrag traegt aber weiter den alten Namen. Sammeleintraege ("...") matcht
# die Regex nicht.
$orphanedRoot = @($describedInRoot | Where-Object { -not (Test-Path (Join-Path $repo $_)) })
if ($orphanedRoot.Count -gt 0) {
    Add-Check "FAIL" $cat "$($orphanedRoot.Count) kuratierte Beschreibung(en) in 00_INDEX\INDEX.md verweisen auf nicht existierende Dateien: $($orphanedRoot -join ', ')"
} else {
    Add-Check "OK" $cat "Alle kuratierten Beschreibungen in 00_INDEX\INDEX.md verweisen auf real existierende Dateien."
}
Write-Output "Index-Abdeckungs-Checks erledigt."

# ---------------------------------------------------------------------------
# 6) VERALTETE "stand:"-DATEN (> 60 Tage) UND ABGELAUFENE "gueltig_bis:"-DATEN
# ---------------------------------------------------------------------------
$cat = "Aktualitaet"
$staleFiles = @()
$driftFiles = @()
# 'gueltig_bis:' (optional, AGENTS.md Abschnitt 7) ist die Gegenrichtung zu 'stand:':
# nicht "wann zuletzt geprueft", sondern "ab wann wertlos". Gelesen wird "gueltig bis
# einschliesslich", abgelaufen ist eine Datei also erst am Tag NACH dem eingetragenen
# Datum. Zwei Wirkungen: abgelaufene Dateien werden gemeldet, und Dateien mit eigenem
# Ablaufdatum sind von der pauschalen 60-Tage-Warnung ausgenommen. Letzteres ist
# Absicht: Eine Meeting-Vorbereitung ist nach 60 Tagen tot, ein Strategiepapier nicht,
# und eine Datei, die ihre Frist selbst mitbringt, braucht die grobe Heuristik nicht.
$expiredFiles = @()
# Drift-Ausnahmen: Rohquellen, deren 'stand:' bewusst das Datum des Ursprungsdokuments
# traegt (z.B. Datum einer eingelesenen PDF), nicht das Datum der letzten Git-Aenderung
# (die oft nur die Uebernahme ins Repo ist). Hier bewusst leer; bei Bedarf selbst
# eintragen, Format "Themenordner/relativer Pfad".
$knownDriftExceptions = @(
)
# Rein mechanische Commits, die den Inhalt einer Datei NICHT veraendert haben und
# deshalb bei der Drift-Berechnung uebersprungen werden. Hintergrund: Ein Massenlauf
# ueber viele Dateien (z.B. eine Umstellung der Linkschreibweise) aendert keine
# einzige Aussage darin. Wuerde man dafuer ueberall 'stand:' auf den Umstellungstag
# setzen, behaupteten anschliessend auch alte Notizen, sie seien heute geprueft
# worden, also genau die Fehlinformation, die 'stand:' verhindern soll. Umgekehrt
# wuerde eine Dauer-Warnung ueber alle betroffenen Dateien den Check unbrauchbar
# machen. Deshalb: Commit ueberspringen, 'stand:' unangetastet lassen. Eintraege sind
# die kurzen Commit-Hashes, NUR fuer nachweislich inhaltsneutrale Massenlaeufe.
$mechanicalCommits = @(
)
Get-ChildItem -Path $repo -Recurse -Filter "*.md" -File | Where-Object { $_.Name -ne "_INDEX.md" -and $_.FullName -notmatch $excludedDirPattern } | ForEach-Object {
    $hasExpiry = $false
    $gb = Select-String -Path $_.FullName -Pattern '^gueltig_bis:\s*(\d{4}-\d{2}-\d{2})' -List -ErrorAction SilentlyContinue
    if ($gb) {
        $hasExpiry = $true
        $gbStr = $gb.Matches[0].Groups[1].Value
        $gbDate = [datetime]::ParseExact($gbStr, "yyyy-MM-dd", $null)
        if ((Get-Date).Date -gt $gbDate.Date) {
            $expiredDays = (New-TimeSpan -Start $gbDate.Date -End (Get-Date).Date).Days
            $expiredFiles += "$($_.FullName.Substring($repo.Length + 1)) (gueltig_bis $gbStr, seit $expiredDays Tag(en) abgelaufen)"
        }
    }
    $m = Select-String -Path $_.FullName -Pattern '^stand:\s*(\d{4}-\d{2}-\d{2})' -List -ErrorAction SilentlyContinue
    if ($m) {
        $standStr = $m.Matches[0].Groups[1].Value
        $d = [datetime]::ParseExact($standStr, "yyyy-MM-dd", $null)
        $age = (New-TimeSpan -Start $d -End (Get-Date)).Days
        if ($age -gt 60 -and -not $hasExpiry) {
            $staleFiles += "$($_.FullName.Substring($repo.Length + 1)) (Stand $standStr, $age Tage alt)"
        }
        # 6b) Drift: Datei wurde laut Git DEUTLICH nach dem eingetragenen stand:
        # geaendert (> 7 Tage) - stand: wurde beim Bearbeiten nicht nachgefuehrt.
        $rel = $_.FullName.Substring($repo.Length + 1).Replace('\', '/')
        if ($knownDriftExceptions -contains $rel) { return }
        # Juengste Aenderung suchen, die kein rein mechanischer Commit war.
        $gitDateRaw = $null
        $hist = & git -C $repo log --format="%H %ad" --date=format:%Y-%m-%d -- "$($_.FullName)" 2>$null
        if ($LASTEXITCODE -eq 0) {
            foreach ($line in @($hist)) {
                $parts = "$line".Split(' ')
                if ($parts.Count -lt 2) { continue }
                $skip = $false
                foreach ($mc in $mechanicalCommits) { if ($parts[0].StartsWith($mc)) { $skip = $true; break } }
                if ($skip) { continue }
                $gitDateRaw = $parts[1]
                break
            }
        }
        if ("$gitDateRaw" -match '^\d{4}-\d{2}-\d{2}$') {
            $gitDate = [datetime]::ParseExact("$gitDateRaw", "yyyy-MM-dd", $null)
            $lagDays = (New-TimeSpan -Start $d -End $gitDate).Days
            if ($lagDays -gt 7) {
                $driftFiles += "$($_.FullName.Substring($repo.Length + 1)) (stand: $standStr, letzte Git-Aenderung $gitDateRaw)"
            }
        }
    }
}
if ($staleFiles.Count -gt 0) {
    Add-Check "WARN" $cat "$($staleFiles.Count) Datei(en) mit 'stand:' aelter als 60 Tage: $($staleFiles -join ' | ')"
} else {
    Add-Check "OK" $cat "Keine 'stand:'-Datumsangabe aelter als 60 Tage (Dateien mit eigenem 'gueltig_bis' sind hier ausgenommen)."
}
if ($expiredFiles.Count -gt 0) {
    Add-Check "WARN" $cat "$($expiredFiles.Count) Datei(en) mit abgelaufenem 'gueltig_bis': $($expiredFiles -join ' | ') - je Datei entscheiden: erledigt (Inhalt in die zustaendige Wissensdatei uebernehmen und Datei loeschen), verlaengern (neues Datum) oder als Historie behalten ('gueltig_bis' entfernen)."
} else {
    Add-Check "OK" $cat "Keine Datei mit abgelaufenem 'gueltig_bis'."
}
if ($driftFiles.Count -gt 0) {
    Add-Check "WARN" $cat "$($driftFiles.Count) Datei(en) wurden nach ihrem 'stand:'-Datum weiter geaendert, ohne dass stand: nachgefuehrt wurde: $($driftFiles -join ' | ')"
} else {
    Add-Check "OK" $cat "Alle 'stand:'-Datumsangaben passen zur letzten Git-Aenderung (Toleranz 7 Tage)."
}

# 6c) Dynamische Dateien OHNE 'stand:'-Kennzeichnung.
# 'stand:' im Frontmatter ist die verbindliche Kennzeichnung fuer Dokumente mit
# variablem Input (AGENTS.md Abschnitt 7). Zwei Heuristiken, damit nichts durchrutscht:
# (a) Dateiname klingt dynamisch, (b) Inhalt enthaelt offene Checkboxen oder eine
# Status-Spalte in einer Tabelle (faengt dynamische Inhalte hinter unauffaelligen
# Namen), (c) Datei liegt in einem Ordner, dessen Inhalt per lokaler AGENTS.md
# als lebende Arbeitsdokumente definiert ist. Bewusst WARN, nicht FAIL.
$dynamicNamePattern = '(aufgaben|taskliste|tasks|status|todo|to-do|verlauf|backlog|pendenzen|checklist|plan)'
$dynamicContentPattern = '(^\s*[-*] \[[ xX]\] )|(\|\s*Status\s*\|)'
$dynamicDirPattern = '\\__KEIN_LEBEND_ORDNER_DEFINIERT__\\'
# Ausnahmen: dynamisch klingender Name/Inhalt/Ort, aber tatsaechlich statisch.
# Hier bewusst leer; bei Bedarf selbst eintragen. Format: "Themenordner/relativer Pfad".
$knownStaticExceptions = @(
)
$untagged = @()
Get-ChildItem -Path $repo -Recurse -Filter "*.md" -File |
    Where-Object {
        $_.FullName -notmatch $excludedDirPattern -and
        $_.FullName -notmatch '\\(00_INDEX|02_Skills|03_Sessionlogs)\\' -and
        $_.Name -notin @("README.md", "AGENTS.md", "_INDEX.md")
    } | ForEach-Object {
        $rel = $_.FullName.Substring($repo.Length + 1).Replace('\', '/')
        if ($knownStaticExceptions -contains $rel) { return }
        $nameHit = $_.BaseName -match $dynamicNamePattern
        $dirHit = $_.FullName -match $dynamicDirPattern
        $contentHit = $false
        if (-not ($nameHit -or $dirHit)) {
            $contentHit = [bool](Select-String -Path $_.FullName -Pattern $dynamicContentPattern -List -ErrorAction SilentlyContinue)
        }
        if (-not ($nameHit -or $dirHit -or $contentHit)) { return }
        $hasStand = Select-String -Path $_.FullName -Pattern '^stand:\s*\d{4}-\d{2}-\d{2}' -List -ErrorAction SilentlyContinue
        if (-not $hasStand) {
            $reason = if ($nameHit) { "Name" } elseif ($dirHit) { "Ordner mit lebenden Arbeitsdokumenten" } else { "Inhalt: Checkboxen/Status-Tabelle" }
            $untagged += "$rel ($reason)"
        }
    }
if ($untagged.Count -gt 0) {
    Add-Check "WARN" $cat "$($untagged.Count) dynamische Datei(en) ohne 'stand:'-Frontmatter (Kennzeichnungspflicht, AGENTS.md Abschnitt 7): $($untagged -join ', ') - 'stand:' ergaenzen oder als statische Ausnahme in health-check.ps1 eintragen."
} else {
    Add-Check "OK" $cat "Alle als dynamisch erkannten Dateien (Name/Inhalt/Ordner) tragen die 'stand:'-Kennzeichnung."
}
Write-Output "Aktualitaets-Checks erledigt."

# ---------------------------------------------------------------------------
# 7) SKILL-REGISTRY-KONSISTENZ
# ---------------------------------------------------------------------------
$cat = "Skills"
$skillDir = Join-Path $repo "02_Skills"
$registerFile = Join-Path $skillDir "Skill-Register.md"

if (-not (Test-Path $registerFile)) {
    Add-Check "FAIL" $cat "Skill-Register.md fehlt komplett."
} else {
    $registerText = Get-Content -Path $registerFile -Raw -Encoding UTF8
    $skillFiles = Get-ChildItem -Path $skillDir -Filter "*.md" -File | Where-Object { $_.Name -notin @("README.md", "Skill-Register.md") }

    $unregistered = @()
    foreach ($sf in $skillFiles) {
        if ($registerText -notmatch [regex]::Escape("02_Skills/$($sf.Name)") -and $registerText -notmatch [regex]::Escape("02_Skills\$($sf.Name)")) {
            $unregistered += $sf.Name
        }
    }
    if ($unregistered.Count -gt 0) {
        Add-Check "WARN" $cat "Skill-Datei(en) existieren, sind aber nicht im Skill-Register eingetragen: $($unregistered -join ', ')"
    }

    $registerRows = [regex]::Matches($registerText, '(?m)^\|[^\n|]+\|[^\n|]+\|\s*(02_Skills[/\\][^\s|]+\.md)\s*\|')
    $brokenRefs = @()
    foreach ($rm in $registerRows) {
        $relPath = $rm.Groups[1].Value.Replace('\', '/')
        if (-not (Test-Path (Join-Path $repo $relPath))) { $brokenRefs += $relPath }
    }
    if ($brokenRefs.Count -gt 0) {
        Add-Check "FAIL" $cat "Skill-Register verweist auf nicht existierende Datei(en): $($brokenRefs -join ', ')"
    }

    $triggerRows = [regex]::Matches($registerText, '(?m)^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|')
    $allTriggers = New-Object System.Collections.Generic.List[PSCustomObject]
    foreach ($tr in $triggerRows) {
        $skillName = $tr.Groups[1].Value.Trim()
        if ($skillName -eq "Skill" -or $skillName -match "^-+$") { continue }
        $triggerCol = $tr.Groups[2].Value
        $words = [regex]::Matches($triggerCol, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value.Trim().ToLower() }
        foreach ($w in $words) { $allTriggers.Add([PSCustomObject]@{ Skill = $skillName; Word = $w }) }
    }
    $dupTriggers = $allTriggers | Group-Object Word | Where-Object { $_.Count -gt 1 }
    foreach ($d in $dupTriggers) {
        $owners = ($d.Group.Skill | Select-Object -Unique)
        if ($owners.Count -gt 1) {
            Add-Check "FAIL" $cat "Trigger-Wort '$($d.Name)' ist mehrdeutig, verwendet von: $($owners -join ', ')"
        }
    }
    if ($skillFiles.Count -gt 0 -and $unregistered.Count -eq 0 -and $brokenRefs.Count -eq 0 -and $dupTriggers.Count -eq 0) {
        Add-Check "OK" $cat "$($skillFiles.Count) Skill-Dateien, Register vollstaendig und konsistent, Trigger-Woerter eindeutig."
    }
}
Write-Output "Skill-Registry-Checks erledigt."

# ---------------------------------------------------------------------------
# 8) ENCODING-SANITY
# ---------------------------------------------------------------------------
$cat = "Encoding"
$replacementChar = [char]0xFFFD
$badFiles = Get-ChildItem -Path $repo -Recurse -Filter "*.md" -File |
    Where-Object { $_.FullName -notmatch $excludedDirPattern } |
    ForEach-Object {
        $hit = Select-String -Path $_.FullName -Pattern ([regex]::Escape($replacementChar)) -List -ErrorAction SilentlyContinue
        if ($hit) { $_.FullName.Substring($repo.Length + 1) }
    }
if ($badFiles) {
    Add-Check "WARN" $cat "Replacement-Zeichen (Encoding-Problem) gefunden in: $($badFiles -join ', ')"
} else {
    Add-Check "OK" $cat "Keine Encoding-Artefakte (Replacement-Zeichen) gefunden."
}
Write-Output "Encoding-Checks erledigt."

# ---------------------------------------------------------------------------
# 9) INBOX
# ---------------------------------------------------------------------------
$cat = "Inbox"
# Rekursiv und ueber alle Dateitypen: In der Inbox liegen typischerweise PDFs, Scans und
# Office-Dateien, und seit dem 30.07.2026 auch Unterordner. Eine Pruefung nur auf *.md
# direkt im Ordner meldete eine volle Inbox als leer.
$inboxRoot = Join-Path $repo "90_Inbox"
$inboxFiles = Get-ChildItem -Path $inboxRoot -File -Recurse -ErrorAction SilentlyContinue |
    ForEach-Object { $_.FullName.Substring($inboxRoot.Length + 1) } |
    Where-Object { $_ -ne "README.md" }
if ($inboxFiles.Count -gt 0) {
    $shown = $inboxFiles | Select-Object -First 10
    $liste = $shown -join ', '
    if ($inboxFiles.Count -gt $shown.Count) { $liste += ", ... und $($inboxFiles.Count - $shown.Count) weitere" }
    Add-Check "WARN" $cat "$($inboxFiles.Count) unsortierte Datei(en) in 90_Inbox: $liste - wird im Skill 'leo-system-health-check' (Schritt Inbox) behandelt."
} else {
    Add-Check "OK" $cat "90_Inbox leer (bis auf README.md), inkl. Unterordner und Nicht-Markdown-Dateien."
}
Write-Output "Inbox-Check erledigt."

# ---------------------------------------------------------------------------
# 10) 01_BASISKONTEXT - KUERZLICHE AENDERUNGEN (gegen Changelog abgleichen)
# ---------------------------------------------------------------------------
$cat = "Basiskontext"
$changelogFile = Join-Path $repo "04_Changelog\Changelog.md"
if (-not (Test-Path $changelogFile)) {
    Add-Check "WARN" $cat "04_Changelog\Changelog.md fehlt - Aenderungen an 01_Basiskontext koennten unprotokolliert sein."
}
Get-ChildItem -Path (Join-Path $repo "01_Basiskontext") -Filter "*.md" -File -ErrorAction SilentlyContinue | ForEach-Object {
    $lastLog = & git -C $repo log -1 --format="%ad|%s" --date=format:%Y-%m-%d -- "$($_.FullName)" 2>&1
    if ($LASTEXITCODE -eq 0 -and $lastLog -match '^(\d{4}-\d{2}-\d{2})\|(.*)$') {
        $d = [datetime]::ParseExact($matches[1], "yyyy-MM-dd", $null)
        $age = (New-TimeSpan -Start $d -End (Get-Date)).Days
        if ($age -le 14) {
            Add-Check "INFO" $cat "$($_.Name) vor $age Tag(en) geaendert (Commit: '$($matches[2])') - gegen Changelog abgleichen, falls nicht bereits bestaetigt."
        }
    }
}
Write-Output "Basiskontext-Checks erledigt."

# ---------------------------------------------------------------------------
# 11) HARNESS-PORTABILITAETSDATEIEN
# ---------------------------------------------------------------------------
$cat = "Portabilitaet"
foreach ($f in @("CLAUDE.md", "GEMINI.md", ".clinerules", ".github/copilot-instructions.md")) {
    $full = Join-Path $repo $f
    if (-not (Test-Path $full)) {
        Add-Check "FAIL" $cat "$f fehlt im Root."
        continue
    }
    $content = Get-Content -Path $full -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($content)) {
        Add-Check "FAIL" $cat "$f ist leer."
    } elseif ($content -notmatch "AGENTS\.md") {
        Add-Check "WARN" $cat "$f verweist nicht erkennbar auf AGENTS.md."
    } else {
        Add-Check "OK" $cat "$f vorhanden und verweist auf AGENTS.md."
    }
}
# Seit E21/E22 duerfen sich CLAUDE.md und GEMINI.md im Wortlaut unterscheiden: Claude Code
# importiert mit "@Pfad", Gemini CLI verlangt "@./Pfad" (Memory Import Processor), und
# GEMINI.md traegt zusaetzlich einen Verifikations-Hinweis. Ein Byte-Vergleich wuerde das
# als Fehler melden und waere ab sofort Dauerrauschen. Geprueft wird deshalb die Eigenschaft,
# auf die es wirklich ankommt: Beide Dateien muessen dieselbe Menge an Dateien importieren
# (AGENTS.md plus alle Dateien in 01_Basiskontext), damit der Basiskontext-Zwang in jedem
# Harness greift und nicht nur in Claude Code.
function Get-ImportSet([string]$file) {
    $set = New-Object System.Collections.Generic.HashSet[string]
    $raw = Get-Content -Path $file -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $raw) { return ,$set }
    $raw = [regex]::Replace($raw, '`[^`\r\n]*`', '')   # Beispiele in Backticks ignorieren
    foreach ($line in ($raw -split "`r?`n")) {
        if ($line -match '^\s*@(\.{1,2}/)?(.+?)\s*$') {
            [void]$set.Add(($matches[2] -replace '\\', '/').Trim().ToLower())
        }
    }
    # Komma-Operator: verhindert, dass PowerShell die Menge beim Return entrollt. Ohne
    # ihn kommt bei einem LEEREN Set $null zurueck, der Contains-Aufruf unten wirft, und
    # der Check meldet danach faelschlich OK - also ausgerechnet dann gruen, wenn gar
    # kein Import vorhanden ist.
    return ,$set
}
$claudeImports = Get-ImportSet (Join-Path $repo "CLAUDE.md")
$geminiImports = Get-ImportSet (Join-Path $repo "GEMINI.md")
$expected = New-Object System.Collections.Generic.HashSet[string]
[void]$expected.Add("agents.md")
Get-ChildItem -Path (Join-Path $repo "01_Basiskontext") -Filter "*.md" -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "README.md" } |
    ForEach-Object { [void]$expected.Add("01_basiskontext/$($_.Name.ToLower())") }

foreach ($pair in @(@{ n = "CLAUDE.md"; s = $claudeImports }, @{ n = "GEMINI.md"; s = $geminiImports })) {
    $missing = @($expected | Where-Object { -not $pair.s.Contains($_) })
    if ($missing.Count -gt 0) {
        Add-Check "WARN" $cat "$($pair.n) importiert $($missing.Count) Pflichtdatei(en) nicht: $($missing -join ', '). Ohne Import ist der Basiskontext-Zwang aus E21 in diesem Harness wirkungslos."
    } else {
        Add-Check "OK" $cat "$($pair.n) importiert AGENTS.md und alle $($expected.Count - 1) Basiskontext-Dateien (E21)."
    }
}

# Die Werkzeuge ohne Import-Mechanik (.clinerules, copilot-instructions.md) koennen den
# Basiskontext nicht laden, sie muessen ihn textlich anweisen. Ohne diesen Satz startet
# ein Wechsel dorthin ohne Stilregeln, und genau das soll der Basiskontext-Zwang verhindern.
foreach ($f in @(".clinerules", ".github/copilot-instructions.md")) {
    $full = Join-Path $repo $f
    if (-not (Test-Path $full)) { continue }
    $content = Get-Content -Path $full -Raw -Encoding UTF8
    if ($content -notmatch "01_Basiskontext") {
        Add-Check "WARN" $cat "$f weist nicht auf 01_Basiskontext hin. Dieses Werkzeug kennt keinen Import; ohne die textliche Anweisung greift der Basiskontext-Zwang dort nicht (AGENTS.md Abschnitt 11a)."
    } else {
        Add-Check "OK" $cat "$f weist textlich auf 01_Basiskontext hin (Ersatz fuer den fehlenden Import)."
    }
}

# Skill-Zeiger in allen Werkzeug-Pfaden (AGENTS.md Abschnitt 11a). Geprueft wird, ob jedes
# Zielverzeichnis genau die Skills aus dem Register traegt. Faellt eines zurueck, fehlen
# beim Wechsel in dieses Werkzeug still ein paar Skills - der Fehler, den man erst merkt,
# wenn man ihn schon gemacht hat. Die Liste ist identisch zu $targets in
# build-skill-wrapper.ps1 zu halten; wer eine aendert, zieht die andere nach.
$skillTargets = @(".claude/skills", ".agents/skills", ".gemini/skills", ".cursor/skills", ".cline/skills", ".opencode/skills")
$registerSlugs = @()
$regFile = Join-Path $repo "02_Skills\Skill-Register.md"
if (Test-Path $regFile) {
    foreach ($line in (Get-Content -Path $regFile -Encoding UTF8)) {
        $t = $line.Trim()
        if (-not $t.StartsWith("|")) { continue }
        $cols = ($t.Trim("|") -split "\|") | ForEach-Object { $_.Trim() }
        if ($cols.Count -lt 4) { continue }
        if ($cols[2] -match "([^/\\]+)\.md\s*$") { $registerSlugs += $matches[1] }
    }
}
if ($registerSlugs.Count -eq 0) {
    Add-Check "WARN" $cat "Keine Skills aus dem Register gelesen - Zeiger-Pruefung uebersprungen."
} else {
    $behind = @()
    foreach ($rel in $skillTargets) {
        $dir = Join-Path $repo ($rel -replace '/', '\')
        $missing = @($registerSlugs | Where-Object { -not (Test-Path (Join-Path $dir "$_\SKILL.md")) })
        if ($missing.Count -gt 0) { $behind += "$rel (fehlen: $($missing.Count))" }
    }
    if ($behind.Count -gt 0) {
        Add-Check "WARN" $cat "Skill-Zeiger unvollstaendig in: $($behind -join ', '). Behebung: pwsh -NoProfile -ExecutionPolicy Bypass -File `"$repo\00_INDEX\scripts\build-skill-wrapper.ps1`""
    } else {
        Add-Check "OK" $cat "Skill-Zeiger vollstaendig: $($registerSlugs.Count) Skills in allen $($skillTargets.Count) Werkzeug-Pfaden (Abschnitt 11a)."
    }
}
# Kodierung der PowerShell-Skripte.
# Windows PowerShell 5.1 liest eine .ps1 ohne BOM als ANSI. Enthaelt die Datei Umlaute,
# zerfallen sie beim Parsen (aus einem Umlaut werden zwei Zeichen, deren zweites der
# 5.1er Tokenizer als Anfuehrungszeichen liest), und das Skript bricht ab, bevor eine
# Zeile laeuft. Auf einem Rechner ohne PowerShell 7 ist es damit unbenutzbar, und der
# Schaden ist still: Es erscheint keine Fehlermeldung, die betroffene Automatik hoert
# einfach auf zu wirken. Zulaessig ist deshalb beides: BOM oder durchgehend ASCII.
$psBad = @()
foreach ($ps in (Get-ChildItem -Path $repo -Recurse -Filter "*.ps1" -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.FullName -notmatch '\\\.git\\' })) {
    $bytes = [System.IO.File]::ReadAllBytes($ps.FullName)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if ($hasBom) { continue }
    if (@($bytes | Where-Object { $_ -gt 127 }).Count -gt 0) {
        $psBad += $ps.FullName.Replace("$repo\", "")
    }
}
if ($psBad.Count -gt 0) {
    Add-Check "FAIL" $cat "PowerShell-Skript ohne BOM, aber mit Nicht-ASCII-Zeichen: $($psBad -join ', '). Unter Windows PowerShell 5.1 (ohne installiertes pwsh) bricht der Parser ab, ohne dass im Alltag eine Meldung erscheint. Behebung: Datei als UTF-8 MIT BOM speichern oder die Umlaute entfernen."
} else {
    Add-Check "OK" $cat "Alle .ps1 sind unter Windows PowerShell 5.1 lesbar (BOM vorhanden oder ASCII-only)."
}

# Gegenrichtung: Die erzeugten Skill-Zeiger duerfen KEINE BOM tragen. Eine BOM vor dem
# "---" macht das Frontmatter fuer den Skill-Loader unlesbar, der Skill zeigt dann als
# Beschreibung nur noch "---". Entstehen kann das, wenn build-skill-wrapper.ps1 mit
# "Set-Content -Encoding UTF8" unter 5.1 laeuft, wo dieser Parameter BOM bedeutet.
# Das Skript schreibt deshalb inzwischen ueber .NET.
$bomZeiger = @()
foreach ($rel in $skillTargets) {
    $dir = Join-Path $repo ($rel -replace '/', '\')
    foreach ($sk in (Get-ChildItem -Path $dir -Recurse -Filter "SKILL.md" -File -ErrorAction SilentlyContinue)) {
        $b = [System.IO.File]::ReadAllBytes($sk.FullName)
        if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) {
            $bomZeiger += $sk.FullName.Replace("$repo\", "")
        }
    }
}
if ($bomZeiger.Count -gt 0) {
    Add-Check "FAIL" $cat "Skill-Zeiger mit BOM vor dem Frontmatter: $($bomZeiger.Count) Datei(en), z.B. $($bomZeiger[0]). Der Skill-Loader liest die Beschreibung dann nicht. Behebung: die betroffenen Dateien loeschen und build-skill-wrapper.ps1 erneut laufen lassen."
} else {
    Add-Check "OK" $cat "Kein Skill-Zeiger traegt eine BOM vor dem Frontmatter."
}

# Arbeitsbereich-Sperre (AGENTS.md Abschnitt 18). Ohne den Hook-Eintrag ist die Regel
# nur Text, und genau das ist der Zustand, den sie ersetzen soll.
$guardSkript = Join-Path $repo "00_INDEX\scripts\guard-workspace.ps1"
$guardSettings = Join-Path $repo ".claude\settings.json"
if (-not (Test-Path $guardSkript)) {
    Add-Check "FAIL" $cat "guard-workspace.ps1 fehlt. Die Arbeitsbereich-Sperre aus AGENTS.md Abschnitt 18 ist damit nicht durchgesetzt."
} elseif (-not (Test-Path $guardSettings)) {
    Add-Check "WARN" $cat "guard-workspace.ps1 vorhanden, aber .claude\settings.json fehlt. In Claude Code ist die Arbeitsbereich-Sperre damit nur eine Textregel."
} elseif ((Get-Content -Path $guardSettings -Raw -Encoding UTF8) -notmatch "guard-workspace") {
    Add-Check "WARN" $cat ".claude\settings.json haengt guard-workspace.ps1 nicht als PreToolUse-Hook ein. Die Sperre wirkt dann nicht."
} else {
    Add-Check "OK" $cat "Arbeitsbereich-Sperre aktiv (guard-workspace.ps1 als PreToolUse-Hook eingehaengt)."
}

Write-Output "Portabilitaets-Checks erledigt."

# ---------------------------------------------------------------------------
# 12) HARNESS-MEMORY (muss leer bleiben: kein zweites Gedaechtnis neben dem Repo)
# ---------------------------------------------------------------------------
# Hintergrund: Manche Harnesses (z.B. Claude Code) fuehren ausserhalb des Repos
# einen eigenen, persistenten Memory-Speicher. Fuer Leo ist der nicht zugelassen
# (Root-AGENTS.md Abschnitt 1, Entscheid 15.07.2026, Technik T17e): Er waere ein
# zweites, nicht portables Gedaechtnis neben den Markdown-Dateien, und er laesst
# sich nicht einmal sichern (der Pfad ist ein Reparse-Point, git kann ihn nicht
# traversieren). Ein Mirror-Schritt ins Repo wurde geprueft und VERWORFEN.
# Richtig ist: Inhalt mit Dauerwert in die zustaendige Repo-Datei migrieren,
# danach die Memory-Datei loeschen. Diese Pruefung meldet deshalb jeden
# Fuellstand groesser 0 als Handlungsbedarf.
$cat = "Harness-Memory"
$memSlug = ($repo -replace ':', '-' -replace '[\\/]', '-')
$memPath = Join-Path $env:USERPROFILE ".claude\projects\$memSlug\memory"
if (-not (Test-Path $memPath)) {
    Add-Check "INFO" $cat "Harness-Memory-Pfad nicht gefunden ($memPath) - evtl. anderes Harness/Benutzer. Keine Aktion."
} else {
    try {
        $memCount = (Get-ChildItem -Path $memPath -File -Recurse -Force -ErrorAction Stop | Measure-Object).Count
        if ($memCount -gt 0) {
            Add-Check "WARN" $cat "Harness-Memory enthaelt $memCount Datei(en) - ein harness-eigener Memory-Speicher ist fuer Leo nicht zugelassen (Root-AGENTS.md Abschnitt 1). Jede Datei lesen, Inhalt mit Dauerwert in die zustaendige Repo-Datei migrieren (Ziele in 01_Basiskontext nur mit Bestaetigung), danach die Memory-Datei loeschen. KEINEN Repo-Mirror bauen (Technik T17e). Pfad: $memPath"
        } else {
            Add-Check "OK" $cat "Harness-Memory leer - kein zweites Gedaechtnis neben dem Repo (Root-AGENTS.md Abschnitt 1)."
        }
    } catch {
        Add-Check "INFO" $cat "Harness-Memory-Pfad nicht lesbar (Reparse-Point: $($_.Exception.Message)) - Fuellstand nicht bestimmbar, spaeter erneut pruefen."
    }
}
Write-Output "Harness-Memory-Check erledigt."
Write-Output ""


# ---------------------------------------------------------------------------
# 13) TOTE LINKS (Wikilinks und Markdown-Links auf .md-Dateien)
# ---------------------------------------------------------------------------
# Hintergrund: Seit 26.07.2026 sind Querverweise zwischen Wissensdateien echte
# Obsidian-Links statt Pfadnennungen in Backticks (Root-AGENTS.md Abschnitt 5,
# Entscheid E22). Der Nutzen dieser Umstellung haengt daran, dass die Links auch
# stimmen: Ein toter Verweis kostet das LLM eine Fehlsuche und ist im Fliesstext
# unsichtbar. Beim Umstellungslauf waren 26 der bestehenden Pfadnennungen bereits
# verrottet (umbenannte, versionierte oder geloeschte Ziele). Diese Pruefung
# faengt genau das mechanisch ab.
#
# Aufloesung wie in Obsidian: exakter vault-relativer Pfad ODER eindeutiger
# Dateiname. Reine Abschnittslinks ([[#Ueberschrift]]) werden uebersprungen,
# ebenso alles in Code-Bloecken und Inline-Code (dort stehen Beispiele, keine
# echten Verweise).
$cat = "Links"
$mdAll = Get-ChildItem -Path $repo -Recurse -File -Filter "*.md" |
    Where-Object { $_.FullName -notmatch $excludedDirPattern }

$relByLower = @{}
$byBase = @{}
foreach ($f in $mdAll) {
    $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
    $relByLower[$rel.ToLower()] = $rel
    $bn = $f.Name.ToLower()
    if (-not $byBase.ContainsKey($bn)) { $byBase[$bn] = New-Object System.Collections.Generic.List[string] }
    $byBase[$bn].Add($rel)
}

$deadLinks = New-Object System.Collections.Generic.List[string]
$linkCount = 0
foreach ($f in $mdAll) {
    $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
    $raw = Get-Content -Path $f.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $raw) { continue }
    # Code-Bloecke und Inline-Code entfernen, damit Beispiele nicht als Verweis zaehlen.
    $txt = [regex]::Replace($raw, '(?s)```.*?```', '')
    $txt = [regex]::Replace($txt, '`[^`\r\n]*`', '')

    foreach ($m in [regex]::Matches($txt, '\[\[([^\]]+)\]\]')) {
        $target = ($m.Groups[1].Value -split '\|')[0]
        $target = ($target -split '#')[0].Trim()
        if ([string]::IsNullOrWhiteSpace($target)) { continue }   # reiner Abschnittslink
        $linkCount++
        $probe = ($target + '.md').ToLower()
        if ($relByLower.ContainsKey($probe)) { continue }
        $bn = (Split-Path $probe -Leaf)
        if ($byBase.ContainsKey($bn) -and $byBase[$bn].Count -eq 1) { continue }
        $deadLinks.Add("$rel -> [[$target]]")
    }

    foreach ($m in [regex]::Matches($txt, '\]\(([^)]+\.md)\)')) {
        $t = $m.Groups[1].Value
        if ($t -match '^(https?|mailto):') { continue }
        $linkCount++
        $t = [uri]::UnescapeDataString(($t -split '#')[0])
        $combined = Join-Path (Split-Path $f.FullName -Parent) ($t -replace '/', '\')
        $norm = try { [System.IO.Path]::GetFullPath($combined) } catch { $null }
        if ($norm -and (Test-Path -LiteralPath $norm)) { continue }
        if ($relByLower.ContainsKey($t.ToLower() -replace '\\', '/')) { continue }
        $deadLinks.Add("$rel -> ($t)")
    }
}

if ($deadLinks.Count -gt 0) {
    $sample = ($deadLinks | Select-Object -First 10) -join ' | '
    Add-Check "WARN" $cat "$($deadLinks.Count) tote(r) Verweis(e) von $linkCount geprueften Links. Ziel umbenannt, versioniert oder geloescht - Verweis nachziehen oder entfernen, nicht stehen lassen. Erste Treffer: $sample"
} else {
    Add-Check "OK" $cat "Alle $linkCount Verweise (Wikilinks und Markdown-Links auf .md) loesen auf eine real existierende Datei auf."
}
Write-Output "Link-Check erledigt."
Write-Output ""


# ---------------------------------------------------------------------------
# 14) FRONTMATTER-STANDARD FUER NEUE DATEIEN
# ---------------------------------------------------------------------------
# Hintergrund: NEU angelegte Dateien sollen zuverlaessig und einheitlich Frontmatter
# tragen (Root-AGENTS.md Abschnitt 5). Geprueft werden nur Dateien, die laut Git AM
# oder NACH dem Stichtag unten erstmals hinzugefuegt wurden.
# Stichtag: In einem frisch aufgesetzten Repo gibt es keinen Altbestand, deshalb steht
# er hier auf 1970 und die Pflicht gilt fuer alles. Hast du spaeter Dateien ohne
# Frontmatter, die bewusst so bleiben sollen (Bestandsschutz), setzt du hier das Datum
# ein, ab dem die Regel greifen soll, z.B. ParseExact("2027-01-01", ...).
$cat = "Frontmatter"
$fmCutoff = [datetime]::ParseExact("1970-01-01", "yyyy-MM-dd", $null)
$fmRequired = @("titel", "zweck", "type")
$fmAllowedTypes = @("wissensnotiz", "rohquelle", "synthese", "arbeitsdokument",
                    "rollen-regeln", "themen-index", "readme", "basiskontext", "systemdoku",
                    "master-regeln")
# Ausgenommen: Dateiklassen mit eigenem, in sich einheitlichem Schema, das ein Skill
# fest vorgibt (Skills: name/trigger/zweck/type; Sessionlogs: date/time/topic/context/
# tags/type; Indexdateien: vom Generator erzeugt). Diese Regel hier gilt fuer
# Wissensdateien, nicht fuer generierte oder schablonierte Systemdateien, sonst wuerde
# der Check jeden neuen Sessionlog und jeden neuen Skill anmeckern, obwohl beide ihrem
# eigenen Standard exakt folgen.
$fmExemptPrefix = @("02_Skills/", "03_Sessionlogs/", "00_INDEX/", "04_Changelog/")
$fmExemptNames  = @("AGENTS.md", "CLAUDE.md", "GEMINI.md", "_INDEX.md", "README.md")
# Anlagedatum je Datei in EINEM git-Aufruf bestimmen (pro Datei waere es ~250 Aufrufe).
$addDates = @{}
$logOut = & git -C $repo log --diff-filter=A --date=format:%Y-%m-%d --format="D:%ad" --name-only -- "*.md" 2>$null
if ($LASTEXITCODE -eq 0) {
    $curDate = $null
    foreach ($line in @($logOut)) {
        $l = "$line".Trim()
        if ($l -match '^D:(\d{4}-\d{2}-\d{2})$') { $curDate = $matches[1]; continue }
        if ($l -eq "" -or -not $curDate) { continue }
        # git log laeuft von neu nach alt, das Ueberschreiben laesst am Ende den AELTESTEN
        # Add stehen. Genau der ist gewollt: das echte Anlagedatum, nicht ein spaeterer
        # Re-Add nach einer Umbenennung.
        $addDates[$l] = $curDate
    }
}
$fmIssues = @()
foreach ($f in $mdAll) {
    $rel = $f.FullName.Substring($repo.Length + 1) -replace '\\', '/'
    if (-not $addDates.ContainsKey($rel)) { continue }   # noch nie committet: erst nach dem Commit pruefbar
    $added = [datetime]::ParseExact($addDates[$rel], "yyyy-MM-dd", $null)
    if ($added -lt $fmCutoff) { continue }               # Bestandsschutz
    if ($fmExemptNames -contains $f.Name) { continue }
    $isExempt = $false
    foreach ($p in $fmExemptPrefix) { if ($rel.StartsWith($p)) { $isExempt = $true; break } }
    if ($isExempt) { continue }
    $head = Get-Content -Path $f.FullName -TotalCount 25 -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $head -or $head[0].Trim() -ne "---") {
        $fmIssues += "$rel (kein Frontmatter)"
        continue
    }
    $keys = @()
    $typeVal = $null
    for ($i = 1; $i -lt $head.Count; $i++) {
        if ($head[$i].Trim() -eq "---") { break }
        if ($head[$i] -match '^([a-zA-Z_]+):\s*(.*)$') {
            $keys += $matches[1]
            if ($matches[1] -eq "type") { $typeVal = $matches[2].Trim().Trim('"') }
        }
    }
    $missing = @($fmRequired | Where-Object { $keys -notcontains $_ })
    if ($missing.Count -gt 0) { $fmIssues += "$rel (fehlt: $($missing -join ', '))" }
    elseif ($typeVal -and ($fmAllowedTypes -notcontains $typeVal)) {
        $fmIssues += "$rel (type '$typeVal' nicht in der Liste aus AGENTS.md Abschnitt 5)"
    }
}
if ($fmIssues.Count -gt 0) {
    Add-Check "WARN" $cat "$($fmIssues.Count) Datei(en) erfuellen den Frontmatter-Standard nicht: $($fmIssues -join ' | ')"
} else {
    Add-Check "OK" $cat "Alle seit dem Stichtag angelegten Dateien tragen titel, zweck und einen zulaessigen type."
}
Write-Output "Frontmatter-Check erledigt."
Write-Output ""


# ---------------------------------------------------------------------------
# BERICHT
# ---------------------------------------------------------------------------
Write-Output "=== Ergebnis ==="
foreach ($r in $results) {
    Write-Output "[$($r.Level)] [$($r.Category)] $($r.Message)"
}
Write-Output ""

$okC = ($results | Where-Object Level -eq "OK").Count
$infoC = ($results | Where-Object Level -eq "INFO").Count
$warnC = ($results | Where-Object Level -eq "WARN").Count
$failC = ($results | Where-Object Level -eq "FAIL").Count

Write-Output "Zusammenfassung: $okC OK, $infoC INFO, $warnC WARN, $failC FAIL"

if ($failC -gt 0) {
    Write-Output "VERDIKT: SYSTEM NICHT EINSATZBEREIT - $failC kritische(s) Problem(e) beheben."
    exit 2
} elseif ($warnC -gt 0) {
    Write-Output "VERDIKT: SYSTEM EINSATZBEREIT MIT HINWEISEN - $warnC Punkt(e) pruefen/beheben."
    exit 1
} else {
    Write-Output "VERDIKT: SYSTEM VOLLSTAENDIG GESUND."
    exit 0
}
