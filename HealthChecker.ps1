# Versie: 3.0.0

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

# Functie om de huidige versie van dit script op te halen
function Get-CurrentVersion {
    try {
        $content = Get-Content -Path $scriptPath -ErrorAction Stop
        $versionLine = $content | Select-String -Pattern '^# Versie: (\d+\.\d+\.\d+)' | Select-Object -First 1 | ForEach-Object { $_.Matches[0].Groups[1].Value }
        return $versionLine
    }
    catch {
        Write-Log -Message "Fout bij het lezen van de huidige versie: $_" -Level 'ERROR'
        return $null
    }
}

# Functie om de vereiste versie van GitHub te verkrijgen
function Get-RequiredVersion {
    try {
        $requiredData = Invoke-WebRequest -Uri "$githubUrl/required-scripts.json" -UseBasicParsing | ConvertFrom-Json
        $scriptInfo = $requiredData.scripts | Where-Object { $_.name -eq $scriptName }
        return $scriptInfo.version
    }
    catch {
        Write-Log -Message "Fout bij het ophalen van de vereiste versie: $_" -Level 'ERROR'
        return $null
    }
}

# Ophalen van de huidige en vereiste versie
$currentVersion = Get-CurrentVersion
$requiredVersion = Get-RequiredVersion

if ($null -eq $currentVersion -or $null -eq $requiredVersion) {
    Write-Log -Message "Kon versies niet verifiëren. Update geannuleerd." -Level 'ERROR'
    exit
}

# Controleer of een update nodig is
if ([Version]$currentVersion -lt [Version]$requiredVersion) {
    Write-Log -Message "$scriptName is verouderd. Bijwerken naar versie $requiredVersion." -Level 'WARNING'
    
    try {
        # Download de nieuwe versie naar een tijdelijke locatie
        Invoke-WebRequest -Uri "$githubUrl/$scriptName" -OutFile $tempScriptPath -UseBasicParsing
        Write-Log -Message "Nieuwe versie van $scriptName gedownload naar $tempScriptPath." -Level 'INFO'
        
        # Start het UpdateManager-script om de update af te ronden
        Start-Process -FilePath 'powershell.exe' -ArgumentList "-File `"$updateManagerPath`" -OldScriptPath `"$scriptPath`" -NewScriptPath `"$tempScriptPath`""
        exit
    }
    catch {
        Write-Log -Message "Fout bij het downloaden of voorbereiden van de update: $_" -Level 'ERROR'
        exit
    }
}
else {
    Write-Log -Message "$scriptName is up-to-date met versie $currentVersion." -Level 'INFO'
}

Write-Log -Message "Health-check voltooid." -Level 'INFO'
