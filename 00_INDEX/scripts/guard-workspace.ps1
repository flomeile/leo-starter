# guard-workspace.ps1
# Zweck: PreToolUse-Hook. Blockiert jeden SCHREIBENDEN Zugriff ausserhalb des Repos.
#
# WARUM ES DAS GIBT:
# Der Agent arbeitet an einem Second Brain, nicht am Dateisystem. Alles, was er
# veraendert, gehoert ins Repo, weil dort Git jede Aenderung rueckrollbar macht.
# Ausserhalb gibt es dieses Netz nicht: eine falsch geratene Pfadangabe, ein
# uebereifriges "ich raeume das gleich mit auf", ein Tippfehler im Zielpfad, und
# es trifft Dateien, die niemand versioniert hat. Eine Textregel allein reicht
# dafuer nicht, die kann ein LLM uebersehen. Dieser Hook laeuft vor dem
# Werkzeugaufruf und entscheidet ohne das Modell. Die Regel selbst steht in der
# AGENTS.md, Abschnitt 18; dieses Skript ist nur ihre Durchsetzung.
#
# WAS ER NICHT TUT: Lesen bleibt frei. Der Schaden entsteht beim Veraendern, und
# ein Diagnoseblick in eine fremde Datei soll keine Rueckfrage kosten.
#
# GRENZE, DIE MAN KENNEN MUSS: Dieser Hook liegt IM Repo, weil dort das ganze
# System liegt (AGENTS.md Abschnitt 11: kein Systembestandteil ausserhalb).
# Ein Agent mit Schreibrecht auf das Repo koennte ihn also selbst entschaerfen.
# Genau das verbietet AGENTS.md Abschnitt 18 ausdruecklich: Die Ausnahmeliste
# unten zu erweitern, um an ein blockiertes Ziel zu kommen, ist die Umgehung der
# Regel und nicht ihre Anwendung.
#
# EINRICHTUNG: Der Hook wirkt nur, wenn er in .claude\settings.json unter
# hooks.PreToolUse eingehaengt ist. Die Datei liegt im Paket bei. Ohne sie ist
# Abschnitt 18 eine reine Textregel.
#
# ANPASSEN: Brauchst du dauerhaft einen weiteren Ort ausserhalb des Repos, traegst
# DU ihn unten in $allowPatterns ein, nicht der Agent nebenbei.
#
# Eingabe: JSON auf stdin. Ausgabe: JSON auf stdout NUR beim Blockieren.
#
# Bewusst ASCII-only geschrieben und trotzdem mit BOM gespeichert: Dieses Skript
# laeuft bei jedem einzelnen Werkzeugaufruf und muss unter Windows PowerShell 5.1
# genauso starten wie unter PowerShell 7.

$ErrorActionPreference = "Stop"

# WICHTIG: Im Durchlass-Fall gibt dieser Hook NICHTS aus und beendet sich nur mit
# Exitcode 0. Die Hook-Dokumentation kennt zwar einen Rueckgabewert "defer" fuer
# "keine Entscheidung, normaler Berechtigungsweg", aber Claude Code hat damit
# jeden folgenden Werkzeugaufruf mit einem internen Fehler abgebrochen, statt ihn
# auszufuehren. Die Sitzung war danach arbeitsunfaehig und musste ueber
# "git checkout -- .claude/settings.json" von Hand befreit werden. Ein stiller
# Exitcode 0 ist der dokumentierte konservative Weg und bedeutet dasselbe.
function Write-Decision([string]$decision, [string]$reason) {
    if ($decision -ne "deny") { exit 0 }
    $out = @{
        hookSpecificOutput = @{
            hookEventName            = "PreToolUse"
            permissionDecision       = "deny"
            permissionDecisionReason = $reason
        }
    }
    $out | ConvertTo-Json -Depth 5 -Compress
    exit 0
}

