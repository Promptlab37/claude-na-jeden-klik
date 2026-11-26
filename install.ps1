# Claude + Codex na jeden klik: nainstaluje Claude Code a Codex a nastaví je pro začátečníka.
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
    [string]$TestStrojovaPath,
    [int]$MinMistoMB = 1000
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

# Spouštěné nástroje si občas odloží pomocné soubory do aktuální složky. Ať to není Plocha nebo Stažené.
if ($env:TEMP -and (Test-Path $env:TEMP)) { Set-Location $env:TEMP; [Environment]::CurrentDirectory = $env:TEMP }

$OficialniInstalator = 'https://claude.ai/install.ps1'
$InstalatorCodexu = 'https://chatgpt.com/codex/install.ps1'
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

$KrokuCelkem = 5
$Sirka = 58

function Krok($cislo, $text) {
    Write-Host ''
    Write-Host '   ' -NoNewline
    Write-Host ('█' * $cislo) -ForegroundColor Cyan -NoNewline
    Write-Host ('░' * ($KrokuCelkem - $cislo)) -ForegroundColor DarkGray -NoNewline
    Write-Host "  $cislo/$KrokuCelkem  " -ForegroundColor DarkGray -NoNewline
    Write-Host $text -ForegroundColor White
}

function Hotovo($text) {
    Write-Host '     √ ' -ForegroundColor Green -NoNewline
    Write-Host $text
}

function Pozor($text) {
    Write-Host '     ! ' -ForegroundColor Yellow -NoNewline
    Write-Host $text -ForegroundColor Yellow
}

function Radek($text) { Write-Host "     $text" }

function Ramecek($barva, $radky) {
    Write-Host ''
    Write-Host ('   ╔' + ('═' * $Sirka) + '╗') -ForegroundColor $barva
    foreach ($r in $radky) {
        Write-Host ('   ║   ' + ([string]$r).PadRight($Sirka - 3) + '║') -ForegroundColor $barva
    }
    Write-Host ('   ╚' + ('═' * $Sirka) + '╝') -ForegroundColor $barva
}

function Uvod {
    try { $Host.UI.RawUI.WindowTitle = 'Claude + Codex na jeden klik' } catch {}
    $okraj = 'DarkGray'
    Write-Host ''
    Write-Host ('   ╔' + ('═' * $Sirka) + '╗') -ForegroundColor $okraj
    Write-Host ('   ║' + (' ' * $Sirka) + '║') -ForegroundColor $okraj
    Write-Host '   ║   ' -ForegroundColor $okraj -NoNewline
    Write-Host 'CLAUDE' -ForegroundColor DarkYellow -NoNewline
    Write-Host ' + ' -ForegroundColor Gray -NoNewline
    Write-Host 'CODEX' -ForegroundColor Cyan -NoNewline
    Write-Host ((' ' * ($Sirka - 17)) + '║') -ForegroundColor $okraj
    Write-Host '   ║   ' -ForegroundColor $okraj -NoNewline
    Write-Host 'instalace na jeden klik' -ForegroundColor White -NoNewline
    Write-Host ((' ' * ($Sirka - 26)) + '║') -ForegroundColor $okraj
    Write-Host ('   ║' + (' ' * $Sirka) + '║') -ForegroundColor $okraj
    Write-Host ('   ╚' + ('═' * $Sirka) + '╝') -ForegroundColor $okraj
    Write-Host ''
    Radek 'Trvá to pár minut. Nic nemusíš mačkat, jen počkej na konec.'
    Radek 'Kdyby se okno zastavilo, klikni do něj a stiskni Enter.'
}

function Cekej($proces, $popis) {
    # Ukazatel, že se něco děje. Při přesměrovaném výstupu se jen čeká.
    $naObrazovku = $true
    try { $naObrazovku = -not [Console]::IsOutputRedirected } catch {}
    if (-not $naObrazovku) {
        Radek "$popis..."
        $proces.WaitForExit()
        return
    }
    $znaky = '|', '/', '-', '\'
    $zacatek = Get-Date
    $i = 0
    while (-not $proces.WaitForExit(150)) {
        $sekundy = [int]((Get-Date) - $zacatek).TotalSeconds
        Write-Host ("`r     {0} {1} ({2} s)   " -f $znaky[$i % 4], $popis, $sekundy) -ForegroundColor DarkCyan -NoNewline
        $i++
    }
    $proces.WaitForExit()
    Write-Host ("`r" + (' ' * 78) + "`r") -NoNewline
}

