# Versie: 3.0.0

param (
    [switch]$FinalizeUpdate  # Wordt gebruikt door het oude script om de nieuwe versie te activeren
)

$scriptName = 'HealthChecker.ps1'
$oldScriptName = 'HealthChecker_old.ps1'
$scriptFolder = 'C:\ProgramData\AutoUpdate\HPIA'
$scriptPath = Join-Path -Path $scriptFolder -ChildPath $scriptName
$oldScriptPath = Join-Path -Path $scriptFolder -ChildPath $oldScriptName
$tempScriptPath = Join-Path -Path $scriptFolder -ChildPath 'HealthChecker_temp.ps1'
$logPath = Join-Path -Path $scriptFolder -ChildPath 'HealthCheck.log'
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
    Write-Output $logEntry
}

# Controleer of het script de nieuwe versie moet activeren en het oude script moet verwijderen
if ($FinalizeUpdate) {
    try {
        # Hernoem het nieuwe script naar de standaard naam
        Rename-Item -Path $tempScriptPath -NewName $scriptName -Force
        Write-Log -Message "Nieuwe versie hernoemd naar $scriptName." -Level 'INFO'

        # Start de nieuwe versie van het script
        Start-Process -FilePath 'powershell.exe' -ArgumentList "-File `"$scriptPath`""

        # Verwijder het oude script na het opstarten van de nieuwe versie
        Remove-Item -Path $oldScriptPath -Force
        Write-Log -Message "Oude versie $oldScriptPath succesvol verwijderd." -Level 'INFO'
        exit
    }
    catch {
        Write-Log -Message "Fout bij het finaliseren van de update: $_" -Level 'ERROR'
        exit
    }
}

# Download en controleer of een update nodig is
$githubUrl = 'https://raw.githubusercontent.com/robertzijverden/HPIA/main'
$currentVersion = '1.0.0'  # Versie van het huidige script
$requiredVersion = '1.1.0'  # Versie die we willen checken

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

# Controleer of een update nodig is
$requiredVersion = Get-RequiredVersion
if ([Version]$currentVersion -lt [Version]$requiredVersion) {
    Write-Log -Message "$scriptName is verouderd. Bijwerken naar versie $requiredVersion." -Level 'WARNING'
    
    try {
        # Hernoem het huidige script naar de oude versie
        Rename-Item -Path $scriptPath -NewName $oldScriptName -Force
        Write-Log -Message "Oude versie hernoemd naar $oldScriptName." -Level 'INFO'

        # Download het nieuwe script naar een tijdelijke locatie
        Invoke-WebRequest -Uri "$githubUrl/$scriptName" -OutFile $tempScriptPath -UseBasicParsing
        Write-Log -Message "Nieuwe versie gedownload naar $tempScriptPath." -Level 'INFO'
        
        # Start de oude versie van het script met de parameter om de update af te ronden
        Start-Process -FilePath 'powershell.exe' -ArgumentList "-File `"$oldScriptPath`" -FinalizeUpdate"
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

Write-Log -Message 'Health-check voltooid.' -Level 'INFO'
