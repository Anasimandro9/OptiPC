#Requires -RunAsAdministrator
<#
.SYNOPSIS
    OptiPC - Optimizador para Windows 10 LTSC 2021
    Diseñado para: Core i3 330M · 4 GB DDR3 · HDD · GeForce 310M
.DESCRIPTION
    Ejecutar con:  irm https://raw.githubusercontent.com/TU_USUARIO/optipc/main/optipc.ps1 | iex
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference    = "SilentlyContinue"

# ═══════════════════════════════════════════════════════════════
#  COLORES Y UTILIDADES DE CONSOLA
# ═══════════════════════════════════════════════════════════════
function Write-Title  { param($t) Write-Host "`n  $t" -ForegroundColor Cyan }
function Write-OK     { param($t) Write-Host "  [+] $t" -ForegroundColor Green }
function Write-Info   { param($t) Write-Host "  [·] $t" -ForegroundColor DarkGray }
function Write-Warn   { param($t) Write-Host "  [!] $t" -ForegroundColor Yellow }
function Write-Err    { param($t) Write-Host "  [✗] $t" -ForegroundColor Red }
function Write-Step   { param($t) Write-Host "  --> $t" -ForegroundColor White }
function Write-HR     { Write-Host ("  " + ("─" * 62)) -ForegroundColor DarkGray }
function Write-SectionHeader {
    param($t)
    $pad = " " * [Math]::Max(0, [Math]::Floor((64 - $t.Length) / 2))
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host "  ║$pad$t$pad$(if(($t.Length % 2) -eq 1){' '})║" -ForegroundColor Cyan
    Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
}

function Pause-Script {
    Write-Host "`n  Pulsa cualquier tecla para continuar..." -ForegroundColor DarkGray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Helper: Set registry value, creating key if needed
function Set-Reg {
    param($Path, $Name, $Value, $Type = "DWord")
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
    } catch { Write-Info "No se pudo establecer $Path\$Name" }
}

# Helper: Disable a Windows service
function Disable-Svc {
    param($Name)
    try {
        Stop-Service  -Name $Name -Force -NoWait
        Set-Service   -Name $Name -StartupType Disabled
        Write-OK "Servicio deshabilitado: $Name"
    } catch { Write-Info "Servicio no encontrado o ya deshabilitado: $Name" }
}

# Helper: Disable a scheduled task
function Disable-Task {
    param($Path)
    try {
        Disable-ScheduledTask -TaskPath (Split-Path $Path) -TaskName (Split-Path $Path -Leaf) | Out-Null
        Write-OK "Tarea deshabilitada: $(Split-Path $Path -Leaf)"
    } catch { Write-Info "Tarea no encontrada: $Path" }
}

# Helper: Run command silently
function Run-Cmd {
    param($Exe, $Args)
    try { Start-Process -FilePath $Exe -ArgumentList $Args -Wait -WindowStyle Hidden } catch {}
}

# ═══════════════════════════════════════════════════════════════
#  PANTALLA DE BIENVENIDA
# ═══════════════════════════════════════════════════════════════
function Show-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
    Write-Host "  ║                                                          ║" -ForegroundColor DarkCyan
    Write-Host "  ║    ⚡  OptiPC  —  Optimizador Windows 10 LTSC 2021  ⚡   ║" -ForegroundColor Cyan
    Write-Host "  ║                                                          ║" -ForegroundColor DarkCyan
    Write-Host "  ║    Core i3 330M  ·  4 GB DDR3  ·  HDD  ·  GTX 310M     ║" -ForegroundColor DarkGray
    Write-Host "  ║                                                          ║" -ForegroundColor DarkCyan
    Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
    Write-Host ""

    # Info del sistema en tiempo real
    $os      = (Get-WmiObject Win32_OperatingSystem)
    $cpu     = (Get-WmiObject Win32_Processor | Select-Object -First 1).Name.Trim()
    $ramGB   = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $freeGB  = [Math]::Round($os.FreePhysicalMemory / 1MB, 1)
    $usedPct = [Math]::Round((1 - $os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100)
    $disk    = Get-PSDrive C
    $diskFreeGB = [Math]::Round($disk.Free / 1GB, 1)
    $diskUsedGB = [Math]::Round($disk.Used / 1GB, 1)

    Write-Host "  Sistema  : $($os.Caption) Build $($os.BuildNumber)" -ForegroundColor DarkGray
    Write-Host "  CPU      : $cpu" -ForegroundColor DarkGray
    Write-Host "  RAM      : ${usedPct}% usado  ($($ramGB - $freeGB) GB / $ramGB GB)  —  Libre: $freeGB GB" -ForegroundColor DarkGray
    Write-Host "  Disco C: : Libre $diskFreeGB GB  /  Usado $diskUsedGB GB" -ForegroundColor DarkGray
    Write-Host ""
}

