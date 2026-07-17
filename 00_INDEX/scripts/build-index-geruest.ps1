# build-index-geruest.ps1 (Version 2)
# Zweck: Haelt alle MECHANISCHEN Index-Anteile aktuell. Kein LLM, keine Halluzination.
# Listet nur real existierende Dateien; Geloeschtes faellt automatisch raus.
#
# Das Skript macht drei Dinge:
# 1) INDEX-Geruest.md neu erzeugen: vollstaendige, deterministische Baumliste aller .md-Dateien
#    (volle Hierarchie, alle Ebenen), mit Basis-Beschreibung, Groesse, Aenderungsdatum.
# 2) 00_INDEX\INDEX.md: aktualisiert den Auto-Block "BAUM" (Ordnerbaum mit Dateizahlen).
# 3) Je Themenordner (Ordner mit lokaler AGENTS.md/Rolle, numerischer Praefix >= 20 -
#    siehe Test-IsThemenordner; NICHT auf "2X" begrenzt, 30_, 31_, ... zaehlen genauso):
#    legt _INDEX.md an, falls fehlend; aktualisiert den Auto-Block "DATEILISTE"; entfernt
#    kuratierte Beschreibungs-Eintraege zu nicht mehr existierenden Dateien.
#
# Auto-Bloecke sind durch Marker begrenzt (<!-- AUTO:NAME:BEGIN --> / <!-- AUTO:NAME:END -->).
# Alles zwischen den Markern gehoert dem Skript. Nie von Hand aendern.
#
# Aufruf: pwsh -NoProfile -ExecutionPolicy Bypass -File "<REPO>\00_INDEX\scripts\build-index-geruest.ps1"
# Der Repo-Root wird automatisch aus dem Skript-Speicherort ($PSScriptRoot) abgeleitet.
# Das Skript ist dadurch verschiebbar: kein hartcodierter Pfad, funktioniert an jedem Ort.

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
# .claude ist Harness-Territorium, kein Wissen: Konfiguration und vor allem
# .claude\worktrees\ (vollstaendige Zweitkopien des Repos aus Parallel-Sessions).
# Git ignoriert diese Kopien via .git\info\exclude, das Skript laeuft aber ueber
# das Dateisystem und wuerde sie sonst mitindexieren (jede Datei doppelt).
$excludeDirs = @(".git", ".obsidian", ".claude")
$metaNames = @("INDEX.md", "INDEX-Geruest.md", "_INDEX.md")
$now = Get-Date -Format "yyyy-MM-dd HH:mm"

# --- Hilfsfunktionen ---------------------------------------------------------

function Get-BasisDesc([string]$filePath) {
    # Erste Ueberschrift (# ...) oder erste inhaltliche Zeile als Basis-Beschreibung.
    $desc = ""
    $content = Get-Content -Path $filePath -Encoding UTF8 -ErrorAction SilentlyContinue
    foreach ($line in $content) {
        $trim = $line.Trim()
        if ($trim -match "^#\s+(.+)$") { return $matches[1].Trim() }
        if ($desc -eq "" -and $trim -ne "" -and $trim -notmatch "^---$" -and $trim -notmatch "^(titel|zweck|type|version|name|trigger|date|time|topic|context|tags|stand|hinweis|erzeugt|letzte_aenderung):") {
            $desc = $trim
        }
    }
    if ($desc -eq "") { $desc = "(keine Beschreibung gefunden)" }
    return $desc
}

