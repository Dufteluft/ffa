# FiveM FFA Script mit ESX Integration

Dieses Skript implementiert einen Free-For-All (FFA) Spielmodus für FiveM Server mit ESX Integration. Spieler können über ein UI-Menü verschiedenen FFA-Arenen beitreten, erhalten map-spezifische Waffen-Loadouts und respawnen nach ihrem Tod automatisch innerhalb der Arena.

## Features

*   ESX-Integration
*   UI-Menü zum Auswählen von FFA-Arenen (Standardbefehl: `/ffa`)
*   Unterstützung für mehrere FFA-Maps
    *   Map-spezifische Spawn-Punkte
    *   Map-spezifische Waffen-Loadouts
    *   Map-spezifische Grenzen (Bubble-System)
*   Lobby-System (Spieler treten einer Lobby bei, die dann zum Match wird)
*   Automatisches Respawn-System
    *   Volles Leben und Rüstung beim Respawn
    *   Automatisches Erhalten des Waffen-Loadouts beim Respawn
    *   Respawn an zufälligen Punkten der aktuellen Map
*   Isolierung der FFA-Kämpfe durch Routing Buckets (Dimensionen)
*   Debug-Modus für detaillierte Server- und Client-Konsolenausgaben

## Installation

1.  **Download:** Lade das Skript herunter (oder klone das Repository).
2.  **Ordnerstruktur:** Stelle sicher, dass der Ordner den Namen `ffa_script` hat (oder passe den Ressourcennamen entsprechend an). Platziere diesen Ordner in deinem `resources`-Verzeichnis auf dem FiveM-Server.
3.  **Abhängigkeiten:**
    *   Stelle sicher, dass `es_extended` (ESX) auf deinem Server installiert ist und korrekt funktioniert. Die Abhängigkeit ist in der `fxmanifest.lua` deklariert.
4.  **Server-Konfiguration:** Füge `ensure ffa_script` zu deiner `server.cfg` hinzu. Es wird empfohlen, es *nach* `es_extended` und anderen Kern-ESX-Ressourcen zu starten.

## Konfiguration

Die Hauptkonfiguration des Skripts erfolgt in der Datei `shared/config.lua`.

### `Config.Debug`
*   Typ: `boolean`
*   Beschreibung: Schaltet detaillierte Debug-Ausgaben in der Server- und Client-Konsole ein (`true`) oder aus (`false`).
*   Standard: `true`

### `Config.CommandName`
*   Typ: `string`
*   Beschreibung: Definiert den Chat-Befehl zum Öffnen des FFA-Menüs.
*   Standard: `"ffa"`

### `Config.Maps`
*   Typ: `table` (Array von Map-Objekten)
*   Beschreibung: Definiert die verfügbaren FFA-Maps. Jede Map ist ein Objekt mit folgenden Eigenschaften:
    *   `id` (string): Eine eindeutige ID für die Map (z.B. `"construction_site"`).
    *   `displayName` (string): Der Name der Map, wie er in der UI angezeigt wird (z.B. `"Baustelle"`).
    *   `description` (string): Eine kurze Beschreibung der Map für die UI.
    *   `thumbnail` (string): URL zu einem Vorschaubild für die Map (empfohlene Größe ca. 150x100 Pixel). Platzhalter können verwendet werden (z.B. von `https://via.placeholder.com`).
    *   `maxPlayers` (integer): Maximale Anzahl an Spielern für diese Map-Lobby.
    *   `spawnPoints` (table): Eine Liste von Koordinaten-Objekten, die mögliche Spawnpunkte definieren.
        *   Beispiel: `{ { x = 100.0, y = 200.0, z = 30.0 }, ... }`
        *   **Wichtig:** Es muss mindestens ein Spawnpunkt definiert sein, damit die Map funktioniert.
    *   `weapons` (table): Eine Liste von Waffen-Objekten, die das Loadout für diese Map definieren.
        *   `hash` (string): Der Hash-Name der Waffe (z.B. `'WEAPON_PISTOL'`). Eine Liste von Waffen-Hashes findet man in der FiveM-Dokumentation.
        *   `ammo` (integer): Die Menge an Munition für diese Waffe.
        *   Beispiel: `{ { hash = 'WEAPON_PISTOL', ammo = 100 }, ... }`
    *   `boundaries` (table): Definiert die Grenzen der Kampfzone (Bubble). Spieler außerhalb dieser Grenzen werden gewarnt.
        *   `min` (table): Koordinaten-Objekt für die minimale Ecke der Box (`{ x, y, z }`).
        *   `max` (table): Koordinaten-Objekt für die maximale Ecke der Box (`{ x, y, z }`).
        *   Beispiel: `boundaries = { min = { x = 0.0, y = 0.0, z = 0.0 }, max = { x = 100.0, y = 100.0, z = 30.0 } }`
        *   **Wichtig:** Die Z-Achse ist ebenfalls relevant. Stelle sicher, dass die Grenzen hoch und tief genug sind.

**Beispiel für eine Map-Definition in `Config.Maps`:**
```lua
{
    id = "example_map",
    displayName = "Beispiel Map",
    description = "Eine kleine Testarena.",
    thumbnail = "https://via.placeholder.com/150/007bff/FFFFFF?Text=Beispiel",
    maxPlayers = 8,
    spawnPoints = {
        { x = 10.0, y = 10.0, z = 5.0 },
        { x = 20.0, y = 20.0, z = 5.0 }
    },
    weapons = {
        { hash = 'WEAPON_COMBATPISTOL', ammo = 120 },
        { hash = 'WEAPON_MICROSMG', ammo = 200 }
    },
    boundaries = {
        min = { x = 0.0, y = 0.0, z = 0.0 },
        max = { x = 50.0, y = 50.0, z = 20.0 }
    }
}
```

## Nutzung

1.  Starte das Skript auf deinem Server.
2.  Im Spiel: Gib den konfigurierten Befehl (standardmäßig `/ffa`) in den Chat ein, um das Auswahlmenü zu öffnen.
3.  Wähle eine Map aus der Liste und klicke auf "Lobby beitreten".
4.  Du wirst automatisch in die Arena teleportiert und erhältst das Waffen-Loadout.
5.  Kämpfe! Wenn du stirbst, respawnst du nach einer kurzen Verzögerung automatisch.
6.  Um das FFA zu verlassen, öffne das Menü erneut und klicke auf "Lobby verlassen" (falls in der Lobby-Ansicht) oder verlasse die Lobby über die UI-Optionen, die das Skript später ggf. bietet, oder durch erneutes Ausführen des Befehls, um das Menü zu schließen und die Lobby zu verlassen (wenn der Spieler in einer Lobby ist und das Menü schließt, sollte er die Lobby verlassen).

## Bekannte Probleme / Zukünftige Verbesserungen

*   **Erweiterte Lobby-Funktionen:** Countdown zum Match-Start, expliziter Start-Button für Admins, Anzeige von Wartezeiten.
*   **Match-Ende Bedingungen:** Zeitlimit, Kill-Limit, Runden.
*   **Punktesystem/Scoreboard:** Anzeige von Kills/Deaths.
*   **Team-FFA:** Möglichkeit für Team-basierte FFA-Modi.
*   **UI-Verbesserungen:** Visuell ansprechenderes Design, mehr Interaktionsmöglichkeiten.
*   **Flexiblere Bubble-Systeme:** Zylinderförmige Grenzen, dynamische Grenzen.
*   **Konfigurierbare Respawn-Verzögerung.**

Viel Spaß!
```