# ═══════════════════════════════════════════════════════════════
#  MENÚ PRINCIPAL
# ═══════════════════════════════════════════════════════════════
function Show-Menu {
    Show-Banner
    Write-Host "  ┌──────────────────────────────────────────────────────────┐" -ForegroundColor DarkGray
    Write-Host "  │  ¿Qué quieres hacer?                                     │" -ForegroundColor Gray
    Write-Host "  ├──────────────────────────────────────────────────────────┤" -ForegroundColor DarkGray
    Write-Host "  │  [1]  🚀  APLICAR TODO  (recomendado — seguro)           │" -ForegroundColor Green
    Write-Host "  │  [2]  🧹  Limpieza de disco y archivos basura            │" -ForegroundColor White
    Write-Host "  │  [3]  ⚙️   Servicios de Windows innecesarios              │" -ForegroundColor White
    Write-Host "  │  [4]  📅  Tareas programadas de telemetría               │" -ForegroundColor White
    Write-Host "  │  [5]  🌐  Red, privacidad y telemetría                   │" -ForegroundColor White
    Write-Host "  │  [6]  🎨  Efectos visuales y UI                          │" -ForegroundColor White
    Write-Host "  │  [7]  💾  Disco, NTFS y memoria virtual                  │" -ForegroundColor White
    Write-Host "  │  [8]  ⚡  Tweaks avanzados de rendimiento                │" -ForegroundColor White
    Write-Host "  │  [9]  🔧  Herramientas del sistema                       │" -ForegroundColor White
    Write-Host "  │  [0]  ❌  Salir                                          │" -ForegroundColor DarkGray
    Write-Host "  └──────────────────────────────────────────────────────────┘" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Elige una opción: " -ForegroundColor Cyan -NoNewline
    return ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")).Character
}

# ═══════════════════════════════════════════════════════════════
#  1 — LIMPIEZA
# ═══════════════════════════════════════════════════════════════
function Invoke-Cleanup {
    Write-SectionHeader "LIMPIEZA DE DISCO"

    $paths = @(
        "$env:TEMP",
        "$env:SystemRoot\Temp",
        "$env:SystemRoot\Prefetch",
        "$env:SystemRoot\SoftwareDistribution\Download",
        "$env:SystemRoot\Logs\CBS",
        "$env:SystemRoot\Minidump",
        "$env:SystemRoot\Downloaded Program Files",
        "$env:LOCALAPPDATA\Temp",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer",        # thumbnails
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache",
        "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache",
        "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
    )

    $totalFiles = 0
    $totalBytes = 0

    Write-Title "Eliminando archivos temporales y caché..."
    foreach ($p in $paths) {
        if (Test-Path $p) {
            $files = Get-ChildItem -Path $p -Recurse -Force -ErrorAction SilentlyContinue
            $count = 0; $bytes = 0
            foreach ($f in $files) {
                if (-not $f.PSIsContainer) {
                    try {
                        $bytes += $f.Length
                        Remove-Item -Path $f.FullName -Force -ErrorAction Stop
                        $count++
                    } catch {}
                }
            }
            # Remove empty subdirs
            Get-ChildItem -Path $p -Directory -Recurse -Force -ErrorAction SilentlyContinue |
                Sort-Object -Property FullName -Descending |
                ForEach-Object { try { Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue } catch {} }

            if ($count -gt 0) {
                $sz = if ($bytes -gt 1GB) { "$([Math]::Round($bytes/1GB,2)) GB" }
                      elseif ($bytes -gt 1MB) { "$([Math]::Round($bytes/1MB,1)) MB" }
                      else { "$([Math]::Round($bytes/1KB,0)) KB" }
                Write-OK "$count archivos eliminados de $(Split-Path $p -Leaf) ($sz)"
            }
            $totalFiles += $count; $totalBytes += $bytes
        }
    }

    # Papelera
    Write-Step "Vaciando Papelera de Reciclaje..."
    try { Clear-RecycleBin -DriveLetter C -Force; Write-OK "Papelera vaciada" } catch {}

    # Logs de eventos de Windows
    Write-Step "Limpiando registros de eventos de Windows..."
    foreach ($log in @("Application","System","Security","Setup")) {
        try { Clear-EventLog -LogName $log; Write-OK "Registro '$log' limpiado" } catch {}
    }

    # WinSxS superficial
    Write-Step "Limpiando componentes WinSxS obsoletos (DISM — puede tardar)..."
    Run-Cmd "dism.exe" "/Online /Cleanup-Image /StartComponentCleanup /ResetBase"
    Write-OK "Limpieza DISM completada"

    # Archivos de volcado
    $dumpFiles = @("$env:SystemRoot\MEMORY.DMP", "$env:SystemRoot\minidump\*.dmp")
    foreach ($d in $dumpFiles) {
        Get-ChildItem $d -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item $_.FullName -Force; Write-OK "Volcado eliminado: $($_.Name)" } catch {}
        }
    }

    $szTotal = if ($totalBytes -gt 1GB) { "$([Math]::Round($totalBytes/1GB,2)) GB" }
               elseif ($totalBytes -gt 1MB) { "$([Math]::Round($totalBytes/1MB,1)) MB" }
               else { "$([Math]::Round($totalBytes/1KB,0)) KB" }

    Write-Host ""
    Write-HR
    Write-Host "  Total liberado: $szTotal en $totalFiles archivos" -ForegroundColor Green
    Write-HR
}

