    # Versie: 1.0.0

    [cmdletbinding()]
    param()

    # Zorg ervoor dat fouten worden gestopt en opgevangen
    $ErrorActionPreference = 'Stop'

    function Write-Log {
        param (
            [string]$Logger,
            [string]$Message,
            [ValidateSet('INFO', 'WARNING', 'ERROR', 'DEBUG')]
            [string]$Level = 'INFO'
        )

        $dateTime = Get-Date -Format "yyyy-MM-dd,HH:mm:ss"
        $logEntry = "$dateTime,$Level,$Logger,$Message"
        $logEntry | Out-File -FilePath "$env:ProgramData\AutoUpdate\HPIA\HPIA_Update.log" -Append -Encoding utf8

        if ($DebugPreference -eq "Continue" -and $Level -eq 'DEBUG') {
            Write-Output $logEntry
        }
    }

    function Update-HPDrivers {
        param (
            [string]$hpiaPath,
            [string]$reportDirectory,
            [string]$softpaqDownloadFolder
        )

        if (-not (Test-Path -Path $reportDirectory)) {
            New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
            Write-Log -Logger "Update-HPDrivers" -Message "Aangemaakt rapportdirectory: $reportDirectory" -Level "INFO"
        }
        if (-not (Test-Path -Path $softpaqDownloadFolder)) {
            New-Item -ItemType Directory -Path $softpaqDownloadFolder -Force | Out-Null
            Write-Log -Logger "Update-HPDrivers" -Message "Aangemaakt Softpaq-downloadmap: $softpaqDownloadFolder" -Level "INFO"
        }

        $hpiaCommand = "/Operation:Analyze /Category:All /Selection:All /Action:Install /Silent /ReportFolder:`"$reportDirectory`" /Softpaqdownloadfolder:`"$softpaqDownloadFolder`""
        Write-Log -Logger "Update-HPDrivers" -Message "Uitvoeren van HPIA opdracht: $hpiaCommand" -Level "INFO"

        try {
            Start-Process -FilePath "$hpiaPath" -ArgumentList $hpiaCommand -NoNewWindow -Wait -ErrorAction Stop
            Write-Log -Logger "Update-HPDrivers" -Message "HPIA updateproces succesvol voltooid." -Level "INFO"
        }
        catch {
            Write-Log -Logger "Update-HPDrivers" -Message "Fout tijdens HPIA uitvoering: $_" -Level "ERROR"
            throw
        }
    }

    # Hoofdscript
    try {
        $registryPath = 'HKLM:\SOFTWARE\WOW6432Node\AutoUpdate\HPIA' # Subscript registry path
        $settings = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue

        # Voeg logging toe om te controleren of de settings juist worden gelezen
        if ($null -eq $settings) {
            Write-Log -Logger "CheckForHPIAUpdate" -Message "Registry pad '$registryPath' kon niet worden gelezen." -Level "ERROR"
            throw "Registry pad '$registryPath' kon niet worden gelezen."
        }

        $scriptDirectory = $settings.ScriptDirectory
        $hpiaDirectory = $settings.HPIADirectory
        $logPath = $settings.LogPath
        $taskName = $settings.TaskName
        $RunOnce = $settings.RunOnce

        # Log de ingelezen instellingen
        Write-Log -Logger "CheckForHPIAUpdate" -Message "Ingelezen instellingen:" -Level "INFO"
        Write-Log -Logger "CheckForHPIAUpdate" -Message "ScriptDirectory: $scriptDirectory" -Level "INFO"
        Write-Log -Logger "CheckForHPIAUpdate" -Message "HPIADirectory: $hpiaDirectory" -Level "INFO"
        Write-Log -Logger "CheckForHPIAUpdate" -Message "LogPath: $logPath" -Level "INFO"
        Write-Log -Logger "CheckForHPIAUpdate" -Message "TaskName: $taskName" -Level "INFO"
        Write-Log -Logger "CheckForHPIAUpdate" -Message "RunOnce: $RunOnce" -Level "INFO"

        if (-not $hpiaDirectory) {
            Write-Log -Logger "CheckForHPIAUpdate" -Message "HPIADirectory is niet ingesteld." -Level "ERROR"
            throw "HPIADirectory is niet ingesteld."
        }

        $hpiaPath = Join-Path -Path $hpiaDirectory -ChildPath 'HPImageAssistant.exe'

        if (-not (Test-Path -Path $hpiaPath)) {
            Write-Log -Logger "CheckForHPIAUpdate" -Message "HPImageAssistant.exe niet gevonden op pad: $hpiaPath" -Level "ERROR"
            throw "HPImageAssistant.exe niet gevonden op pad: $hpiaPath"
        }

        Write-Log -Logger "CheckForHPIAUpdate" -Message "Start driver update proces." -Level "INFO"

        Update-HPDrivers -hpiaPath $hpiaPath -reportDirectory "$hpiaDirectory\Report" -softpaqDownloadFolder "$hpiaDirectory\Softpaqs"

        if ($RunOnce -eq $true) {
            # Opruimen
            Write-Log -Logger "CheckForHPIAUpdate" -Message "RunOnce is actief, uitvoeren van opruimingsproces." -Level "INFO"

            try {
                Remove-Item -Path $scriptDirectory -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log -Logger "Cleanup" -Message "Verwijderd scriptdirectory: $scriptDirectory" -Level "INFO"
            }
            catch {
                Write-Log -Logger "Cleanup" -Message "Fout bij verwijderen van scriptdirectory: $_" -Level "ERROR"
            }

            try {
                Remove-Item -Path $hpiaDirectory -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log -Logger "Cleanup" -Message "Verwijderd HPIA directory: $hpiaDirectory" -Level "INFO"
            }
            catch {
                Write-Log -Logger "Cleanup" -Message "Fout bij verwijderen van HPIA directory: $_" -Level "ERROR"
            }

            try {
                Remove-Item -Path $registryPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log -Logger "Cleanup" -Message "Verwijderd registry pad: $registryPath" -Level "INFO"
            }
            catch {
                Write-Log -Logger "Cleanup" -Message "Fout bij verwijderen van registry pad: $_" -Level "ERROR"
            }

            try {
                Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
                Write-Log -Logger "Cleanup" -Message "Verwijderd geplande taak: $taskName" -Level "INFO"
            }
            catch {
                Write-Log -Logger "Cleanup" -Message "Fout bij verwijderen van geplande taak: $_" -Level "ERROR"
            }
        }

        Write-Log -Logger "CheckForHPIAUpdate" -Message "Script succesvol uitgevoerd." -Level "INFO"
        exit 0
    }
    catch {
        Write-Log -Logger "CheckForHPIAUpdate" -Message "Er is een fout opgetreden: $_" -Level "ERROR"
        exit 1
    }
