# Versie: 1.1.0

param (
    [string]$OldScriptPath,
    [string]$NewScriptPath
)

$logPath = "C:\ProgramData\AutoUpdate\HPIA\HealthCheck.log"

# Functie om logberichten te schrijven
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR')]
        [string]$Level = 'INFO'
    )
    
    $dateTime = Get-Date -Format 'yyyy-MM-dd,HH:mm:ss'
    $logEntry = "$dateTime,$Level,UpdateManager,$Message"
    Add-Content -Path $logPath -Value $logEntry
    Write-Output $logEntry
}

try {
    # Verwijder het oude script
    Remove-Item -Path $OldScriptPath -Force
    Write-Log -Message "Oude versie van HealthChecker.ps1 verwijderd." -Level 'INFO'
    
    # Hernoem het nieuwe script naar de standaardnaam
    Rename-Item -Path $NewScriptPath -NewName (Split-Path -Path $OldScriptPath -Leaf)
    Write-Log -Message "Nieuwe versie hernoemd naar HealthChecker.ps1." -Level 'INFO'
    
    # Start de bijgewerkte versie van HealthChecker.ps1
    Start-Process -FilePath 'powershell.exe' -ArgumentList "-File `"$OldScriptPath`""
    Write-Log -Message "Bijgewerkte versie van HealthChecker.ps1 gestart." -Level 'INFO'
    exit
}
catch {
    Write-Log -Message "Fout bij het afronden van de update: $_" -Level 'ERROR'
    exit
}