# ═══════════════════════════════════════════════════════════════
#  2 — SERVICIOS
# ═══════════════════════════════════════════════════════════════
function Invoke-Services {
    Write-SectionHeader "SERVICIOS DE WINDOWS"
    Write-Title "Deshabilitando servicios innecesarios..."

    $services = @(
        # Telemetría
        @{ N="DiagTrack";             D="Telemetría de Windows (envía datos a MS)" },
        @{ N="dmwappushservice";       D="WAP Push de Microsoft" },
        @{ N="WerSvc";                 D="Reporte de errores a Microsoft" },
        @{ N="PcaSvc";                 D="Program Compatibility Assistant" },
        @{ N="Cexecsvc";               D="CEIP de cliente" },
        # Búsqueda e indexación
        @{ N="WSearch";                D="Indexación del disco (muy pesado en HDD)" },
        # Memoria
        @{ N="SysMain";                D="Superfetch/SysMain (contraproducente en HDD)" },
        # Xbox (inútil sin Xbox)
        @{ N="XblAuthManager";         D="Xbox Live Authentication" },
        @{ N="XblGameSave";            D="Xbox Game Save" },
        @{ N="XboxNetApiSvc";          D="Xbox Networking" },
        @{ N="XboxGipSvc";             D="Xbox Accessory Management" },
        # Biometría / NFC / Geolocalización
        @{ N="WbioSrvc";               D="Biometría (huellas dactilares)" },
        @{ N="lfsvc";                  D="Geolocalización" },
        @{ N="SEMgrSvc";               D="Pagos y NFC" },
        # Fax / Impresión remota
        @{ N="Fax";                    D="Servicio de Fax" },
        # Acceso remoto
        @{ N="RemoteRegistry";         D="Acceso remoto al registro (riesgo de seguridad)" },
        @{ N="RemoteAccess";           D="Routing and Remote Access" },
        # Tableta / táctil
        @{ N="TabletInputService";     D="Teclado táctil / entrada tablet" },
        # Mapas y teléfono
        @{ N="MapsBroker";             D="Descarga de mapas offline" },
        @{ N="PhoneSvc";               D="Servicio de teléfono" },
        # Smart Card
        @{ N="SCardSvr";               D="Lector de tarjetas inteligentes" },
        @{ N="ScDeviceEnum";           D="Enumerador de Smart Cards" },
        # Sensores
        @{ N="SensorService";          D="Servicio de sensores" },
        @{ N="SensrSvc";               D="Monitorización de sensores" },
        @{ N="SensorDataService";      D="Datos de sensores" },
        # Escáneres / cámaras
        @{ N="stisvc";                 D="Windows Image Acquisition (escáneres)" },
        # Varios
        @{ N="TrkWks";                 D="Distributed Link Tracking Client" },
        @{ N="wisvc";                  D="Windows Insider Service" },
        @{ N="RetailDemo";             D="Modo demo de tienda" },
        @{ N="icssvc";                 D="Mobile Hotspot" },
        @{ N="WMPNetworkSvc";          D="Windows Media Player Network Sharing" },
        @{ N="WpcMonSvc";              D="Control parental" },
        @{ N="NgcSvc";                 D="Windows Hello (huella/cara)" },
        @{ N="NgcCtnrSvc";             D="Windows Hello Container" },
        @{ N="NaturalAuthentication";  D="Autenticación natural (biometría)" },
        @{ N="wlidsvc";                D="Microsoft Account Sign-in (si usas cuenta local)" },
        @{ N="SharedAccess";           D="ICS — Compartir conexión a Internet" },
        @{ N="TermService";            D="Remote Desktop (si no lo usas)" },
        @{ N="UmRdpService";           D="Remote Desktop — Redirector de puertos" },
        @{ N="SessionEnv";             D="Remote Desktop Configuration" },
        @{ N="WalletService";          D="Monedero de Windows" },
        @{ N="OneSyncSvc";             D="Sincronización (contactos, correo, calendario)" },
        @{ N="UnistoreSvc";            D="Almacén de datos de usuario" },
        @{ N="UserDataSvc";            D="Servicio de datos de usuario" },
        @{ N="MessagingService";       D="Mensajería (SMS)" },
        @{ N="PimIndexMaintenanceSvc"; D="Índice de contactos" },
        @{ N="RmSvc";                  D="Radio Management (WiFi/BT toggle)" },
        @{ N="BcastDVRUserService";    D="Grabación de juegos (Game DVR)" }
    )

    foreach ($svc in $services) {
        Write-Info "$($svc.D)..."
        Disable-Svc -Name $svc.N
    }

    Write-OK "Todos los servicios procesados."
}

