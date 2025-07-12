Config = {}

-- Debug-Modus: true = detaillierte Log-Ausgaben in Server- und Client-Konsole, false = aus
Config.Debug = true

-- Befehl zum Öffnen des FFA-Menüs in der UI
Config.CommandName = "ffa"

-- Respawn-Verzögerung in Millisekunden, nachdem ein Spieler im FFA gestorben ist
Config.RespawnDelay = 3000 -- Entspricht 3 Sekunden (wird in server/server.lua verwendet)

-- Standard Routing Bucket, in den Spieler zurückgesetzt werden, wenn sie ein FFA verlassen.
-- 0 ist normalerweise die Haupt-Spielwelt-Dimension.
Config.DefaultRoutingBucket = 0

-- [[ Map-Definitionen ]]
-- Jede Map ist ein Table-Eintrag in Config.Maps
-- Attribute pro Map:
--   id: Eindeutige String-ID für die Map (wird intern verwendet).
--   displayName: Angezeigter Name in der UI.
--   description: Kurze Beschreibung in der UI.
--   thumbnail: URL zu einem Vorschaubild für die UI (z.B. "https://via.placeholder.com/150/FF8C00/FFFFFF?Text=MapName").
--   maxPlayers: Maximale Anzahl an Spielern, die dieser Map/Lobby beitreten können.
--   spawnPoints: Eine Liste von Koordinaten {x, y, z} für mögliche Spawnpunkte. Mindestens einer ist erforderlich.
--   weapons: Eine Liste von Waffen {hash = 'WAFFEN_HASH', ammo = MUNITIONSMENGE}, die das Loadout definieren.
--   boundaries: Definiert die Kampfzone.
--     min: {x, y, z} für die minimale Ecke der Zone.
--     max: {x, y, z} für die maximale Ecke der Zone.
Config.Maps = {
    {
        id = "construction_site",
        displayName = "Baustelle",
        description = "Ein hektisches Gefecht auf der alten Baustelle. Gut für kurze Distanzen.",
        thumbnail = "https://via.placeholder.com/150/FF8C00/FFFFFF?Text=Baustelle",
        maxPlayers = 16,
        spawnPoints = {
            { x = 1100.0, y = -1500.0, z = 35.0 },
            { x = 1120.0, y = -1510.0, z = 35.0 },
            { x = 1140.0, y = -1505.0, z = 35.0 },
            { x = 1080.0, y = -1480.0, z = 35.0 },
        },
        weapons = {
            -- Ox Inventory Item-Namen verwenden!
            { name = 'weapon_pumpshotgun', ammo = 60 },
            { name = 'weapon_pistol', ammo = 120 },
        },
        boundaries = {
            min = { x = 1050.0, y = -1550.0, z = 30.0 }, -- Untere süd-westliche Ecke
            max = { x = 1180.0, y = -1450.0, z = 55.0 }  -- Obere nord-östliche Ecke
        }
    },
    {
        id = "aircraft_carrier",
        displayName = "Flugzeugträger",
        description = "Kämpfe um die Vorherrschaft auf dem Deck eines massiven Flugzeugträgers. Weite Sichtlinien.",
        thumbnail = "https://via.placeholder.com/150/4682B4/FFFFFF?Text=Flugzeugtr%C3%A4ger",
        maxPlayers = 24,
        spawnPoints = {
            { x = 3076.88, y = -4700.08, z = 15.20 },
            { x = 3096.88, y = -4710.08, z = 15.20 },
            { x = 3070.88, y = -4720.08, z = 15.20 },
            { x = 3050.00, y = -4690.00, z = 15.20 },
        },
        weapons = {
            { name = 'weapon_assaultrifle', ammo = 240 },
            { name = 'weapon_sniperrifle', ammo = 40 },
            { name = 'weapon_combatpistol', ammo = 90 },
        },
        boundaries = {
            min = { x = 3000.0, y = -4750.0, z = 10.0 },
            max = { x = 3150.0, y = -4650.0, z = 25.0 }
        }
    },
    {
        id = "sandy_shores_motel",
        displayName = "Sandy Shores Motel",
        description = "Ein schnelles Gefecht im und um das verlassene Motel. CQB-Action.",
        thumbnail = "https://via.placeholder.com/150/DEB887/000000?Text=Sandy+Shores",
        maxPlayers = 12,
        spawnPoints = {
            { x = 180.0, y = 2950.0, z = 45.5 },
            { x = 190.0, y = 2960.0, z = 45.5 },
            { x = 170.0, y = 2955.0, z = 45.5 },
            { x = 200.0, y = 2945.0, z = 45.5 },
        },
        weapons = {
            { name = 'weapon_smg', ammo = 200 },
            { name = 'weapon_sawnoffshotgun', ammo = 50 },
        },
        boundaries = {
            min = { x = 150.0, y = 2900.0, z = 40.0 },
            max = { x = 220.0, y = 2990.0, z = 55.0 }
        }
    }
}

-- Hier könnten weitere allgemeine Konfigurationen für das FFA-Skript folgen.
-- z.B. Minimale Spieleranzahl um ein Match zu starten (aktuell nicht implementiert, startet mit 1 Spieler)
-- Config.MinPlayersToStartFFA = 2
