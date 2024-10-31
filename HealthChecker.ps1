# Versie: 2.3.0

param (
    [string]$logPath = 'C:\ProgramData\AutoUpdate\HPIA\HealthCheck.log',
    [switch]$EnableDebug
)

$ErrorActionPreference = 'Stop'

# Functie om logberichten te schrijven
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $dateTime = Get-Date -Format 'yyyy-MM-dd,HH:mm:ss'
    $logEntry = "$dateTime,$Level,HealthCheck,$Message"
    Add-Content -Path $logPath -Value $logEntry

    if ($EnableDebug.IsPresent) {
        Write-Output $logEntry
    }
}

# Functie om te controleren of AutoUpdate ingeschakeld is in het register
function Is-AutoUpdateEnabled {
    param (
        [string]$registryPath = 'HKLM:\SOFTWARE\AutoUpdate\HPIA'
    )
        
    try {
        $autoUpdate = (Get-ItemProperty -Path $registryPath -Name 'Autoupdate' -ErrorAction Stop).Autoupdate
        return $autoUpdate -eq 'Enabled'
    }
    catch {
        Write-Log -Message "Fout bij lezen van AutoUpdate instelling uit het register: $_" -Level 'ERROR'
        return $false
    }
}

# Functie om de versie te controleren in het scriptbestand
function Get-ScriptVersion {
    param (
        [string]$filePath
    )
        
    if (Test-Path -Path $filePath) {
        $content = Get-Content -Path $filePath -ErrorAction Stop
        $versionLine = $content | Select-String -Pattern '^# Versie: (\d+\.\d+\.\d+)' | Select-Object -First 1 | ForEach-Object { $_.Matches[0].Groups[1].Value }
            
        if ($versionLine) {
            Write-Log -Message "Versie $versionLine gevonden in $filePath." -Level 'INFO'
            return $versionLine
        }
        else {
            Write-Log -Message "Geen versieregel gevonden in $filePath." -Level 'WARNING'
            return $null
        }
    }
    else {
        Write-Log -Message "Bestand $filePath niet gevonden." -Level 'ERROR'
        return $null
    }
}

# Functie om de vereiste scripts van GitHub te lezen
function Get-RequiredScripts {
    param (
        [string]$githubUrl = 'https://raw.githubusercontent.com/robertzijverden/HPIA/main/required-scripts.json'
    )

    try {
        $content = Invoke-WebRequest -Uri $githubUrl -UseBasicParsing -ErrorAction Stop | ConvertFrom-Json
        Write-Log -Message 'Lijst met vereiste scripts succesvol opgehaald.' -Level 'INFO'
        return $content
    }
    catch {
        Write-Log -Message "Fout bij ophalen van de vereiste scripts lijst vanaf GitHub: $_" -Level 'ERROR'
        return $null
    }
}

# Functie om het script te downloaden van GitHub en lokaal op te slaan
function Update-ScriptFromGitHub {
    param (
        [string]$scriptName,
        [string]$localPath,
        [string]$githubUrl = 'https://raw.githubusercontent.com/robertzijverden/HPIA/main'
    )

    # Controleer of de directory van het pad bestaat, maak deze aan als dat niet zo is
    $directory = Split-Path -Path $localPath
    if (!(Test-Path -Path $directory)) {
        try {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
            Write-Log -Message "Map ${directory} aangemaakt." -Level 'INFO'
        }
        catch {
            Write-Log -Message "Fout bij het aanmaken van map ${directory}: $_" -Level 'ERROR'
            return
        }
    }

    $url = "$githubUrl/$scriptName"
    try {
        Invoke-WebRequest -Uri $url -OutFile $localPath -UseBasicParsing -ErrorAction Stop
        Write-Log -Message "Bestand $scriptName succesvol bijgewerkt naar de nieuwste versie vanaf GitHub." -Level 'INFO'
    }
    catch {
        Write-Log -Message "Fout bij downloaden van $scriptName vanaf GitHub: $_" -Level 'ERROR'
    }
}