# ═══════════════════════════════════════════════════════════════
#  3 — TAREAS PROGRAMADAS
# ═══════════════════════════════════════════════════════════════
function Invoke-Tasks {
    Write-SectionHeader "TAREAS PROGRAMADAS"
    Write-Title "Deshabilitando tareas de telemetría y diagnóstico..."

    $tasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Application Experience\StartupAppTask",
        "\Microsoft\Windows\Application Experience\PcaPatchDbTask",
        "\Microsoft\Windows\Autochk\Proxy",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\Customer Experience Improvement Program\BthSQM",
        "\Microsoft\Windows\Customer Experience Improvement Program\HypervisorFlightingTask",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver",
        "\Microsoft\Windows\DiskFootprint\Diagnostics",
        "\Microsoft\Windows\DiskFootprint\StorageSense",
        "\Microsoft\Windows\Feedback\Siuf\DmClient",
        "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
        "\Microsoft\Windows\Maps\MapsUpdateTask",
        "\Microsoft\Windows\Maps\MapsToastTask",
        "\Microsoft\Windows\Shell\FamilySafetyMonitor",
        "\Microsoft\Windows\Shell\FamilySafetyRefreshTask",
        "\Microsoft\Windows\Shell\FamilySafetyUpload",
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
        "\Microsoft\Windows\WindowsUpdate\Automatic App Update",
        "\Microsoft\Windows\XblGameSave\XblGameSaveTask",
        "\Microsoft\Windows\XblGameSave\XblGameSaveTaskLogon",
        "\Microsoft\Windows\Diagnosis\Scheduled",
        "\Microsoft\Windows\MUI\LPRemove",
        "\Microsoft\Windows\NetTrace\GatherNetworkInfo",
        "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
        "\Microsoft\Windows\PushToInstall\LoginCheck",
        "\Microsoft\Windows\PushToInstall\Registration",
        "\Microsoft\Windows\Maintenance\WinSAT",
        "\Microsoft\Windows\Media Center\ActivateWindowsSearch",
        "\Microsoft\Windows\Media Center\ConfigureInternetTimeService",
        "\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents",
        "\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic",
        "\Microsoft\Windows\SpacePort\SpaceAgentTask",
        "\Microsoft\Windows\SpacePort\SpaceManagerTask",
        "\Microsoft\Windows\Speech\SpeechModelDownloadTask",
        "\Microsoft\Windows\WindowsUpdate\sih",
        "\Microsoft\Windows\WindowsUpdate\sihboot",
        "\Microsoft\XblGameSave\XblGameSaveTask"
    )

    foreach ($task in $tasks) {
        Write-Info "$(Split-Path $task -Leaf)..."
        Disable-Task -Path $task
    }

    Write-OK "Todas las tareas procesadas."
}

# ═══════════════════════════════════════════════════════════════
#  4 — RED Y PRIVACIDAD
# ═══════════════════════════════════════════════════════════════
function Invoke-NetworkPrivacy {
    Write-SectionHeader "RED, PRIVACIDAD Y TELEMETRÍA"

    # ── Telemetría ──
    Write-Title "Deshabilitando telemetría de Windows..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"             "AllowTelemetry"              0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry"           0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "MaxTelemetryAllowed"      0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"             "DoNotShowFeedbackNotifications" 1
    Set-Reg "HKCU:\Software\Microsoft\Siuf\Rules"                                  "NumberOfSIUFInPeriod"        0
    Set-Reg "HKCU:\Software\Microsoft\Siuf\Rules"                                  "PeriodInNanoSeconds"         0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows"                  "CEIPEnable"                  0
    Write-OK "Telemetría deshabilitada"

    # ── Cortana y búsqueda web ──
    Write-Title "Deshabilitando Cortana y búsqueda web..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"             "AllowCortana"                0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"             "DisableWebSearch"            1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"             "ConnectedSearchUseWeb"       0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"               "BingSearchEnabled"           0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"               "CortanaConsent"              0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"               "SearchboxTaskbarMode"        1
    Write-OK "Cortana y búsqueda web deshabilitadas"

    # ── ID publicitario y seguimiento ──
    Write-Title "Deshabilitando seguimiento y publicidad..."
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo"      "Enabled"                     0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"            "DisabledByGroupPolicy"       1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"    "Start_TrackProgs"            0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SoftLandingEnabled"        0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "OemPreInstalledAppsEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "PreInstalledAppsEnabled"   0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "ContentDeliveryAllowed"    0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "RotatingLockScreenEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353698Enabled" 0
    Write-OK "Publicidad y seguimiento deshabilitados"

    # ── Timeline / Historial de actividad ──
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"                     "EnableActivityFeed"          0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"                     "PublishUserActivities"       0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"                     "UploadUserActivities"        0
    Write-OK "Timeline / Historial de actividad deshabilitado"

    # ── Windows Update P2P y drivers ──
    Write-Title "Configurando Windows Update..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"       "DODownloadMode"              0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"              "ExcludeWUDriversInQualityUpdate" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"           "NoAutoRebootWithLoggedOnUsers" 1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"           "AUOptions"                   2
    Write-OK "Windows Update P2P deshabilitado"

    # ── TCP/IP Tweaks ──
    Write-Title "Optimizando TCP/IP..."
    Run-Cmd "netsh" "int tcp set global autotuninglevel=normal"
    Run-Cmd "netsh" "int tcp set global chimney=disabled"
    Run-Cmd "netsh" "int tcp set global ecncapability=disabled"
    Run-Cmd "netsh" "int tcp set global timestamps=disabled"
    Run-Cmd "netsh" "int tcp set global rss=enabled"
    Run-Cmd "netsh" "int tcp set global netdma=disabled"
    Run-Cmd "netsh" "interface ipv6 set teredo disabled"
    Run-Cmd "netsh" "interface ipv6 set isatap disabled"
    # Nagle disable para menor latencia
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"             "TcpAckFrequency"             1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"             "TCPNoDelay"                  1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"             "TcpDelAckTicks"              0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"             "DefaultTTL"                  64
    # QoS — liberar el 20% de ancho de banda reservado
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched"                     "NonBestEffortLimit"          0
    Write-OK "TCP/IP optimizado"

    # ── Wi-Fi Sense ──
    Set-Reg "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config"            "AutoConnectAllowedOEM"       0
    Write-OK "Wi-Fi Sense deshabilitado"

    # ── Privacidad adicional (micrófono, cámara, ubicación por app) ──
    Write-Title "Deshabilitando acceso de apps a micrófono/cámara/ubicación..."
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"                 "LetAppsAccessCamera"         2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"                 "LetAppsAccessMicrophone"     2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"                 "LetAppsAccessLocation"       2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"                 "LetAppsAccessContacts"       2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"                 "LetAppsAccessCalendar"       2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"                 "LetAppsAccessCallHistory"    2
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"                 "LetAppsAccessEmail"          2
    Write-OK "Privacidad de apps configurada (valor 2 = Deny por defecto)"
}