function Add-FileTree {
    # Haengt einen Baum (Dateien + Unterordner, rekursiv) an $out an.
    param([string]$dirPath, [int]$depth, [System.Collections.Generic.List[string]]$out, [bool]$withMeta)
    $indent = "  " * $depth
    $files = Get-ChildItem -Path $dirPath -File -Filter "*.md" | Where-Object { $metaNames -notcontains $_.Name } | Sort-Object Name
    foreach ($f in $files) {
        if ($withMeta) {
            $desc = Get-BasisDesc $f.FullName
            $kb = [math]::Round($f.Length / 1KB, 1)
            $dat = $f.LastWriteTime.ToString("yyyy-MM-dd")
            $out.Add("$indent- $($f.Name) | $desc | $kb KB | $dat")
        } else {
            $out.Add("$indent- $($f.Name)")
        }
    }
    $dirs = Get-ChildItem -Path $dirPath -Directory | Where-Object { $excludeDirs -notcontains $_.Name } | Sort-Object Name
    foreach ($d in $dirs) {
        $out.Add("$indent- $($d.Name)\")
        Add-FileTree -dirPath $d.FullName -depth ($depth + 1) -out $out -withMeta $withMeta
    }
}

function Add-DirTree {
    # Haengt einen reinen Ordnerbaum (mit Anzahl .md-Dateien je Ordner, rekursiv gezaehlt) an $out an.
    param([string]$dirPath, [int]$depth, [System.Collections.Generic.List[string]]$out)
    $dirs = Get-ChildItem -Path $dirPath -Directory | Where-Object { $excludeDirs -notcontains $_.Name } | Sort-Object Name
    foreach ($d in $dirs) {
        $count = @(Get-ChildItem -Path $d.FullName -Recurse -File -Filter "*.md" | Where-Object { $metaNames -notcontains $_.Name }).Count
        $indent = "  " * $depth
        $out.Add("$indent- $($d.Name)\  ($count Dateien)")
        Add-DirTree -dirPath $d.FullName -depth ($depth + 1) -out $out
    }
}

function Set-AutoBlock([string]$file, [string]$blockName, [string[]]$bodyLines) {
    # Ersetzt den Inhalt zwischen den Markern des benannten Auto-Blocks. Rein mechanisch.
    if (-not (Test-Path $file)) { Write-Output "WARNUNG: $file fehlt, Auto-Block $blockName nicht aktualisiert."; return }
    $begin = "<!-- AUTO:{0}:BEGIN -->" -f $blockName
    $end = "<!-- AUTO:{0}:END -->" -f $blockName
    $text = Get-Content -Path $file -Raw -Encoding UTF8
    $i = $text.IndexOf($begin)
    $j = $text.IndexOf($end)
    if ($i -lt 0 -or $j -lt $i) { Write-Output "WARNUNG: Marker AUTO:$blockName fehlen in $file."; return }
    $body = ($bodyLines -join "`r`n")
    $newText = $text.Substring(0, $i + $begin.Length) + "`r`n" + $body + "`r`n" + $text.Substring($j)
    # -NoNewline ist Pflicht: $newText enthaelt ueber $text.Substring($j) bereits das
    # originale Dateiende samt Zeilenumbruch. Ohne -NoNewline haengt Set-Content bei
    # JEDEM Lauf eine weitere Leerzeile an (taeglicher Scheduler = taegliches Wachstum
    # und eine sinnlose Aenderung im Commit).
    Set-Content -Path $file -Value $newText -Encoding UTF8 -NoNewline
}

# --- 1) INDEX-Geruest.md -----------------------------------------------------

$allFiles = @(Get-ChildItem -Path $repo -Recurse -File -Filter "*.md" |
    Where-Object { $_.FullName -notmatch "\\\.(git|obsidian|claude)\\" -and $metaNames -notcontains $_.Name })

$g = New-Object System.Collections.Generic.List[string]
$g.Add("---")
$g.Add("titel: Index-Geruest (mechanisch erzeugt)")
$g.Add("zweck: Vollstaendige, deterministische Baumliste aller Markdown-Dateien im Repo")
$g.Add("type: index-geruest")
$g.Add("erzeugt: $now")
$g.Add("hinweis: Automatisch erzeugt. Nicht von Hand bearbeiten. Sicherheitsnetz und Delta-Quelle fuer die kuratierten Indizes.")
$g.Add("---")
$g.Add("")
$g.Add("# Index-Geruest")
$g.Add("")
$g.Add("Mechanisch aus dem Dateisystem erzeugt am $now. Volle Hierarchie, jede real existierende .md-Datei.")
$g.Add("Format je Datei: Name | Basis-Beschreibung (erste Ueberschrift) | Groesse | geaendert.")
$g.Add("")
Add-FileTree -dirPath $repo -depth 0 -out $g -withMeta $true
$g.Add("")
$g.Add("---")
$g.Add("Ende des Geruests. Anzahl Dateien: $($allFiles.Count)")

$geruestFile = Join-Path $repo "00_INDEX\INDEX-Geruest.md"
($g -join "`r`n") | Set-Content -Path $geruestFile -Encoding UTF8
Write-Output "Index-Geruest geschrieben: $geruestFile ($($allFiles.Count) Dateien)"

# --- 2) Ordnerbaum in INDEX.md -----------------------------------------------

$tree = New-Object System.Collections.Generic.List[string]
$tree.Add("Stand: $now (mechanisch aktualisiert, Anzahl = .md-Dateien inkl. Unterordner)")
$tree.Add("")
Add-DirTree -dirPath $repo -depth 0 -out $tree
Set-AutoBlock -file (Join-Path $repo "00_INDEX\INDEX.md") -blockName "BAUM" -bodyLines $tree
Write-Output "Ordnerbaum in INDEX.md aktualisiert."

# --- 2b) Rollen-Tabelle in AGENTS.md und Themenbereiche in INDEX.md -----------
# Quelle der Wahrheit fuer die Rolle ist die lokale AGENTS.md des Ordners
# (Zeile "# Rolle: ..."). Tabelle und Bereichsliste werden daraus mechanisch erzeugt.

function Get-Rolle([string]$agentsFile) {
    $c = Get-Content -Path $agentsFile -Encoding UTF8 -ErrorAction SilentlyContinue
    foreach ($line in $c) {
        if ($line -match "^#\s+Rolle:\s*(.+)$") { return $matches[1].Trim() }
    }
    return "(Rolle fehlt: Zeile '# Rolle: ...' in der lokalen AGENTS.md ergaenzen)"
}

function Test-IsThemenordner([System.IO.DirectoryInfo]$dir) {
    # Themenordner = Ordner mit eigener Rolle (lokale AGENTS.md, "# Rolle: ..."), dessen
    # numerischer Praefix >= 20 ist. Bewusst NICHT hart auf "2X" begrenzt: 30_, 31_, ...
    # zaehlen genauso, damit neue Themenbereiche jenseits von 29 automatisch als
    # Themenordner erkannt werden (eigene _INDEX.md, Eintrag in INDEX.md BEREICHE).
    # Ordner mit Praefix < 20 (00_INDEX, 01_Basiskontext, 02_Skills, 03_Sessionlogs,
    # 04_Changelog, 10_System, ...) sind Systemordner und werden hier ausgeschlossen.
    if ($dir.Name -notmatch "^(\d+)_") { return $false }
    return [int]$matches[1] -ge 20
}

$roleDirs = Get-ChildItem -Path $repo -Directory | Where-Object { Test-Path (Join-Path $_.FullName "AGENTS.md") } | Sort-Object Name

$rollen = New-Object System.Collections.Generic.List[string]
$rollen.Add("| Ordner | Rolle |")
$rollen.Add("|---|---|")
foreach ($d in $roleDirs) {
    $rolle = Get-Rolle (Join-Path $d.FullName "AGENTS.md")
    $rollen.Add("| $($d.Name) | $rolle |")
}
Set-AutoBlock -file (Join-Path $repo "AGENTS.md") -blockName "ROLLEN" -bodyLines $rollen
Write-Output "Rollen-Tabelle in AGENTS.md aktualisiert ($($roleDirs.Count) Ordner)."

$bereiche = New-Object System.Collections.Generic.List[string]
foreach ($d in ($roleDirs | Where-Object { Test-IsThemenordner $_ })) {
    $rolle = Get-Rolle (Join-Path $d.FullName "AGENTS.md")
    $bereiche.Add("- **$($d.Name)** | Rolle: $rolle | Regeln: $($d.Name)\AGENTS.md | Datei-Beschreibungen stehen NICHT hier, sondern in -> $($d.Name)\_INDEX.md (IMMER dort lesen)")
}
Set-AutoBlock -file (Join-Path $repo "00_INDEX\INDEX.md") -blockName "BEREICHE" -bodyLines $bereiche
Write-Output "Themenbereiche in INDEX.md aktualisiert."

# --- 3) Lokale _INDEX.md je Themenordner --------------------------------------

$themeDirs = $roleDirs | Where-Object { Test-IsThemenordner $_ } | Sort-Object Name
foreach ($t in $themeDirs) {
    $idx = Join-Path $t.FullName "_INDEX.md"

    # 3a) Anlegen, falls fehlend (Template)
    if (-not (Test-Path $idx)) {
        $tpl = @(
            "---",
            "titel: Lokaler Index $($t.Name)",
            "type: themen-index",
            "hinweis: Dateiliste mechanisch (Skript), Beschreibungen kuratiert (LLM). Auto-Bloecke nicht von Hand aendern.",
            "---",
            "",
            "# Lokaler Index: $($t.Name)",
            "",
            "Beschreibt die Wissensdateien in diesem Ordner. Erst die Dateiliste pruefen (immer aktuell), dann die kuratierten Beschreibungen nutzen. Fehlt eine Beschreibung, gilt die Basis-Beschreibung aus der Dateiliste.",
            "",
            "## Dateiliste (mechanisch aktuell)",
            "<!-- AUTO:DATEILISTE:BEGIN -->",
            "<!-- AUTO:DATEILISTE:END -->",
            "",
            "## Beschreibungen (kuratiert)",
            'Format je Eintrag: "- **Relativpfad** - Beschreibung". Eintraege zu geloeschten Dateien entfernt das Skript automatisch.',
            ""
        )
        ($tpl -join "`r`n") | Set-Content -Path $idx -Encoding UTF8
        Write-Output "Neu angelegt: $idx"
    }

    # 3b) Dateiliste aktualisieren
    $list = New-Object System.Collections.Generic.List[string]
    $list.Add("Stand: $now")
    $list.Add("")
    Add-FileTree -dirPath $t.FullName -depth 0 -out $list -withMeta $true
    Set-AutoBlock -file $idx -blockName "DATEILISTE" -bodyLines $list

    # 3c) Kuratierte Eintraege zu geloeschten Dateien entfernen (rein loeschend, nie erzeugend)
    $linesIdx = Get-Content -Path $idx -Encoding UTF8
    $result = New-Object System.Collections.Generic.List[string]
    $inCurated = $false
    $skipContinuation = $false
    $removed = @()
    foreach ($ln in $linesIdx) {
        if ($ln -match "^## Beschreibungen") { $inCurated = $true; $skipContinuation = $false; $result.Add($ln); continue }
        elseif ($ln -match "^## ") { $inCurated = $false; $skipContinuation = $false }
        if ($inCurated -and $ln -match "^- \*\*(.+?)\*\*") {
            $relp = $matches[1]
            if (Test-Path (Join-Path $t.FullName $relp)) { $skipContinuation = $false; $result.Add($ln) }
            else { $skipContinuation = $true; $removed += $relp }
            continue
        }
        if ($inCurated -and $skipContinuation) {
            if ($ln -match "^\s+\S") { continue } else { $skipContinuation = $false }
        }
        $result.Add($ln)
    }
    if ($removed.Count -gt 0) {
        ($result -join "`r`n") | Set-Content -Path $idx -Encoding UTF8
        Write-Output "Bereinigt in $($t.Name)\_INDEX.md (Datei existiert nicht mehr): $($removed -join ', ')"
    }
    Write-Output "Lokaler Index aktualisiert: $idx"
}

Write-Output "Fertig. $now"