function Spust-Oficialni($adresa, $nazev, $popis) {
    # Stáhne a spustí oficiální instalátor. Jeho anglický výstup jde do souboru,
    # na obrazovce běží jen ukazatel. Při chybě se konec výstupu ukáže.
    $skript = Join-Path $env:TEMP "$nazev-oficialni-$Razitko-$PID.ps1"
    $obal = Join-Path $env:TEMP "$nazev-spusteni-$Razitko-$PID.ps1"
    $vystup = Join-Path $env:TEMP "$nazev-instalace-$Razitko-$PID.log"
    $chyby = Join-Path $env:TEMP "$nazev-instalace-$Razitko-$PID.chyby.log"
    # Plný disk končí nesrozumitelnou anglickou chybou uprostřed instalace.
    $disk = New-Object IO.DriveInfo ([IO.Path]::GetPathRoot($Domov))
    $volneMB = [int]($disk.AvailableFreeSpace / 1MB)
    if ($volneMB -lt $MinMistoMB) {
        throw "Na disku $($disk.Name) je jen $volneMB MB volného místa. Uvolni aspoň $MinMistoMB MB a spusť instalaci znovu."
    }
    try {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $adresa -OutFile $skript
        } catch {
            throw "Nepodařilo se stáhnout instalátor z $(([Uri]$adresa).Host). Zkontroluj připojení k internetu. ($($_.Exception.Message))"
        }
        # TLS 1.2 zapneme i pro oficiální instalátor. Obalový soubor s BOM snese každý znak v cestě.
        $prikaz = "[Net.ServicePointManager]::SecurityProtocol = 'Tls12'; & '$($skript -replace "'", "''")'; exit `$LASTEXITCODE"
        [IO.File]::WriteAllText($obal, $prikaz, (New-Object Text.UTF8Encoding($true)))
        # Pracovní složka TEMP: oficiální instalátory si občas odkládají soubory do aktuální složky.
        $p = Start-Process $PsExe -NoNewWindow -PassThru `
            -WorkingDirectory $env:TEMP -RedirectStandardOutput $vystup -RedirectStandardError $chyby `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$obal`"")
        $null = $p.Handle
        Cekej $p $popis
        if ($p.ExitCode -ne 0) {
            foreach ($soubor in $vystup, $chyby) {
                if (-not (Test-Path $soubor)) { continue }
                Get-Content $soubor -Tail 6 | Where-Object { $_ -and ($_ -notmatch '^#< CLIXML|^<Objs') } |
                    ForEach-Object { Write-Host "       $_" -ForegroundColor DarkGray }
            }
            throw "Oficiální instalace skončila chybou (kód $($p.ExitCode))."
        }
    } finally {
        Remove-Item $skript, $obal, $vystup, $chyby -Force -ErrorAction SilentlyContinue
    }
}

function Precti-Json($cesta) {
    # Prázdný soubor nebo jiný obsah než objekt bereme jako nečitelné nastavení.
    $obsah = [IO.File]::ReadAllText($cesta) | ConvertFrom-Json
    if ($obsah -isnot [Management.Automation.PSCustomObject]) { throw 'Soubor neobsahuje nastavení.' }
    return $obsah
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
        $verze = & $ClaudeExe --version
        return (($LASTEXITCODE -eq 0) -and ("$verze" -match 'Claude Code'))
    } catch {
        return $false
    }
}