# ═══════════════════════════════════════════════════════════════
#  5 — EFECTOS VISUALES
# ═══════════════════════════════════════════════════════════════
function Invoke-Visual {
    Write-SectionHeader "EFECTOS VISUALES Y UI"
    Write-Title "Aplicando configuración de máximo rendimiento visual..."

    # Mejor rendimiento visual
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2

    # Preferencias de usuario (animaciones, sombras, efectos)
    # 0x90, 0x12, 0x01, 0x80 = la mayoría de efectos apagados
    $bytes = [byte[]](0x90,0x12,0x01,0x80,0x10,0x00,0x00,0x00)
    Set-Reg "HKCU:\Control Panel\Desktop"                                           "UserPreferencesMask" $bytes "Binary"

    # Animaciones
    Set-Reg "HKCU:\Control Panel\Desktop\WindowMetrics"                             "MinAnimate"          "0"   "String"

    # Menús instantáneos (0ms de delay)
    Set-Reg "HKCU:\Control Panel\Desktop"                                           "MenuShowDelay"       "0"   "String"

    # Sin arrastrar contenido completo (solo borde)
    Set-Reg "HKCU:\Control Panel\Desktop"                                           "DragFullWindows"     "0"   "String"

    # Sin fuentes suavizadas ClearType innecesarias
    # (Dejamos ClearType activado — desactivarlo hace las fuentes horribles)
    Set-Reg "HKCU:\Control Panel\Desktop"                                           "FontSmoothingType"   2     "DWord"

    # Transparencia del escritorio
    Set-Reg "HKCU:\Software\Microsoft\Windows\DWM"                                  "EnableTransparency"  0

    # Barra de tareas sin animaciones
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"     "TaskbarAnimations"   0

    # Explorador: iconos en vez de miniaturas (mucho más rápido en HDD)
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"     "IconsOnly"           1

    # Mostrar extensiones de archivo
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"     "HideFileExt"         0

    # Mostrar archivos ocultos
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"     "Hidden"              1

    # Sin sombras bajo el ratón
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"     "ListviewShadow"       0

    # Sin People Bar en la barra de tareas
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"     "PeopleBand"          0

    # Sin animación al primer inicio de apps
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"     "LaunchTo"            1

    # Explorador: no mostrar recientes en Acceso rápido
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"              "ShowRecent"          0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"              "ShowFrequent"        0

    # Carpetas del explorador en proceso separado (más estabilidad)
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"     "SeparateProcess"     1

    # Deshabilitar acceso rápido en el explorador (abrir en Este Equipo)
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"              "LaunchTo"            1

    Write-OK "Efectos visuales optimizados para máximo rendimiento"
    Write-Warn "Cierra sesión o reinicia para aplicar todos los cambios visuales"
}