# Functie om overbodige bestanden te verwijderen
function Remove-UnnecessaryFiles {
    param (
        [array]$filesToRemove,
        [string]$directory = 'C:\ProgramData\AutoUpdate\HPIA'
    )
        
    foreach ($file in $filesToRemove) {
        $filePath = Join-Path -Path $directory -ChildPath $file
        if (Test-Path -Path $filePath) {
            try {
                Remove-Item -Path $filePath -Force -ErrorAction Stop
                Write-Log -Message "Bestand $file succesvol verwijderd." -Level 'INFO'
            }
            catch {
                Write-Log -Message "Fout bij verwijderen van $file $_" -Level 'ERROR'
            }
        }
        else {
            Write-Log -Message "Bestand $file niet gevonden. Geen verwijdering nodig." -Level 'INFO'
        }
    }
}

# Hoofdscript
try {
    $autoUpdateEnabled = Is-AutoUpdateEnabled
    $requiredData = Get-RequiredScripts

    if ($null -ne $requiredData) {
        # Controleer en update de vereiste scripts, behalve het eigen script
        foreach ($script in $requiredData.scripts) {
            if ($script.name -eq 'HealthChecker.ps1') { continue }

            $scriptName = $script.name
            $requiredVersion = $script.version
            $localPath = "C:\ProgramData\AutoUpdate\HPIA\$scriptName"
                
            # Haal de lokale versie uit het scriptbestand op
            $localVersion = Get-ScriptVersion -filePath $localPath
                
            # Controleer of het script ontbreekt of verouderd is
            if ($null -eq $localVersion -or ([Version]$localVersion -lt [Version]$requiredVersion)) {
                Write-Log -Message "Bestand $scriptName ontbreekt of is verouderd. Vereiste versie: $requiredVersion." -Level 'WARNING'
                    
                if ($autoUpdateEnabled) {
                    Update-ScriptFromGitHub -scriptName $scriptName -localPath $localPath
                }
                else {
                    Write-Log -Message "Auto-update is uitgeschakeld, update niet uitgevoerd voor $scriptName." -Level 'INFO'
                }
            }
            else {
                Write-Log -Message "$scriptName is up-to-date met versie $localVersion." -Level 'INFO'
            }
        }

        # Verwijder overbodige bestanden indien gespecificeerd in de verwijderlijst
        if ($autoUpdateEnabled -and $requiredData.remove) {
            Remove-UnnecessaryFiles -filesToRemove $requiredData.remove
        }
    }

    # Controleer en update het eigen script (HealthChecker.ps1)
    $ownScriptName = 'HealthChecker.ps1'
    $ownScriptPath = $PSCommandPath
    $ownVersion = '2.3.0'  # Zorg ervoor dat dit de huidige versie is van het script zelf

    # Controleer of het eigen script ook in de vereiste scripts lijst staat voor updates
    $ownScript = $requiredData.scripts | Where-Object { $_.name -eq $ownScriptName }
    if ($null -ne $ownScript) {
        $requiredVersion = $ownScript.version
        
        # Vergelijk de huidige versie van het script met de vereiste versie
        if ([Version]$ownVersion -lt [Version]$requiredVersion) {
            Write-Log -Message "Eigen script is verouderd. Vereiste versie: $requiredVersion." -Level 'WARNING'
            
            if ($autoUpdateEnabled) {
                $tempPath = "C:\ProgramData\AutoUpdate\HPIA\Temp\$ownScriptName"
                
                # Download de nieuwe versie naar een tijdelijke locatie
                Update-ScriptFromGitHub -scriptName $ownScriptName -localPath $tempPath
                
                # Start het bijgewerkte script en sluit het huidige script af
                Write-Log -Message "Start bijgewerkte versie van $ownScriptName." -Level 'INFO'
                Start-Process -FilePath 'powershell.exe' -ArgumentList "-File `"$tempPath`""
                exit
            }
            else {
                Write-Log -Message "Auto-update is uitgeschakeld, update niet uitgevoerd voor $ownScriptName." -Level 'INFO'
            }
        }
        else {
            Write-Log -Message "$ownScriptName is up-to-date met versie $ownVersion." -Level 'INFO'
        }
    }

    Write-Log -Message 'Health-check voltooid.' -Level 'INFO'
}
catch {
    Write-Log -Message "Fout tijdens health-check: $_" -Level 'ERROR'
}
