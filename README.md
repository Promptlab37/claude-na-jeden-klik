# Claude na jeden klik

Nainstaluje [Claude Code](https://code.claude.com/docs) do Windows a nastaví ho tak, aby s ním mohl pracovat i člověk, který příkazovému řádku vůbec nerozumí.

## Co potřebuješ

- Windows 10 nebo 11 (64bitová verze)
- internet
- placený účet Claude (Pro nebo vyšší), bezplatný účet Claude Code nezahrnuje

## Instalace

1. **[Stáhni soubor Instalovat-Claude.bat](https://github.com/Promptlab37/claude-na-jeden-klik/releases/latest/download/Instalovat-Claude.bat)**
2. Dvakrát na něj klikni.
3. Když Windows napíše „Systém Windows ochránil váš počítač“, klikni na **Další informace** a pak na **Přesto spustit**.
4. V prohlížeči se přihlas svým účtem Claude a vrať se do okna instalace.

Pak už jen napiš obyčejně česky, co potřebuješ. Příště Claude spustíš ikonou **Claude** na ploše.

## Dobré vědět

**Claude se na nic neptá.** Je to tak nastavené záměrně (`bypassPermissions`), takže co mu napíšeš, to rovnou udělá, včetně práce se soubory a programy v počítači. Proto:

- Dej mu přesné zadání a důležité soubory si zálohuj.
- Nepoužívej ho na firemním počítači ani na počítači s citlivými daty, pokud to nemáš povolené.
- Nenechávej ho zpracovávat weby a soubory, kterým nevěříš. Může se v nich schovávat škodlivý pokyn a tady ho nikdo nepotvrzuje. Oficiální dokumentace tento režim doporučuje jen pro izolované prostředí.

Chceš, aby se Claude ptal? V okně Claude stiskni `Shift+Tab`, nebo v souboru `.claude\settings.json` změň `defaultMode` na `auto`.

## Co instalátor dělá

| Krok | Co se změní |
|---|---|
| Instalace | Spustí [oficiální instalátor Anthropicu](https://claude.ai/install.ps1). Práva správce nepotřebuje. |
| PATH | Přidá `%USERPROFILE%\.local\bin` do proměnné PATH uživatele. |
| Nastavení | Do `.claude\settings.json` zapíše režim bez ptaní, češtinu a pár zákazů (například formátování disku). Zbytek nastavení nechá a udělá zálohu. |
| Pokyny | Vytvoří `.claude\CLAUDE.md` s pokyny pro práci se začátečníkem, pokud tam ještě žádné nejsou. |
| První spuštění | V `.claude.json` přeskočí úvodní volby a označí pracovní složku jako důvěryhodnou. Pokud už jsi v Claude přihlášený, tento soubor nemění. |
| Složka a ikona | Vytvoří složku `%USERPROFILE%\Claude` a ikonu na ploše. |

Zákazy jsou jen základní pojistka proti běžnému tvaru příkazu, nejsou to bezpečnostní hranice.

## Odinstalace

Oficiální postup je v [dokumentaci](https://code.claude.com/docs/en/setup). Ikonu a složku `Claude` pak můžeš smazat ručně.

## Licence

MIT
