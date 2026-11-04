# Claude na jeden klik

Nainstaluje [Claude Code](https://code.claude.com/docs) do Windows a nastaví ho tak, aby s ním mohl pracovat i člověk, který příkazovému řádku vůbec nerozumí.

## Co potřebuješ

- Windows 10 verze 1809 nebo novější, případně Windows 11 (64bitová verze)
- internet
- placený účet Claude (Pro nebo vyšší), bezplatný účet Claude Code nezahrnuje

## Instalace

1. **[Stáhni soubor Instalovat-Claude.bat](https://github.com/Promptlab37/claude-na-jeden-klik/releases/latest/download/Instalovat-Claude.bat)**
2. Dvakrát na něj klikni.
3. Když Windows napíše „Systém Windows ochránil váš počítač“, klikni na **Další informace** a pak na **Přesto spustit**.
4. V prohlížeči se přihlas svým účtem Claude a vrať se do okna instalace.

Když soubor nejde spustit (například ho zablokuje antivirus), otevři nabídku Start, napiš `PowerShell`, otevři ho a vlož tento řádek:

```powershell
irm https://raw.githubusercontent.com/Promptlab37/claude-na-jeden-klik/main/install.ps1 -OutFile "$env:TEMP\claude-instalace.ps1"; & "$PSHOME\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\claude-instalace.ps1"
```

Pak už jen napiš obyčejně česky, co potřebuješ. Příště Claude spustíš ikonou **Claude** na ploše.

## Práce ve vlastní složce

1. Založ si novou složku, kde chceš něco stavět.
2. Klikni na ni pravým tlačítkem a zvol **Otevřít v příkazovém řádku**. Ve Windows 11 ji najdeš pod **Zobrazit další možnosti**, nebo rovnou zvol **Otevřít v terminálu**.
3. Napiš `claude` a stiskni Enter.

## Dobré vědět

**Claude se na nic neptá.** Je to tak nastavené záměrně (`bypassPermissions`), takže co mu napíšeš, to rovnou udělá, včetně práce se soubory a programy v počítači. Proto:

- Dej mu přesné zadání a důležité soubory si zálohuj.
- Nepoužívej ho na firemním počítači ani na počítači s citlivými daty, pokud to nemáš povolené.
- Nenechávej ho zpracovávat weby a soubory, kterým nevěříš. Může se v nich schovávat škodlivý pokyn a tady ho nikdo nepotvrzuje. Oficiální dokumentace tento režim doporučuje jen pro izolované prostředí.
- Nespouštěj ho ve složkách stažených z neznámých zdrojů ani na cizím flash disku. Dotaz na důvěru složky je vypnutý pro všechny disky a nastavení v takové složce by se mohlo rovnou načíst a spustit.

Chceš, aby se Claude ptal? V okně Claude stiskni `Shift+Tab`, nebo v souboru `.claude\settings.json` změň `defaultMode` na `auto`.

## Co instalátor dělá

| Krok | Co se změní |
|---|---|
| Instalace | Spustí [oficiální instalátor Anthropicu](https://claude.ai/install.ps1), pokud v `.local\bin` ještě funkční Claude není. Práva správce nepotřebuje. |
| PATH | Přidá `%USERPROFILE%\.local\bin` do proměnné PATH uživatele. Když v počítači v PATH chybí systémové složky Windows, doplní je tam také. |
| Nastavení | Do `.claude\settings.json` zapíše režim bez ptaní, češtinu a pár zákazů (například formátování disku). Zbytek nastavení nechá a udělá zálohu. |
| Pokyny | Vytvoří `.claude\CLAUDE.md` s pokyny pro práci se začátečníkem, pokud tam ještě žádné nejsou. |
| První spuštění | V `.claude.json` přeskočí úvodní volby a označí pracovní složku i kořeny všech disků jako důvěryhodné. Pokud už jsi v Claude přihlášený, tento soubor nemění. |
| Složka a ikona | Vytvoří složku `Claude` v Dokumentech a ikonu na ploše. Claude se otevírá v této složce. |
| Pravé tlačítko | Přidá do nabídky složek položku „Otevřít v příkazovém řádku“ (klíč `ClaudePrikazovyRadek` v `HKCU\Software\Classes`). |
| Přihlášení | Otevře přihlášení přes předplatné Claude. API klíč vypne jen pro Claude (prázdná hodnota v `settings.json`), jiným programům zůstane. Přihlášení přes placené API nahradí předplatným. Účet bez předplatného instalátor ohlásí. |

Zákazy jsou jen základní pojistka proti běžnému tvaru příkazu, nejsou to bezpečnostní hranice.

## Odinstalace

Oficiální postup je v [dokumentaci](https://code.claude.com/docs/en/setup). Ikonu a složku `Claude` pak můžeš smazat ručně. Položku z nabídky pravého tlačítka odstraníš v příkazovém řádku:

```
reg delete "HKCU\Software\Classes\Directory\shell\ClaudePrikazovyRadek" /f
reg delete "HKCU\Software\Classes\Directory\Background\shell\ClaudePrikazovyRadek" /f
```

## Licence

MIT
