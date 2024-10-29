# Versie: 2.1.0

# Definieer de logbestand locatie
        $logPath = 'C:/hpia/hpia_install_log.txt'

        # Zorg ervoor dat de hpia map en het logbestand bestaan
        $hpiaDirectory = 'C:/hpia'
        if (-not (Test-Path -Path $hpiaDirectory)) {
            New-Item -Path $hpiaDirectory -ItemType Directory
        }
        if (-not (Test-Path -Path $logPath)) {
            New-Item -Path $logPath -ItemType File
        }   

        # Functie om logberichten te schrijven
        function Write-Log {
            param (
                [String]$Message
            )

            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            "$timestamp - $Message" | Out-File -FilePath $logPath -Append
        }

        # URL van de HPIA downloadpagina
        $url = 'https://ftp.ext.hp.com/pub/caps-softpaq/cmit/HPIA.html'

        try {
            $page = Invoke-WebRequest -Uri $url -UseBasicParsing
            Write-Log 'Webpagina succesvol opgehaald.'
        }
        catch {
            Write-Log "Fout bij het verbinden met de HPIA downloadpagina. Error: $_"
            exit 1
        }

        # Zoek de downloadlink voor de nieuwste versie
        $latestVersionLink = $page.Links | Where-Object { $_.href -like '*hp-hpia-*.exe' } | Select-Object -First 1

        if ($latestVersionLink -and $latestVersionLink.href -match 'hp-hpia-(\d+\.\d+\.\d+)') {
            $latestVersion = $matches[1]
            Write-Log "Nieuwste versie gevonden: $latestVersion"
        }
        else {
            Write-Log 'Kan de nieuwste versie niet bepalen.'
            exit 1
        }

        $installedVersion = $null

        # Controleer de geïnstalleerde versie
        $installedExe = Get-ChildItem -Path $hpiaDirectory -Filter 'HPImageAssistant.exe' -File | Select-Object -First 1
        if ($null -ne $installedExe) {
            $installedVersionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($installedExe.FullName)
            $installedVersionFull = $installedVersionInfo.ProductVersion

            if ($installedVersionFull -match '(\d+\.\d+\.\d+)') {
                $installedVersion = $matches[1]
                Write-Log "Geïnstalleerde versie gevonden: $installedVersion"
            }
        }

        if ($installedVersion -and ([version]$installedVersion -ge [version]$latestVersion)) {
            Write-Log "De geïnstalleerde versie van HPIA ($installedVersion) is up-to-date. Geen actie vereist."
            exit 0
        }
        else {
            $tempPath = [System.IO.Path]::GetTempPath()
            $fileName = [System.IO.Path]::GetFileName($latestVersionLink.href)
            $downloadPath = Join-Path -Path $tempPath -ChildPath $fileName

            Invoke-WebRequest -Uri $latestVersionLink.href -OutFile $downloadPath
            Write-Log 'Nieuwste versie van HPIA gedownload naar tijdelijke locatie.'

            $installCommand = "& `"$downloadPath`" /s /e /f c:\hpia"
            Invoke-Expression $installCommand
            Write-Log 'Nieuwe versie van HPIA geïnstalleerd.'

            Remove-Item -Path $downloadPath -Force
            Write-Log 'Tijdelijk installatiebestand verwijderd.'
            exit 0
        }
