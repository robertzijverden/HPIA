# HPIA

PowerShell-scripts om drivers, firmware en software op HP-apparaten automatisch up-to-date te houden met [HP Image Assistant (HPIA)](https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HPIA.html).

## Scripts

| Script | Wat het doet |
|---|---|
| `HPIAUpdate.ps1` | Haalt de nieuwste HPIA-versie op van de HP-downloadpagina en installeert die in `C:\hpia` als de geïnstalleerde versie ouder is. |
| `CheckForHPIAUpdate.ps1` | Leest de instellingen uit het register en laat HPIA alle aanbevolen updates analyseren en stil installeren. Ruimt bij `RunOnce` alles op na afloop. |
| `HealthChecker.ps1` | Vergelijkt de lokale scripts met de versies in `required-scripts.json` op GitHub en werkt verouderde scripts automatisch bij. |
| `UpdateManager.ps1` | Hulpscript dat `HealthChecker.ps1` vervangt door de nieuwe versie, omdat een script zichzelf niet kan overschrijven terwijl het draait. |
| `required-scripts.json` | De lijst met scripts en de versie die elke client moet hebben, plus scripts die verwijderd mogen worden. |

## Instellingen

`CheckForHPIAUpdate.ps1` leest zijn instellingen uit `HKLM:\SOFTWARE\WOW6432Node\AutoUpdate\HPIA`:

| Waarde | Betekenis |
|---|---|
| `ScriptDirectory` | Map met de scripts |
| `HPIADirectory` | Map waarin `HPImageAssistant.exe` staat |
| `LogPath` | Pad voor logbestanden |
| `TaskName` | Naam van de geplande taak die de scripts start |
| `RunOnce` | Als dit `True` is, worden na één run de scripts, HPIA, de registersleutel en de geplande taak verwijderd |

## Logbestanden

- `C:\ProgramData\AutoUpdate\HPIA\HealthCheck.log`: health-check en zelf-update
- `C:\ProgramData\AutoUpdate\HPIA\HPIA_Update.log`: driver-updates via HPIA
- `C:\hpia\hpia_install_log.txt`: installatie van HPIA zelf
- `<HPIADirectory>\Report`: rapporten van HPIA

## Een nieuwe versie uitrollen

1. Pas het script aan en verhoog de regel `# Versie: x.y.z` bovenaan.
2. Zet hetzelfde versienummer in `required-scripts.json`.
3. Bij de volgende run van `HealthChecker.ps1` halen clients de nieuwe versie automatisch op.
