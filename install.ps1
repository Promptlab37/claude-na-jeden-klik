# Claude na jeden klik: nainstaluje Claude Code a nastaví ho pro začátečníka.
# Spouští se přes Instalovat-Claude.bat. Práva správce nepotřebuje.
param(
    [string]$Domov = $env:USERPROFILE,
    [string]$Plocha = [Environment]::GetFolderPath('Desktop'),
    [string]$Dokumenty = [Environment]::GetFolderPath('MyDocuments'),
    [switch]$BezInstalace,
    [switch]$BezSpusteni,
    [switch]$BezPath,
    [string]$KlicPath = 'Environment',
    [string]$KlicTrid = 'Software\Classes',
    [string]$TestStrojovaPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Na některých počítačích v PATH systémové složky chybí, proto se na ni nespoléháme.
if (-not $env:SystemRoot) { $env:SystemRoot = [Environment]::GetFolderPath('Windows') }
$Sys = $env:SystemRoot
$env:Path = "$Sys\System32;$Sys;$Sys\System32\Wbem;$Sys\System32\WindowsPowerShell\v1.0;$env:Path"
# Oficiální instalátor vyžaduje 64bitový PowerShell, i když nás spustila 32bitová aplikace.
$PsExe = "$Sys\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path $PsExe)) { $PsExe = "$Sys\System32\WindowsPowerShell\v1.0\powershell.exe" }

$OficialniInstalator = 'https://claude.ai/install.ps1'
$DotClaude = Join-Path $Domov '.claude'
$Bin = Join-Path $Domov '.local\bin'
$ClaudeExe = Join-Path $Bin 'claude.exe'
if (-not $Dokumenty) { $Dokumenty = Join-Path $Domov 'Documents' }
$Prace = Join-Path $Dokumenty 'Claude'
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
- Když je aktuální složka C:\Windows, System32 nebo jiná systémová složka, nic v ní nevytvářej
  ani neměň. Pracuj ve složce Dokumenty\Claude a řekni mu, kam se soubory ukládají.
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

function Claude-Funguje {
    if (-not (Test-Path $ClaudeExe)) { return $false }
    try {
        $null = & $ClaudeExe --version
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Nainstaluj-Claude {
    if (Claude-Funguje) { Hotovo 'Claude Code už v počítači je, instalaci přeskakuji.'; return }
    if ($BezInstalace) { throw 'Claude Code není nainstalovaný a instalace je vypnutá.' }
    # Nefunkční soubor z dřívějška by mohl oficiální instalaci zmást.
    if (Test-Path -LiteralPath $ClaudeExe) { Remove-Item -LiteralPath $ClaudeExe -Force }
    Write-Host '   Stahuji z oficiálního webu Anthropic, může to trvat pár minut...'
    $skript = Join-Path $env:TEMP "claude-oficialni-$Razitko.ps1"
    Invoke-WebRequest -UseBasicParsing -Uri $OficialniInstalator -OutFile $skript
    try {
        # TLS 1.2 zapneme i pro oficiální instalátor. Kódovaný příkaz snese každý znak v cestě.
        $prikaz = "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; & '$($skript -replace "'", "''")'; exit `$LASTEXITCODE"
        $kodovany = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($prikaz))
        $p = Start-Process $PsExe -NoNewWindow -PassThru `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $kodovany)
        $null = $p.Handle
        $p.WaitForExit()
        if ($p.ExitCode -ne 0) { throw "Oficiální instalace skončila chybou (kód $($p.ExitCode))." }
    } finally {
        Remove-Item $skript -Force -ErrorAction SilentlyContinue
    }
    if (-not (Claude-Funguje)) { throw 'Instalace proběhla, ale Claude Code nejde spustit. Může ho blokovat antivirus.' }
    Hotovo 'Claude Code je nainstalovaný.'
}

function Pridej-DoPath {
    if ($BezPath) { return }
    $klic = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($KlicPath)
    try {
        $puvodni = [string]$klic.GetValue('Path', '', 'DoNotExpandEnvironmentNames')
        $polozky = @($puvodni -split ';' | Where-Object { $_ })
        $rozbalene = @($polozky | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\') })
        $pridat = @()
        if ($rozbalene -notcontains $Bin.TrimEnd('\')) { $pridat += $Bin }

        # Bez systémových složek v PATH nefungují běžné příkazy ani nástroje Claude.
        # Systémová PATH vyžaduje správce, doplnění do uživatelské PATH ne.
        $strojova = $TestStrojovaPath
        if (-not $TestStrojovaPath) {
            $stroj = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment')
            try {
                $strojova = [string]$stroj.GetValue('Path', '')
            } finally {
                $stroj.Close()
            }
        }
        $vsechny = @($rozbalene) + @($strojova -split ';' | Where-Object { $_ } | ForEach-Object {
            [Environment]::ExpandEnvironmentVariables($_).TrimEnd('\')
        })
        foreach ($slozka in '%SystemRoot%\System32', '%SystemRoot%', '%SystemRoot%\System32\Wbem', '%SystemRoot%\System32\WindowsPowerShell\v1.0') {
            if ($vsechny -notcontains [Environment]::ExpandEnvironmentVariables($slozka)) { $pridat += $slozka }
        }

        if ($pridat.Count -gt 0) {
            $novy = ($polozky + $pridat) -join ';'
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
    # Claude hledá důvěru i v nadřazených složkách. Zápis na kořeny disků znamená, že se
    # v žádné nové složce nezeptá. Jinak je předvybrané „No, exit“ a Enter ho vypne.
    # Všechna písmena, aby to platilo i pro flash disk nebo disk připojený později.
    $duveryhodne = @($Prace -replace '\\', '/')
    foreach ($pismeno in [char[]]'CDEFGHIJKLMNOPQRSTUVWXYZ') { $duveryhodne += "${pismeno}:/" }
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

function Prihlas {
    $null = & $ClaudeExe auth status
    if ($LASTEXITCODE -eq 0) { Hotovo 'Už jsi přihlášený.'; return }
    Write-Host '   Otevře se prohlížeč. Přihlas se svým účtem Claude a pak se sem vrať.' -ForegroundColor Yellow
    Write-Host '   Když se přihlášení zasekne, zavři toto okno, spusť ikonu Claude na ploše a napiš /login' -ForegroundColor Yellow
    $p = Start-Process -FilePath $ClaudeExe -ArgumentList @('auth', 'login', '--claudeai') -NoNewWindow -PassThru
    $null = $p.Handle
    $p.WaitForExit()
    if ($p.ExitCode -eq 0) {
        Hotovo 'Přihlášení proběhlo.'
    } else {
        Write-Host '   Přihlášení se nedokončilo. V okně Claude napiš /login a zkus to znovu.' -ForegroundColor Yellow
    }
}

function Vytvor-Zastupce {
    New-Item -ItemType Directory -Force -Path $Plocha | Out-Null
    $lnk = Join-Path $Plocha 'Claude.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $zastupce = $shell.CreateShortcut($lnk)
    $zastupce.TargetPath = $ClaudeExe
    $zastupce.IconLocation = "$ClaudeExe,0"
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
    # Ikona ani nabídka nejsou pro Claude nezbytné, jejich selhání instalaci nezastaví.
    try { Vytvor-Zastupce } catch {
        Write-Host '   Ikonu na plochu se nepodařilo vytvořit. Claude spustíš slovem claude v příkazovém řádku.' -ForegroundColor Yellow
    }
    try { Pridej-Nabidku } catch {
        Write-Host '   Položku v nabídce pravého tlačítka se nepodařilo přidat.' -ForegroundColor Yellow
    }

    if (-not $BezSpusteni) {
        Krok 'Přihlášení'
        Prihlas
    }

    Write-Host ''
    Write-Host 'Hotovo!' -ForegroundColor Green
    Write-Host 'Claude teď pracuje bez ptaní: co mu napíšeš, to rovnou udělá.'
    Write-Host 'Příště ho spustíš ikonou Claude na ploše.'
    Write-Host 'Nebo si založ složku, klikni na ni pravým tlačítkem, otevři příkazový řádek a napiš: claude'
    Write-Host ''
    Write-Host 'Teď se otevře okno Claude. Napiš do něj obyčejně česky, co potřebuješ.' -ForegroundColor Yellow

    if (-not $BezSpusteni) {
        Start-Process -FilePath $ClaudeExe -WorkingDirectory $Prace
    }
    exit 0
} catch {
    Write-Host ''
    Write-Host 'Instalace se nepovedla.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host 'Vyfoť tuhle obrazovku a pošli ji tomu, kdo ti instalaci poslal.'
    exit 1
}