function Jina-Instalace-Funguje {
    # Oficiální instalátor odebere Claude nainstalovaný přes npm, to nesmíme nikomu udělat.
    # Zástupce aplikace ve složce WindowsApps není Claude Code a jeho spuštění by otevřelo okno.
    $prikaz = Get-Command claude -CommandType Application -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -notmatch '\\WindowsApps\\' } | Select-Object -First 1
    if (-not $prikaz) { return $false }
    try {
        $verze = & $prikaz.Source --version
        return (($LASTEXITCODE -eq 0) -and ("$verze" -match 'Claude Code'))
    } catch {
        return $false
    }
}

function Nainstaluj-Claude {
    if (Claude-Funguje) { Hotovo 'Claude Code už v počítači je, instalaci přeskakuji.'; return }
    if ($BezInstalace) { throw 'Claude Code není nainstalovaný a instalace je vypnutá.' }
    # Nefunkční soubor z dřívějška by mohl oficiální instalaci zmást.
    if (Test-Path -LiteralPath $ClaudeExe) { Remove-Item -LiteralPath $ClaudeExe -Force }
    Spust-Oficialni $OficialniInstalator 'claude' 'Stahuji Claude Code z oficiálního webu Anthropic'
    if (-not (Claude-Funguje)) { throw 'Instalace proběhla, ale Claude Code nejde spustit. Může ho blokovat antivirus.' }
    Hotovo 'Claude Code je nainstalovaný.'
}

function Codex-Funguje {
    # Najde funkční Codex a zapamatuje si, kde je.
    $kandidati = @()
    if ($env:LOCALAPPDATA) { $kandidati += Join-Path $env:LOCALAPPDATA 'Programs\OpenAI\Codex\bin\codex.exe' }
    $prikaz = Get-Command codex -CommandType Application -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -notmatch '\\WindowsApps\\' } | Select-Object -First 1
    if ($prikaz) { $kandidati += $prikaz.Source }
    foreach ($soubor in $kandidati) {
        if (-not (Test-Path -LiteralPath $soubor)) { continue }
        try {
            $verze = & $soubor --version
            if (($LASTEXITCODE -eq 0) -and ("$verze" -match 'codex')) {
                $script:CodexSoubor = $soubor
                return $true
            }
        } catch {}
    }
    return $false
}

function Nainstaluj-Codex {
    # Když se Codex nepovede, instalace Claude pokračuje dál.
    # Vrací $true, když Codex v počítači je.
    try {
        if (Codex-Funguje) { Hotovo 'Codex už v počítači je, instalaci přeskakuji.'; return $true }
        if ($BezInstalace) { return $false }
        # Bez tohoto se oficiální instalátor anglicky ptá a na konci by Codex sám spustil.
        $env:CODEX_NON_INTERACTIVE = '1'
        Spust-Oficialni $InstalatorCodexu 'codex' 'Stahuji Codex z oficiálního webu OpenAI'
        if (-not (Codex-Funguje)) { throw 'Codex je stažený, ale nejde spustit. Může ho blokovat antivirus.' }
        Hotovo 'Codex je nainstalovaný.'
        return $true
    } catch {
        Pozor "Codex se nepodařilo nainstalovat. $($_.Exception.Message)"
        Pozor 'Claude to neovlivní, instalace pokračuje.'
        return $false
    }
}

