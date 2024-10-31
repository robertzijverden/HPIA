# Versie: 3.1.0

$scriptName = "HealthChecker.ps1"
$tempScriptName = "HealthChecker_new.ps1"
$updateManagerScript = "UpdateManager.ps1"
$scriptFolder = "C:\ProgramData\AutoUpdate\HPIA"
$scriptPath = Join-Path -Path $scriptFolder -ChildPath $scriptName
$tempScriptPath = Join-Path -Path $scriptFolder -ChildPath $tempScriptName
$updateManagerPath = Join-Path -Path $scriptFolder -ChildPath $updateManagerScript
$logPath = Join-Path -Path $scriptFolder -ChildPath "HealthCheck.log"
$ErrorActionPreference = 'Stop'
$githubUrl = 'https://raw.githubusercontent.com/robertzijverden/HPIA/main'

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
    Write-Output $logEntry
}

# Functie om de huidige versie van een script op te halen
function Get-CurrentVersion {
    param (
        [string]$filePath
    )
    
    if (Test-Path -Path $filePath) {
        try {
            $content = Get-Content -Path $filePath -ErrorAction Stop
            $versionLine = $content | Select-String -Pattern '^# Versie: (\d+\.\d+\.\d+)' | Select-Object -First 1 | ForEach-Object { $_.Matches[0].Groups[1].Value }
            return $versionLine
        }
        catch {
            Write-Log -Message "Fout bij het lezen van de versie uit $filePath: $_" -Level 'ERROR'
            return $null
        }
    }
    else {
        Write-Log -Message "Script $filePath niet gevonden." -Level 'WARNING'
        return $null
    }
}

# Functie om de lijst met vereiste scripts van GitHub op te halen
function Get-RequiredScripts {
    try {
        $requiredData = Invoke-WebRequest -Uri "$githubUrl/required-scripts.json" -UseBasicParsing | ConvertFrom-Json
        Write-Log -Message "Lijst met vereiste scripts succesvol opgehaald." -Level 'INFO'
        return $requiredData.scripts
    }
    catch {
        Write-Log -Message "Fout bij het ophalen van de vereiste scriptslijst: $_" -Level 'ERROR'
        return $null
    }
}

# Haal de lijst met vereiste scripts op
$requiredScripts = Get-RequiredScripts
if ($null -eq $requiredScripts) {
    Write-Log -Message "Kon de vereiste scripts niet ophalen. Update geannuleerd." -Level 'ERROR'
    exit
}

# Controleer en update elk script
foreach ($script in $requiredScripts) {
    $scriptName = $script.name
    $requiredVersion = $script.version
    $localPath = Join-Path -Path $scriptFolder -ChildPath $scriptName
    $currentVersion = Get-CurrentVersion -filePath $localPath

    if ($null -eq $currentVersion) {
        Write-Log -Message "Huidige versie van $scriptName kon niet worden bepaald." -Level 'ERROR'
        continue
    }

    # Controleer of het script moet worden bijgewerkt
    if ([Version]$currentVersion -lt [Version]$requiredVersion) {
        Write-Log -Message "$scriptName is verouderd. Bijwerken naar versie $requiredVersion." -Level 'WARNING'
        
        try {
            # Voor HealthChecker.ps1, gebruik een speciale update procedure
            if ($scriptName -eq "HealthChecker.ps1") {
                # Download de nieuwe versie naar een tijdelijke locatie
                Invoke-WebRequest -Uri "$githubUrl/$scriptName" -OutFile $tempScriptPath -UseBasicParsing
                Write-Log -Message "Nieuwe versie van $scriptName gedownload naar $tempScriptPath." -Level 'INFO'
                
                # Start het UpdateManager-script om de update af te ronden
                Start-Process -FilePath 'powershell.exe' -ArgumentList "-File `"$updateManagerPath`" -OldScriptPath `"$scriptPath`" -NewScriptPath `"$tempScriptPath`""
                exit
            }
            else {
                # Voor andere scripts: direct updaten
                Invoke-WebRequest -Uri "$githubUrl/$scriptName" -OutFile $localPath -UseBasicParsing
                Write-Log -Message "Script $scriptName succesvol bijgewerkt naar versie $requiredVersion." -Level 'INFO'
            }
        }
        catch {
            Write-Log -Message "Fout bij het downloaden of bijwerken van $scriptName: $_" -Level 'ERROR'
        }
    }
    else {
        Write-Log -Message "$scriptName is up-to-date met versie $currentVersion." -Level 'INFO'
    }
}

Write-Log -Message "Health-check voltooid." -Level 'INFO'
