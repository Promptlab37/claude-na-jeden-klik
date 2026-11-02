# Claude na jeden klik: nainstaluje Claude Code a nastaví ho pro začátečníka.
# Spouští se přes Instalovat-Claude.bat. Práva správce nepotřebuje.
param(
    [string]$Domov = $env:USERPROFILE,
    [string]$Plocha = [Environment]::GetFolderPath('Desktop'),
    [switch]$BezInstalace,
    [switch]$BezSpusteni,
    [switch]$BezPath,
    [string]$KlicPath = 'Environment',
    [string]$KlicTrid = 'Software\Classes'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$OficialniInstalator = 'https://claude.ai/install.ps1'
$DotClaude = Join-Path $Domov '.claude'
$Bin = Join-Path $Domov '.local\bin'
$ClaudeExe = Join-Path $Bin 'claude.exe'
$Prace = Join-Path $Domov 'Claude'
$Razitko = Get-Date -Format 'yyyyMMdd-HHmmss'

$Zakazy = @(
    'Bash(format *)', 'PowerShell(format *)', 'PowerShell(Format-Volume*)',
    'Bash(diskpart*)', 'PowerShell(diskpart*)', 'PowerShell(Clear-Disk*)'
)

$Pokyny = @'
# Pokyny pro práci se začátečníkem

Pracuješ s člověkem, který nezná programování ani příkazový řádek.

- Mluv česky a jednoduše. Technické pojmy vysvětli jednou větou nebo se jim vyhni.
- Nežádej ho o spouštění příkazů ani o úpravy souborů. Udělej to sám.
- Když je zadání nejasné, polož jednu srozumitelnou otázku s návrhem řešení.
- Nové soubory ukládej do aktuální pracovní složky, pokud neřekne jinak.
- Než smažeš nebo přepíšeš jeho soubory, zeptej se obyčejnými slovy. Totéž platí před
  odesláním čehokoli na internet, nákupem nebo změnou nastavení Windows.
- Na závěr řekni, co vzniklo a kde to najde. Nevypisuj kód, pokud o něj nestojí.
'@

function Krok($text) { Write-Host ''; Write-Host $text -ForegroundColor Cyan }
function Hotovo($text) { Write-Host "   OK: $text" -ForegroundColor Green }

function Precti-Json($cesta) {
    return ([IO.File]::ReadAllText($cesta) | ConvertFrom-Json)
}

function Zapis-Text($cesta, $text) {
    [IO.File]::WriteAllText($cesta, $text, (New-Object Text.UTF8Encoding($false)))
}

function Nastav($objekt, $nazev, $hodnota) {
    $objekt | Add-Member -NotePropertyName $nazev -NotePropertyValue $hodnota -Force
}

function Najdi-Claude {
    if (Test-Path $ClaudeExe) { return $ClaudeExe }
    $prikaz = Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($prikaz) { return $prikaz.Source }
    return $null
}

function Nainstaluj-Claude {
    if (Najdi-Claude) { Hotovo 'Claude Code už v počítači je, instalaci přeskakuji.'; return }
    if ($BezInstalace) { throw 'Claude Code není nainstalovaný a instalace je vypnutá.' }
    Write-Host '   Stahuji z oficiálního webu Anthropic, může to trvat pár minut...'
    $skript = Join-Path $env:TEMP "claude-oficialni-$Razitko.ps1"
    Invoke-WebRequest -UseBasicParsing -Uri $OficialniInstalator -OutFile $skript
    try {
        $p = Start-Process powershell.exe -NoNewWindow -PassThru `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$skript`"")
        $null = $p.Handle
        $p.WaitForExit()
        if ($p.ExitCode -ne 0) { throw "Oficiální instalace skončila chybou (kód $($p.ExitCode))." }
    } finally {
        Remove-Item $skript -Force -ErrorAction SilentlyContinue
    }
    if (-not (Najdi-Claude)) { throw 'Instalace proběhla, ale Claude Code se nepodařilo najít.' }
    Hotovo 'Claude Code je nainstalovaný.'
}