# ═══════════════════════════════════════════════════════════════
#  6 — DISCO Y NTFS
# ═══════════════════════════════════════════════════════════════
function Invoke-Disk {
    Write-SectionHeader "DISCO Y NTFS"

    # ── NTFS ──
    Write-Title "Optimizando NTFS para HDD..."
    Run-Cmd "fsutil" "behavior set disable8dot3 1"          # Sin nombres cortos 8.3
    Run-Cmd "fsutil" "behavior set disablelastaccess 1"     # Sin LastAccessTime
    Run-Cmd "fsutil" "behavior set mftzone 2"               # MFT en zona óptima
    Run-Cmd "fsutil" "behavior set memoryusage 2"           # Más caché de paginación NTFS
    Run-Cmd "fsutil" "behavior set encryptpagingfile 0"     # Sin cifrado del pagefile
    Write-OK "NTFS optimizado (sin nombres 8.3, sin LastAccessTime)"

    # ── Pagefile fijo (evita fragmentación) ──
    Write-Title "Configurando memoria virtual (pagefile fijo 2048 MB)..."
    $cs = Get-WmiObject Win32_ComputerSystem
    $cs.AutomaticManagedPagefile = $false
    $cs.Put() | Out-Null
    $pf = Get-WmiObject Win32_PageFileSetting
    if ($pf) {
        $pf.InitialSize = 2048
        $pf.MaximumSize = 2048
        $pf.Put() | Out-Null
        Write-OK "Pagefile fijado en 2048 MB"
    } else {
        Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{
            Name = "C:\pagefile.sys"; InitialSize = 2048; MaximumSize = 2048
        } | Out-Null
        Write-OK "Pagefile creado y fijado en 2048 MB"
    }

    # ── Hibernación (libera ~4 GB en disco) ──
    Write-Title "Deshabilitando hibernación (libera hiberfil.sys)..."
    Run-Cmd "powercfg" "/hibernate off"
    Write-OK "Hibernación deshabilitada — hiberfil.sys eliminado (~4 GB libres)"

    # ── Fast Startup (causa problemas en algunos equipos) ──
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"          "HiberbootEnabled"    0
    Write-OK "Fast Startup deshabilitado"

    # ── Desfragmentación automática deshabilitada (hacerlo manualmente) ──
    Run-Cmd "schtasks" "/Change /TN `"\Microsoft\Windows\Defrag\ScheduledDefrag`" /Disable"
    Write-OK "Desfragmentación automática deshabilitada (hazla manualmente cuando quieras)"

    # ── Volcados de memoria (BSOD) — solo log, sin archivo ──
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"                  "CrashDumpEnabled"    0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"                  "LogEvent"            1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"                  "SendAlert"           0
    Write-OK "Volcados de memoria en BSOD deshabilitados (ahorra espacio)"

    # ── Prefetch deshabilitado (en SSD no hace nada, en HDD puede molestar) ──
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnablePrefetcher" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnableSuperfetch" 0
    Write-OK "Prefetch deshabilitado"

    # ── Storage Sense (limpieza automática) ── activar
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\StorageSense"               "AllowStorageSenseGlobal" 1
    Write-OK "Storage Sense configurado"
}

# ═══════════════════════════════════════════════════════════════
#  7 — TWEAKS AVANZADOS
# ═══════════════════════════════════════════════════════════════
function Invoke-Advanced {
    Write-SectionHeader "TWEAKS AVANZADOS DE RENDIMIENTO"

    # ── Plan de energía: Alto Rendimiento ──
    Write-Title "Activando plan de energía Alto Rendimiento..."
    Run-Cmd "powercfg" "/setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
    # Intentar desbloquear plan Máximo Rendimiento
    Run-Cmd "powercfg" "/duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61" 2>&1 | Out-Null
    $plans = powercfg /list 2>$null
    $ultLine = $plans | Where-Object { $_ -match "Ultimate|Máximo|e9a42b02" }
    if ($ultLine) {
        $guid = ($ultLine -split "\s+")[3]
        Run-Cmd "powercfg" "/setactive $guid"
        Write-OK "Plan Máximo Rendimiento activado"
    } else {
        Write-OK "Plan Alto Rendimiento activado"
    }

    # ── CPU: prioridad a procesos en primer plano ──
    Write-Title "Optimizando planificador de CPU..."
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"               "Win32PrioritySeparation" 38
    Write-OK "Prioridad de CPU: programas en primer plano"

    # ── Kernel en RAM (no paginar ejecutivos del kernel) ──
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" 1
    Write-OK "Kernel bloqueado en RAM (sin paginación)"

    # ── Apagar Windows más rápido ──
    Write-Title "Reduciendo tiempos de cierre..."
    Set-Reg "HKCU:\Control Panel\Desktop"                                           "WaitToKillAppTimeout"  "2000" "String"
    Set-Reg "HKCU:\Control Panel\Desktop"                                           "HungAppTimeout"        "1000" "String"
    Set-Reg "HKCU:\Control Panel\Desktop"                                           "AutoEndTasks"          "1"    "String"
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control"                                "WaitToKillServiceTimeout" "2000" "String"
    Write-OK "Tiempos de cierre reducidos a 2 segundos"

    # ── HPET deshabilitado (mejor para juegos y rendimiento general) ──
    Write-Title "Deshabilitando HPET (mejora latencia en juegos)..."
    Run-Cmd "bcdedit" "/deletevalue useplatformclock"
    Run-Cmd "bcdedit" "/set disabledynamictick yes"
    Write-OK "HPET y dynamic tick deshabilitados"

    # ── IRQ de GPU en prioridad alta ──
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"               "IRQ8Priority"  1
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"               "IRQ16Priority" 1

    # ── nVidia GeForce 310M tweaks ──
    Write-Title "Optimizando registro para GeForce 310M..."
    $nvPath = "HKLM:\SOFTWARE\NVIDIA Corporation\Global"
    Set-Reg "$nvPath\NVTweak"                                                       "Coolbits"            8
    Set-Reg "$nvPath\NvCplApi\Policies"                                             "PowerMizerEnable"    0
    Set-Reg "$nvPath\NvCplApi\Policies"                                             "PowerMizerLevel"     1
    Set-Reg "$nvPath\NvCplApi\Policies"                                             "PowerMizerLevelAC"   1
    Write-OK "nVidia: modo rendimiento activado"

    # ── Deshabilitar Game Bar y Game Mode (inútil en este equipo) ──
    Write-Title "Deshabilitando Game Bar y DVR..."
    Set-Reg "HKCU:\System\GameConfigStore"                                          "GameDVR_Enabled"     0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"                     "AllowGameDVR"        0
    Set-Reg "HKCU:\Software\Microsoft\GameBar"                                      "ShowStartupPanel"    0
    Set-Reg "HKCU:\Software\Microsoft\GameBar"                                      "UseNexusForGameBarEnabled" 0
    Write-OK "Game Bar deshabilitado"

    # ── Deshabilitar notificaciones de centro de actividades ──
    Write-Title "Optimizando notificaciones y centro de actividades..."
    Set-Reg "HKCU:\Software\Policies\Microsoft\Windows\Explorer"                    "DisableNotificationCenter" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\PushNotifications"     "ToastEnabled"        0
    Write-OK "Centro de notificaciones deshabilitado"

    # ── Eliminar bloatware de LTSC (apps mínimas, pero por si acaso) ──
    Write-Title "Eliminando apps innecesarias..."
    $appsToRemove = @(
        "Microsoft.XboxGameOverlay",
        "Microsoft.XboxGamingOverlay",
        "Microsoft.Xbox.TCUI",
        "Microsoft.XboxApp",
        "Microsoft.XboxSpeechToTextOverlay",
        "Microsoft.MixedReality.Portal",
        "Microsoft.Microsoft3DViewer",
        "Microsoft.Print3D",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.Messaging",
        "Microsoft.People"
    )
    foreach ($app in $appsToRemove) {
        $pkg = Get-AppxPackage -Name $app -ErrorAction SilentlyContinue
        if ($pkg) {
            Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction SilentlyContinue
            Write-OK "App eliminada: $app"
        }
    }

    # ── SFC (verificar integridad del sistema) ──
    Write-Title "Comprobando integridad del sistema (SFC)..."
    Write-Warn "Esto puede tardar 5-10 minutos..."
    Run-Cmd "sfc" "/scannow"
    Write-OK "SFC completado"

    # ── Restablecer red (soluciona muchos problemas de conectividad) ──
    Write-Title "Reseteando stack de red..."
    Run-Cmd "netsh" "winsock reset"
    Run-Cmd "netsh" "int ip reset"
    Run-Cmd "ipconfig" "/flushdns"
    Write-OK "Stack de red reseteado y DNS limpiado"

    # ── Registro: reducir tamaño máximo ──
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache" 0

    Write-OK "Tweaks avanzados completados"
}

# ═══════════════════════════════════════════════════════════════
#  8 — HERRAMIENTAS
# ═══════════════════════════════════════════════════════════════
function Invoke-Tools {
    Write-SectionHeader "HERRAMIENTAS DEL SISTEMA"
    Write-Host ""
    Write-Host "  [1]  Administrador de tareas         (taskmgr)" -ForegroundColor White
    Write-Host "  [2]  Monitor de recursos             (resmon)" -ForegroundColor White
    Write-Host "  [3]  Información del sistema         (msinfo32)" -ForegroundColor White
    Write-Host "  [4]  Administrador de discos         (diskmgmt)" -ForegroundColor White
    Write-Host "  [5]  Servicios                       (services.msc)" -ForegroundColor White
    Write-Host "  [6]  Editor de registro              (regedit)" -ForegroundColor White
    Write-Host "  [7]  Tareas programadas              (taskschd.msc)" -ForegroundColor White
    Write-Host "  [8]  Desfragmentar disco C:" -ForegroundColor White
    Write-Host "  [9]  CHKDSK en próximo arranque" -ForegroundColor White
    Write-Host "  [A]  Mostrar info del sistema (CPU/RAM/Disco)" -ForegroundColor White
    Write-Host "  [0]  Volver al menú principal" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Elige: " -ForegroundColor Cyan -NoNewline
    $k = ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")).Character

    switch ($k) {
        "1" { Start-Process taskmgr }
        "2" { Start-Process resmon }
        "3" { Start-Process msinfo32 }
        "4" { Start-Process diskmgmt.msc }
        "5" { Start-Process services.msc }
        "6" { Start-Process regedit }
        "7" { Start-Process taskschd.msc }
        "8" {
            Write-Warn "Iniciando desfragmentación de C: — puede tardar 30-60 minutos..."
            Start-Process "defrag.exe" -ArgumentList "C: /U /V" -Wait
            Write-OK "Desfragmentación completada"
        }
        "9" {
            Run-Cmd "chkdsk" "C: /F /R"
            Write-OK "CHKDSK programado para el próximo arranque"
        }
        "a" { Show-SystemInfo }
        "A" { Show-SystemInfo }
    }
}

function Show-SystemInfo {
    Write-HR
    $cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
    $os  = Get-WmiObject Win32_OperatingSystem
    $cs  = Get-WmiObject Win32_ComputerSystem
    $disk = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DeviceID -eq "C:" }

    Write-Host "  CPU      : $($cpu.Name.Trim())" -ForegroundColor Cyan
    Write-Host "  Núcleos  : $($cpu.NumberOfCores) núcleos / $($cpu.NumberOfLogicalProcessors) hilos" -ForegroundColor White
    Write-Host "  Uso CPU  : $($cpu.LoadPercentage)%" -ForegroundColor White
    Write-Host "  RAM Tot  : $([Math]::Round($cs.TotalPhysicalMemory/1GB,1)) GB" -ForegroundColor Cyan
    Write-Host "  RAM Libre: $([Math]::Round($os.FreePhysicalMemory/1MB,1)) MB" -ForegroundColor White
    Write-Host "  RAM Usada: $([Math]::Round(($cs.TotalPhysicalMemory - $os.FreePhysicalMemory*1KB)/1GB,1)) GB ($([Math]::Round((1-$os.FreePhysicalMemory*1KB/$cs.TotalPhysicalMemory)*100))%)" -ForegroundColor White
    Write-Host "  Disco C: : $([Math]::Round($disk.Size/1GB,0)) GB total / $([Math]::Round($disk.FreeSpace/1GB,1)) GB libres" -ForegroundColor Cyan
    Write-Host "  Windows  : $($os.Caption) Build $($os.BuildNumber)" -ForegroundColor White
    Write-HR
}

# ═══════════════════════════════════════════════════════════════
#  APLICAR TODO
# ═══════════════════════════════════════════════════════════════
function Invoke-All {
    Write-SectionHeader "APLICAR TODAS LAS OPTIMIZACIONES"
    Write-Host ""
    Write-Warn "Esto aplicará TODAS las optimizaciones a la vez:"
    Write-Host "  · Limpieza de disco y archivos temporales" -ForegroundColor White
    Write-Host "  · Deshabilitar servicios innecesarios" -ForegroundColor White
    Write-Host "  · Deshabilitar tareas de telemetría" -ForegroundColor White
    Write-Host "  · Privacidad, red y TCP/IP" -ForegroundColor White
    Write-Host "  · Efectos visuales mínimos" -ForegroundColor White
    Write-Host "  · Optimizaciones NTFS y disco" -ForegroundColor White
    Write-Host "  · Tweaks avanzados de rendimiento" -ForegroundColor White
    Write-Host ""
    Write-Host "  ¿Continuar? [S/N]: " -ForegroundColor Yellow -NoNewline
    $k = ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")).Character
    if ($k -notin @("s","S","y","Y")) { Write-Warn "Cancelado."; return }

    $start = Get-Date
    Invoke-Cleanup
    Invoke-Services
    Invoke-Tasks
    Invoke-NetworkPrivacy
    Invoke-Visual
    Invoke-Disk
    Invoke-Advanced

    $elapsed = [Math]::Round(((Get-Date) - $start).TotalSeconds)
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║   ✅  TODAS LAS OPTIMIZACIONES APLICADAS ($elapsed seg)    ║" -ForegroundColor Green
    Write-Host "  ║   Reinicia Windows para que surtan efecto completo.     ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  ¿Reiniciar ahora? [S/N]: " -ForegroundColor Yellow -NoNewline
    $r = ($Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")).Character
    if ($r -in @("s","S","y","Y")) { Restart-Computer -Force }
}

# ═══════════════════════════════════════════════════════════════
#  BUCLE PRINCIPAL
# ═══════════════════════════════════════════════════════════════
while ($true) {
    $choice = Show-Menu
    switch ($choice) {
        "1" { Invoke-All;           Pause-Script }
        "2" { Invoke-Cleanup;       Pause-Script }
        "3" { Invoke-Services;      Pause-Script }
        "4" { Invoke-Tasks;         Pause-Script }
        "5" { Invoke-NetworkPrivacy;Pause-Script }
        "6" { Invoke-Visual;        Pause-Script }
        "7" { Invoke-Disk;          Pause-Script }
        "8" { Invoke-Advanced;      Pause-Script }
        "9" { Invoke-Tools;         Pause-Script }
        "0" { Clear-Host; Write-Host "`n  Hasta luego!`n" -ForegroundColor Cyan; exit }
    }
}