function Nastav-Codex {
    # Codex se nebude ptát na potvrzení, stejně jako Claude. Ostatní nastavení zůstává.
    try {
        $slozka = Join-Path $Domov '.codex'
        if ($env:CODEX_HOME) { $slozka = $env:CODEX_HOME }
        New-Item -ItemType Directory -Force -Path $slozka | Out-Null
        $cesta = Join-Path $slozka 'config.toml'
        $radky = @()
        if (Test-Path $cesta) {
            Copy-Item $cesta "$cesta.zaloha-$Razitko"
            $radky = @([IO.File]::ReadAllLines($cesta))
        }
        # Oba klíče musí být před první sekcí [...], jinak by patřily do ní.
        $prvniSekce = $radky.Count
        for ($i = 0; $i -lt $radky.Count; $i++) {
            if ($radky[$i] -match '^\s*\[') { $prvniSekce = $i; break }
        }
        $hlava = @($radky | Select-Object -First $prvniSekce |
            Where-Object { $_ -notmatch '^\s*(approval_policy|sandbox_mode)\s*=' })
        $zbytek = @($radky | Select-Object -Skip $prvniSekce)
        $nove = @('approval_policy = "never"', 'sandbox_mode = "danger-full-access"') + $hlava
        # Pracovní složka je důvěryhodná, aby se na ni Codex při startu neptal.
        $sekce = "[projects.'$Prace']"
        if (($Prace -notmatch "'") -and ($zbytek -notcontains $sekce)) {
            $zbytek += @('', $sekce, 'trust_level = "trusted"')
        }
        Zapis-Text $cesta ((($nove + $zbytek) -join "`r`n") + "`r`n")
        Hotovo 'Codex se nebude na nic ptát.'
    } catch {
        Pozor 'Nastavení Codexu se nepodařilo zapsat, bude se ptát na potvrzení.'
    }
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
            # Na začátek, aby měl přednost před stejnojmennými zástupci jiných aplikací.
            $novy = ($pridat + $polozky) -join ';'
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
            Pozor 'Staré nastavení nešlo přečíst, je uložené jako záloha a začínám znovu.'
            $nastaveni = New-Object PSObject
        }
    }
    if ($nastaveni.permissions -isnot [Management.Automation.PSCustomObject]) { Nastav $nastaveni 'permissions' (New-Object PSObject) }
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
            $konfigurace = New-Object PSObject
        }
        if ($konfigurace.oauthAccount) { return }
        Copy-Item $cesta "$cesta.zaloha-$Razitko"
    }
    # Bez toho se Claude po startu anglicky ptá, jestli přepnout režim, a předvybrané je Ano.
    Nastav $konfigurace 'hasSeenAutoDefaultNudge' $true
    if (-not $konfigurace.theme) { Nastav $konfigurace 'theme' 'dark' }
    if ($konfigurace.projects -isnot [Management.Automation.PSCustomObject]) { Nastav $konfigurace 'projects' (New-Object PSObject) }
    # Claude hledá důvěru i v nadřazených složkách. Zápis na kořeny disků znamená, že se
    # v žádné nové složce nezeptá. Jinak je předvybrané „No, exit“ a Enter ho vypne.
    # Všechna písmena, aby to platilo i pro flash disk nebo disk připojený později.
    $duveryhodne = @($Prace -replace '\\', '/')
    foreach ($pismeno in [char[]]'CDEFGHIJKLMNOPQRSTUVWXYZ') { $duveryhodne += "${pismeno}:/" }
    foreach ($klic in $duveryhodne) {
        # Existující záznam projektu se jen doplní, Claude si v něm drží i jiné věci.
        $projekt = $konfigurace.projects.PSObject.Properties[$klic]
        if ($projekt -and ($projekt.Value -is [Management.Automation.PSCustomObject])) {
            $projekt = $projekt.Value
        } else {
            $projekt = New-Object PSObject
            Nastav $konfigurace.projects $klic $projekt
        }
        Nastav $projekt 'hasTrustDialogAccepted' $true
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

function Vytvor-Zastupce($nazev, $cil) {
    New-Item -ItemType Directory -Force -Path $Plocha | Out-Null
    $shell = New-Object -ComObject WScript.Shell
    $zastupce = $shell.CreateShortcut((Join-Path $Plocha "$nazev.lnk"))
    $zastupce.TargetPath = $cil
    if ($cil -like '*.exe') { $zastupce.IconLocation = "$cil,0" }
    $zastupce.WorkingDirectory = $Prace
    $zastupce.Description = "Spustit $nazev"
    $zastupce.Save()
    Hotovo "Na ploše je ikona $nazev."
}

try {
    Uvod

    # Dvě instalace naráz by si přepisovaly soubory.
    $Zamek = New-Object Threading.Mutex($false, 'Local\ClaudeCodexJedenKlik')
    $volno = $false
    try { $volno = $Zamek.WaitOne(0) } catch [Threading.AbandonedMutexException] { $volno = $true }
    if (-not $volno) {
        Write-Host ''
        Pozor 'Instalace už běží v jiném okně. Tohle okno můžeš zavřít.'
        exit 0
    }

    if (-not [Environment]::Is64BitOperatingSystem) { throw 'Claude Code i Codex vyžadují 64bitová Windows.' }
    if ([Environment]::OSVersion.Version.Build -lt 17763) {
        throw 'Tahle verze Windows je moc stará. Je potřeba Windows 10 verze 1809 nebo novější.'
    }

    if ((-not (Claude-Funguje)) -and (Jina-Instalace-Funguje)) {
        # Claude nainstalovaný jinou cestou necháváme úplně být, doplní se jen Codex.
        $KrokuCelkem = 2
        Krok 1 'Claude Code'
        Hotovo 'Claude Code už v počítači máš a funguje. Aby se nic nerozbilo, nechávám ho být.'
        Krok 2 'Codex'
        $JeCodex = Nainstaluj-Codex
        if ($JeCodex) { Nastav-Codex }
        Ramecek 'Green' @('HOTOVO')
        Write-Host ''
        Radek 'Claude   v příkazovém řádku napiš: claude'
        if ($JeCodex) { Radek 'Codex    v novém příkazovém řádku napiš: codex' }
        exit 0
    }

    Krok 1 'Claude Code'
    Nainstaluj-Claude

    Krok 2 'Codex'
    $JeCodex = Nainstaluj-Codex
    if ($JeCodex) { Nastav-Codex }
    Pridej-DoPath

    Krok 3 'Nastavení pro začátečníka'
    Nastav-Claude

    Krok 4 'Pracovní složka'
    Priprav-Slozku
    Hotovo "Tvoje práce se bude ukládat do složky $Prace"

    Krok 5 'Ikony a nabídka pravého tlačítka'
    # Ikony ani nabídka nejsou nezbytné, jejich selhání instalaci nezastaví.
    $IkonaClaude = $false
    $IkonaCodex = $false
    try { Vytvor-Zastupce 'Claude' $ClaudeExe; $IkonaClaude = $true } catch {
        Pozor 'Ikonu Claude se nepodařilo vytvořit.'
    }
    if ($JeCodex) {
        try { Vytvor-Zastupce 'Codex' $CodexSoubor; $IkonaCodex = $true } catch {
            Pozor 'Ikonu Codex se nepodařilo vytvořit.'
        }
    }
    try { Pridej-Nabidku } catch {
        Pozor 'Položku v nabídce pravého tlačítka se nepodařilo přidat.'
    }

    Ramecek 'Green' @('HOTOVO')
    Write-Host ''
    $jak = 'v příkazovém řádku napiš:'
    if ($IkonaClaude) { Radek "Claude   ikona na ploše, nebo $jak claude" } else { Radek "Claude   $jak claude" }
    if ($IkonaCodex) { Radek "Codex    ikona na ploše, nebo $jak codex" } elseif ($JeCodex) { Radek "Codex    $jak codex" }
    Radek "Složka   $Prace"
    Write-Host ''
    if ($JeCodex) {
        Radek 'Oba pracují bez ptaní: co jim napíšeš, to rovnou udělají.'
        Radek 'Při prvním spuštění se zeptají na přihlášení. Přihlas se svým účtem.'
    } else {
        Radek 'Claude pracuje bez ptaní: co mu napíšeš, to rovnou udělá.'
        Radek 'Při prvním spuštění se zeptá na přihlášení. Přihlas se svým účtem.'
    }
    Radek 'Vlastní složka: klikni na ni pravým tlačítkem a otevři příkazový řádek.'
    Write-Host ''
    Write-Host '     Teď se otevře okno Claude. Přihlas se a piš obyčejně česky, co potřebuješ.' -ForegroundColor Yellow

    if (-not $BezSpusteni) {
        Start-Process -FilePath $ClaudeExe -WorkingDirectory $Prace
    }
    exit 0
} catch {
    Ramecek 'Red' @('INSTALACE SE NEPOVEDLA')
    Write-Host ''
    Write-Host "     $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ''
    Radek 'Vyfoť tuhle obrazovku a pošli ji tomu, kdo ti instalaci poslal.'
    exit 1
}