# Faellt hier etwas aus, darf der Hook den Betrieb nicht blockieren: Eine Sperre,
# die bei einem eigenen Fehler alles anhaelt, ist gefaehrlicher als die Luecke,
# die sie schliesst.
try {

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { Write-Decision "durch" "Keine Eingabe erhalten." }
$in = $raw | ConvertFrom-Json

$repo = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
# Der Artefakte-Ordner ist der Geschwisterordner "<Repo> Artifacts". Join-Path statt
# Zeichenkette, weil ein Repo direkt auf einem Laufwerk sonst einen doppelten
# Trenner ergibt: Split-Path liefert dort "C:\" samt Trennzeichen.
$artifacts = (Join-Path (Split-Path -Parent $repo) ((Split-Path -Leaf $repo) + " Artifacts")).TrimEnd('\')

# --- Erlaubte Bereiche ------------------------------------------------------
# Das Repo selbst, dazu drei Ausnahmen, die je einen Ablauf betreffen, der ohne
# sie bricht. Die Muster enden bewusst auf "\*" statt auf "*": sonst wuerde ein
# Muster wie "C:\Leo*" auch "C:\Leonardo" mit erlauben.
$allowPatterns = @(
    $repo                                          # das Repo selbst
    "$repo\*"                                      # alles darin
    $artifacts                                     # erzeugte Artefakte (Abschnitt 5)
    "$artifacts\*"
    "$([System.IO.Path]::GetTempPath())claude\*"   # Scratchpad des Werkzeugs
    "$env:TEMP\claude\*"                           # dasselbe, andere Schreibweise
    "$env:USERPROFILE\.claude\projects\*\memory"   # nur um Harness-Memory zu LOESCHEN
    "$env:USERPROFILE\.claude\projects\*\memory\*"
)

function Test-Allowed([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $true }
    $p = $path.Trim().Trim('"').Trim("'")
    # Git-Bash-Schreibweise /c/Repo/... auf C:\Repo\... normalisieren
    if ($p -match '^/([a-zA-Z])/(.*)$') { $p = $matches[1].ToUpper() + ":\" + ($matches[2] -replace '/', '\') }
    $p = $p -replace '/', '\'
    # Relative Pfade werden hier nicht bewertet, dafuer zaehlt das Arbeitsverzeichnis.
    if ($p -notmatch '^[a-zA-Z]:\\' -and $p -notmatch '^\\\\') { return $true }
    try { $p = [System.IO.Path]::GetFullPath($p) } catch { }
    $p = $p.TrimEnd('\')
    foreach ($pat in $allowPatterns) {
        if ($p -like $pat) { return $true }
    }
    return $false
}

$tool = [string]$in.tool_name
$ti   = $in.tool_input

# --- 1) Dateiwerkzeuge: der Zielpfad steht direkt im Aufruf -------------------
if ($tool -in @("Write", "Edit", "NotebookEdit", "MultiEdit")) {
    $target = [string]$ti.file_path
    if (-not (Test-Allowed $target)) {
        Write-Decision "deny" "Ausserhalb des Repos ($repo) wird nichts geschrieben. Blockierter Pfad: $target. Das ist eine harte Regel, siehe AGENTS.md Abschnitt 18. Frag [NAME] um Erlaubnis, statt den Weg zu umgehen."
    }
    Write-Decision "durch" ""
}

# --- 2) Shell: Pfade aus dem Kommandotext lesen -------------------------------
if ($tool -in @("Bash", "PowerShell")) {
    $cmd = [string]$ti.command
    if ([string]::IsNullOrWhiteSpace($cmd)) { Write-Decision "durch" "" }

    # Geprueft werden nur schreibende Kommandos. Lesen ausserhalb ist erlaubt, und
    # ein Hook, der jede Suche blockiert, fuehrt nur dazu, dass die Sperre
    # irgendwann abgeschaltet wird.
    $writeVerbs = @(
        'Set-Content','Add-Content','Out-File','New-Item','Remove-Item','Move-Item','Copy-Item',
        'Rename-Item','Clear-Content','Set-ItemProperty','New-ItemProperty','Remove-ItemProperty',
        'Export-Csv','Export-Clixml','Start-Process','Invoke-WebRequest.*-OutFile',
        'WriteAllText','WriteAllBytes','WriteAllLines','AppendAllText',
        '\bmkdir\b','\brmdir\b','\brm\b','\bmv\b','\bcp\b','\btouch\b','\btee\b','\bdel\b','\berase\b',
        '\bgit\s+(add|commit|push|checkout|reset|clean|rm|mv|init|apply|restore|stash|tag)\b',
        '\bnpm\s+(install|i|uninstall|link)\b','\bpip\s+install\b',
        '>>','\|\s*Out-File','\|\s*Set-Content','\|\s*Add-Content'
    )
    $isWrite = $false
    foreach ($v in $writeVerbs) { if ($cmd -match $v) { $isWrite = $true; break } }
    if (-not $isWrite) { Write-Decision "durch" "" }

    # Arbeitsverzeichnis zaehlt mit: ein schreibendes Kommando mit relativen
    # Pfaden trifft sonst unbemerkt ein fremdes Verzeichnis.
    $cwd = [string]$in.cwd
    if (-not (Test-Allowed $cwd)) {
        Write-Decision "deny" "Schreibendes Kommando mit Arbeitsverzeichnis ausserhalb des Repos: $cwd. Harte Regel, siehe AGENTS.md Abschnitt 18."
    }

    # Absolute Pfade im Kommandotext einsammeln: Laufwerk, UNC, Git-Bash-Stil.
    # Das UNC-Muster verlangt bewusst einen Hostnamen und danach einen EINFACHEN
    # Trenner ("\\host\share"). Ohne diese Verschaerfung trifft es auch JSON mit
    # escapten Backslashes ("\\00_INDEX\\scripts"), und damit jeden Versuch, eine
    # Hook-Konfiguration zu schreiben.
    $found = @()
    foreach ($rx in @('[a-zA-Z]:[\\/][^"''`;,|)\s]*', '(?<!\\)\\\\[a-zA-Z0-9._-]+\\(?!\\)[^"''`;,|)\s]+', '(?<![\w.])/[a-zA-Z]/[^"''`;,|)\s]*')) {
        foreach ($m in [regex]::Matches($cmd, $rx)) { $found += $m.Value }
    }
    foreach ($f in ($found | Select-Object -Unique)) {
        if (-not (Test-Allowed $f)) {
            Write-Decision "deny" "Schreibendes Kommando mit Ziel ausserhalb des Repos ($repo). Blockierter Pfad: $f. Harte Regel, siehe AGENTS.md Abschnitt 18. Frag [NAME] um Erlaubnis, statt den Weg zu umgehen."
        }
    }
    Write-Decision "durch" ""
}

Write-Decision "durch" ""

} catch {
    Write-Decision "durch" ""
}
