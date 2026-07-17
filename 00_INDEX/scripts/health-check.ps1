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
$excludedDirPattern = '\\\.(git|obsidian|claude)\\'

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
# Mit Florian explizit abgestimmte Dauer-Ausnahmen (2026-07-07): zu gross/zu viele
# Einzeldateien fuer sinnvolle Einzelbeschreibungen. Format: "Themenordner/relativer Pfad"
# oder "Themenordner/Unterordner/*" als Wildcard fuer einen ganzen Unterordner.
$knownCoverageExclusions = @(
    "21_Buch/Manuskript-DER-SAVANT-Band-1-Toedliche-Gabe.md",
    "21_Buch/Archiv Sessions mit KI/*"
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
# Befund 2026-07-17: Der Eintrag zu "Florian Persoenlichkeit und Muster.md" trug
# nach einer Umlaut-Korrektur den Dateinamen mit "oe" -> "ö", ohne dass die Datei
# selbst umbenannt wurde. Sammeleintraege ("...") matcht die Regex nicht.
$orphanedRoot = @($describedInRoot | Where-Object { -not (Test-Path (Join-Path $repo $_)) })
if ($orphanedRoot.Count -gt 0) {
    Add-Check "FAIL" $cat "$($orphanedRoot.Count) kuratierte Beschreibung(en) in 00_INDEX\INDEX.md verweisen auf nicht existierende Dateien: $($orphanedRoot -join ', ')"
} else {
    Add-Check "OK" $cat "Alle kuratierten Beschreibungen in 00_INDEX\INDEX.md verweisen auf real existierende Dateien."
}
Write-Output "Index-Abdeckungs-Checks erledigt."

# ---------------------------------------------------------------------------
# 6) VERALTETE "stand:"-DATEN (> 60 Tage)
# ---------------------------------------------------------------------------
$cat = "Aktualitaet"
$staleFiles = @()
$driftFiles = @()
Get-ChildItem -Path $repo -Recurse -Filter "*.md" -File | Where-Object { $_.Name -ne "_INDEX.md" -and $_.FullName -notmatch $excludedDirPattern } | ForEach-Object {
    $m = Select-String -Path $_.FullName -Pattern '^stand:\s*(\d{4}-\d{2}-\d{2})' -List -ErrorAction SilentlyContinue
    if ($m) {
        $standStr = $m.Matches[0].Groups[1].Value
        $d = [datetime]::ParseExact($standStr, "yyyy-MM-dd", $null)
        $age = (New-TimeSpan -Start $d -End (Get-Date)).Days
        if ($age -gt 60) {
            $staleFiles += "$($_.FullName.Substring($repo.Length + 1)) (Stand $standStr, $age Tage alt)"
        }
        # 6b) Drift: Datei wurde laut Git DEUTLICH nach dem eingetragenen stand:
        # geaendert (> 7 Tage) - stand: wurde beim Bearbeiten nicht nachgefuehrt.
        $gitDateRaw = & git -C $repo log -1 --format=%ad --date=format:%Y-%m-%d -- "$($_.FullName)" 2>$null
        if ($LASTEXITCODE -eq 0 -and "$gitDateRaw" -match '^\d{4}-\d{2}-\d{2}$') {
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
    Add-Check "OK" $cat "Keine 'stand:'-Datumsangabe aelter als 60 Tage."
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
$dynamicDirPattern = '\\21_Buch\\Arbeitsdokumente Band 2\\'
# Mit Florian abgestimmte Ausnahmen: dynamisch klingender Name/Inhalt/Ort, aber statisch.
$knownStaticExceptions = @(
    "21_Buch/Arbeitsdokumente Band 2/Flo Voice and Style.md",
    "21_Buch/Arbeitsdokumente Band 2/Referenz_Savant_und_NDE.md",
    "22_Gesundheit/Prophylaxe/2026-04-08_Briefing_Strategien-Herz-Kreislauf-Praevention-Langlebigkeit.md"
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
$inboxFiles = Get-ChildItem -Path (Join-Path $repo "90_Inbox") -File -Filter "*.md" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "README.md" }
if ($inboxFiles.Count -gt 0) {
    Add-Check "WARN" $cat "$($inboxFiles.Count) unsortierte Datei(en) in 90_Inbox: $($inboxFiles.Name -join ', ') - wird im Skill 'leo-system-health-check' (Schritt Inbox) behandelt."
} else {
    Add-Check "OK" $cat "90_Inbox leer (bis auf README.md)."
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
foreach ($f in @("CLAUDE.md", "GEMINI.md", ".clinerules")) {
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
# Body-Vergleich ohne die erste Zeile (Titel "# CLAUDE.md" / "# GEMINI.md" darf sich
# legitim unterscheiden, der Rest sollte identisch sein) und ohne Zeilenumbruch-Rauschen.
$claudeBody = (Get-Content -Path (Join-Path $repo "CLAUDE.md") -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -Skip 1) -join "`n"
$geminiBody = (Get-Content -Path (Join-Path $repo "GEMINI.md") -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -Skip 1) -join "`n"
if ($claudeBody -and $geminiBody -and $claudeBody -ne $geminiBody) {
    Add-Check "WARN" $cat "CLAUDE.md und GEMINI.md unterscheiden sich inhaltlich (ausser der Titelzeile) - sollten identische Weiterleitungs-Vorlagen sein."
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
