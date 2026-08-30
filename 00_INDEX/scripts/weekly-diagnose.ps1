# weekly-diagnose.ps1
# Zweck: Unbeaufsichtigte woechentliche Diagnose. Laesst health-check.ps1 (rein
# lesend) laufen und schreibt das Ergebnis nach 10_System\health-check-report.txt,
# mit den WARN- und FAIL-Zeilen ZUOBERST, damit sie jemand liest. Die
# Tagessicherung committet die Datei mit; der Systemzustand ist damit auf GitHub
# sichtbar, ohne dass jemand ein Trigger-Wort sagt.
#
# Entstanden aus einem Befund im Betrieb (30.08.2026): Wer ausschliesslich MIT dem
# System arbeitet und nie AN ihm, loest nie einen Health-Check aus, und das System
# driftet unbemerkt. Diese Diagnose ist das mechanische Gegenmittel; behoben wird
# weiterhin im naechsten Wrap-Up bzw. ueber den Skill leo-system-health-check.
#
# WICHTIG: Dieses Skript gibt immer Exit-Code 0 zurueck, wenn der Lauf selbst
# geklappt hat. Wuerde es den Diagnose-Exitcode durchreichen, meldete der Task
# Scheduler jeden Bericht mit Befund als fehlgeschlagenen Task, und der naechste
# Health-Check warnte ueber seinen eigenen Berichts-Task.
#
# Registrierung: siehe ANLEITUNG.md, Schritt 6 (optionaler zweiter Task).
# ASCII-only mit Absicht, wie die uebrigen Kern-Skripte (laeuft auch unter
# Windows PowerShell 5.1).

$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$report = Join-Path $repo "10_System\health-check-report.txt"
$checker = Join-Path $PSScriptRoot "health-check.ps1"

try {
    $aus = & powershell -NoProfile -ExecutionPolicy Bypass -File $checker 2>&1 | ForEach-Object { "$_" }

    $befunde = @($aus | Where-Object { $_ -match '^\[(WARN|FAIL)\]' })
    $summe   = @($aus | Where-Object { $_ -match '^(Zusammenfassung|VERDIKT)' })

    $inhalt = New-Object System.Collections.Generic.List[string]
    $inhalt.Add("Leo Wochendiagnose vom " + (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    $inhalt.Add("Rein lesend, nichts behoben. Behoben wird im naechsten Wrap-Up oder ueber den Skill leo-system-health-check.")
    $inhalt.Add("")
    if ($befunde.Count -gt 0) {
        $inhalt.Add("=== BEFUNDE (zuerst lesen) ===")
        foreach ($z in $befunde) { $inhalt.Add($z) }
    } else {
        $inhalt.Add("Keine WARN- oder FAIL-Befunde.")
    }
    $inhalt.Add("")
    foreach ($z in $summe) { $inhalt.Add($z) }
    $inhalt.Add("")
    $inhalt.Add("=== Vollstaendiger Bericht ===")
    foreach ($z in $aus) { $inhalt.Add($z) }

    [System.IO.File]::WriteAllLines($report, $inhalt, (New-Object System.Text.UTF8Encoding $false))
    Write-Output "Bericht geschrieben: $report ($($befunde.Count) Befund(e))"
    exit 0
} catch {
    # Auch ein gescheiterter Lauf wird sichtbar gemacht statt still verschluckt.
    try {
        [System.IO.File]::WriteAllLines($report, @(
            "Leo Wochendiagnose vom " + (Get-Date -Format 'yyyy-MM-dd HH:mm'),
            "FEHLER: Die Diagnose selbst ist nicht durchgelaufen: " + $_.Exception.Message
        ), (New-Object System.Text.UTF8Encoding $false))
    } catch { }
    exit 0
}