function Pridej-DoPath {
    if ($BezPath) { return }
    $klic = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($KlicPath)
    try {
        $puvodni = [string]$klic.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
        $polozky = $puvodni -split ';' | Where-Object { $_ }
        $rozbalene = $polozky | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') }
        if ($rozbalene -notcontains $Bin.TrimEnd('\')) {
            $novy = (@($polozky) + $Bin) -join ';'
            $klic.SetValue('Path', $novy, [Microsoft.Win32.RegistryValueKind]::ExpandString)
            # Tenhle zápis jen oznámí oknům Windows, že se proměnné změnily.
            [Environment]::SetEnvironmentVariable('CLAUDE_JEDEN_KLIK', $null, 'User')
        }
    } finally {
        $klic.Close()
    }
    if (($env:Path -split ';') -notcontains $Bin) { $env:Path = "$env:Path;$Bin" }
}

function Nastav-Claude {
    New-Item -ItemType Directory -Force -Path $DotClaude | Out-Null
    $cesta = Join-Path $DotClaude 'settings.json'
    $nastaveni = New-Object PSObject
    if (Test-Path $cesta) {
        Copy-Item $cesta "$cesta.zaloha-$Razitko"
        try {
            $nastaveni = Precti-Json $cesta
        } catch {
            Write-Host '   Staré nastavení nešlo přečíst, je uložené jako záloha a začínám znovu.' -ForegroundColor Yellow
            $nastaveni = New-Object PSObject
        }
    }
    if (-not $nastaveni.permissions) { Nastav $nastaveni 'permissions' (New-Object PSObject) }
    Nastav $nastaveni.permissions 'defaultMode' 'bypassPermissions'
    $zakazy = @(@($nastaveni.permissions.deny) + $Zakazy | Where-Object { $_ } | Select-Object -Unique)
    Nastav $nastaveni.permissions 'deny' $zakazy
    Nastav $nastaveni 'skipDangerousModePermissionPrompt' $true
    if (-not $nastaveni.language) { Nastav $nastaveni 'language' 'czech' }
    Zapis-Text $cesta ($nastaveni | ConvertTo-Json -Depth 50)
    Hotovo 'Claude se nebude na nic ptát a bude mluvit česky.'

    $cestaPokynu = Join-Path $DotClaude 'CLAUDE.md'
    if (Test-Path $cestaPokynu) {
        Hotovo 'Vlastní pokyny už existují, nechávám je být.'
    } else {
        Zapis-Text $cestaPokynu $Pokyny
        Hotovo 'Pokyny pro začátečníka jsou připravené.'
    }
}

function Priprav-Slozku {
    New-Item -ItemType Directory -Force -Path $Prace | Out-Null
    # Stávajícímu uživateli Claude Code konfiguraci nepřepisujeme.
    $cesta = Join-Path $Domov '.claude.json'
    $konfigurace = New-Object PSObject
    if (Test-Path $cesta) {
        try {
            $konfigurace = Precti-Json $cesta
        } catch {
            return
        }
        if ($konfigurace.oauthAccount) { return }
        Copy-Item $cesta "$cesta.zaloha-$Razitko"
    }
    # Přeskočí anglickou volbu barev při prvním spuštění, přihlášení zůstává.
    Nastav $konfigurace 'hasCompletedOnboarding' $true
    # Bez toho se Claude po startu anglicky ptá, jestli přepnout režim, a předvybrané je Ano.
    Nastav $konfigurace 'hasSeenAutoDefaultNudge' $true
    if (-not $konfigurace.theme) { Nastav $konfigurace 'theme' 'dark' }
    if (-not $konfigurace.projects) { Nastav $konfigurace 'projects' (New-Object PSObject) }
    # Claude hledá důvěru i v nadřazených složkách. Zápis na kořeny pevných disků znamená,
    # že se v žádné nové složce nezeptá. Jinak je předvybrané „No, exit“ a Enter ho vypne.
    $duveryhodne = @($Prace -replace '\\', '/')
    foreach ($disk in [IO.DriveInfo]::GetDrives()) {
        if ($disk.DriveType -eq 'Fixed') { $duveryhodne += ($disk.Name -replace '\\', '/') }
    }
    foreach ($klic in $duveryhodne) {
        $projekt = New-Object PSObject
        Nastav $projekt 'hasTrustDialogAccepted' $true
        Nastav $konfigurace.projects $klic $projekt
    }
    Zapis-Text $cesta ($konfigurace | ConvertTo-Json -Depth 50)
}

function Pridej-Nabidku {
    # Položka v nabídce pravého tlačítka na složce i uvnitř složky. Práva správce nepotřebuje.
    # Windows 10 ji ukáže hned, Windows 11 pod „Zobrazit další možnosti“.
    foreach ($typ in 'Directory', 'Directory\Background') {
        $klic = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("$KlicTrid\$typ\shell\ClaudePrikazovyRadek")
        try {
            $klic.SetValue('', 'Otevřít v příkazovém řádku')
            $klic.SetValue('Icon', 'cmd.exe')
            $prikaz = $klic.CreateSubKey('command')
            try {
                $prikaz.SetValue('', 'cmd.exe /s /k pushd "%V"')
            } finally {
                $prikaz.Close()
            }
        } finally {
            $klic.Close()
        }
    }
    Hotovo 'Po kliknutí pravým tlačítkem na složku jde otevřít příkazový řádek.'
}

function Spust-A-Pockej($claude, [string[]]$argumenty) {
    $p = Start-Process -FilePath $claude -ArgumentList $argumenty -NoNewWindow -PassThru
    $null = $p.Handle
    $p.WaitForExit()
    return $p.ExitCode
}

function Prihlas($claude) {
    $null = & $claude auth status
    if ($LASTEXITCODE -eq 0) { Hotovo 'Už jsi přihlášený.'; return }
    Write-Host '   Otevře se prohlížeč. Přihlas se svým účtem Claude a pak se sem vrať.' -ForegroundColor Yellow
    $kod = Spust-A-Pockej $claude @('auth', 'login', '--claudeai')
    if ($kod -eq 0) {
        Hotovo 'Přihlášení proběhlo.'
    } else {
        Write-Host '   Přihlášení se nedokončilo. V okně Claude napiš /login a zkus to znovu.' -ForegroundColor Yellow
    }
}

function Vytvor-Zastupce($claude) {
    $lnk = Join-Path $Plocha 'Claude.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $zastupce = $shell.CreateShortcut($lnk)
    if ($claude -like '*.exe') {
        $zastupce.TargetPath = $claude
        $zastupce.IconLocation = "$claude,0"
    } else {
        $zastupce.TargetPath = "$env:SystemRoot\System32\cmd.exe"
        $zastupce.Arguments = '/c claude'
    }
    $zastupce.WorkingDirectory = $Prace
    $zastupce.Description = 'Spustit Claude'
    $zastupce.Save()
    Hotovo 'Na ploše je ikona Claude.'
}

try {
    Write-Host ''
    Write-Host '==================================' -ForegroundColor Cyan
    Write-Host '   Claude: instalace na jeden klik' -ForegroundColor Cyan
    Write-Host '==================================' -ForegroundColor Cyan

    if (-not [Environment]::Is64BitOperatingSystem) { throw 'Claude Code vyžaduje 64bitová Windows.' }
    if ([Environment]::OSVersion.Version.Build -lt 17763) {
        throw 'Tahle verze Windows je moc stará. Claude Code potřebuje Windows 10 verze 1809 nebo novější.'
    }

    Krok '1/4  Instaluji Claude Code'
    Nainstaluj-Claude
    Pridej-DoPath

    Krok '2/4  Nastavuji Claude'
    Nastav-Claude

    Krok '3/4  Připravuji pracovní složku'
    Priprav-Slozku
    Hotovo "Tvoje práce se bude ukládat do složky $Prace"

    Krok '4/4  Přidávám ikonu a nabídku pravého tlačítka'
    $claude = Najdi-Claude
    Vytvor-Zastupce $claude
    Pridej-Nabidku

    if (-not $BezSpusteni) {
        Krok 'Přihlášení'
        Prihlas $claude
    }

    Write-Host ''
    Write-Host 'Hotovo!' -ForegroundColor Green
    Write-Host 'Claude teď pracuje bez ptaní: co mu napíšeš, to rovnou udělá.'
    Write-Host 'Příště ho spustíš ikonou Claude na ploše.'
    Write-Host 'Nebo si založ složku, klikni na ni pravým tlačítkem, otevři příkazový řádek a napiš: claude'
    Write-Host ''
    Write-Host 'Teď se otevře okno Claude. Napiš do něj obyčejně česky, co potřebuješ.' -ForegroundColor Yellow

    if (-not $BezSpusteni) {
        if ($claude -like '*.exe') {
            Start-Process -FilePath $claude -WorkingDirectory $Prace
        } else {
            Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList '/c claude' -WorkingDirectory $Prace
        }
    }
    exit 0
} catch {
    Write-Host ''
    Write-Host 'Instalace se nepovedla.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host 'Vyfoť tuhle obrazovku a pošli ji tomu, kdo ti instalaci poslal.'
    exit 1
}
