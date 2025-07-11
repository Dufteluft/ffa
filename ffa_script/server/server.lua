ESX = exports["es_extended"]:getSharedObject()

-- Hilfsfunktion für Debug-Nachrichten auf dem Server
local function DebugPrint(msg)
    if Config.Debug then
        print('[FFA_SCRIPT][SERVER] ' .. msg)
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        -- ESX sollte jetzt direkt initialisiert sein, wenn es_extended vorher gestartet wurde.
        -- Eine zusätzliche Prüfung kann nicht schaden, ist aber weniger kritisch als bei der Event-Methode.
        if ESX ~= nil then
            DebugPrint("ESX Shared Object erfolgreich geladen (via export).")
            -- Hier könnten weitere Initialisierungen für den Server stattfinden
        else
            DebugPrint("ESX Shared Object konnte NICHT geladen werden (via export). Stelle sicher, dass es_extended gestartet ist UND exports korrekt definiert sind.")
        end
        DebugPrint("FFA Script Server-Seite gestartet.")
    end
end)

-- Hier wird später die Logik für FFA-Matches, Spieler-Synchronisation etc. implementiert

local activeLobbies = {} -- mapId = { players = {playerId = ESXPlayerObject, ...}, mapDetails = Config.Map }
local playerLobbyMap = {} -- playerId = mapId

-- Hilfsfunktion, um eine Map-Konfiguration anhand der ID zu finden
local function getMapConfigById(mapId)
    for _, mapConfig in ipairs(Config.Maps) do
        if mapConfig.id == mapId then
            return mapConfig
        end
    end
    return nil
end

-- Event Handler für Client-Anfrage zum Beitreten einer Lobby
RegisterNetEvent('ffa:joinLobby')
AddEventHandler('ffa:joinLobby', function(mapId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then
        DebugPrint("Spieler " .. src .. " nicht gefunden beim Versuch, Lobby beizutreten.")
        return
    end

    -- Prüfen, ob Spieler bereits in einer Lobby ist
    if playerLobbyMap[src] then
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") ist bereits in Lobby: " .. playerLobbyMap[src] .. ". Verlässt alte Lobby zuerst.")
        -- Implementiere hier ggf. automatisches Verlassen oder eine Fehlermeldung
        -- Vorerst: Einfach die alte Lobby verlassen
        TriggerEvent('ffa:leaveLobby', playerLobbyMap[src], src) -- Annahme: ffa:leaveLobby kann auch intern getriggert werden
    end

    local mapConfig = getMapConfigById(mapId)
    if not mapConfig then
        DebugPrint("Ungültige Map-ID " .. mapId .. " von Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") empfangen.")
        -- TODO: Benachrichtigung an Client senden
        return
    end

    -- Lobby erstellen, falls nicht vorhanden
    if not activeLobbies[mapId] then
        activeLobbies[mapId] = {
            players = {},
            mapDetails = mapConfig,
            playerCount = 0
        }
        DebugPrint("Lobby für Map '" .. mapConfig.displayName .. "' (ID: " .. mapId .. ") erstellt.")
    end

    -- Prüfen, ob Lobby voll ist
    if activeLobbies[mapId].playerCount >= mapConfig.maxPlayers then
        DebugPrint("Lobby für Map '" .. mapConfig.displayName .. "' ist voll. Spieler " .. xPlayer.getName() .. " kann nicht beitreten.")
        xPlayer.showNotification("Die Lobby für " .. mapConfig.displayName .. " ist bereits voll.")
        return
    end

    -- Spieler zur Lobby hinzufügen
    activeLobbies[mapId].players[src] = xPlayer
    activeLobbies[mapId].playerCount = activeLobbies[mapId].playerCount + 1
    playerLobbyMap[src] = mapId

    DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") ist Lobby für Map '" .. mapConfig.displayName .. "' beigetreten. Spieler in Lobby: " .. activeLobbies[mapId].playerCount)
    xPlayer.showNotification("Du bist der Lobby für " .. mapConfig.displayName .. " beigetreten.")

    -- Alle Spieler in der Lobby (und ggf. alle Clients mit offener UI) über die Änderung informieren
    TriggerClientEvent('ffa:updateLobbyView', -1, mapId, activeLobbies[mapId].players, activeLobbies[mapId].playerCount)

    -- FFA-Logik: Spieler ins Match überführen
    if not mapConfig.spawnPoints or #mapConfig.spawnPoints == 0 then
        DebugPrint("FEHLER: Keine Spawnpunkte für Map " .. mapId .. " definiert! Spieler kann nicht teleportiert werden.")
        xPlayer.showNotification("Fehler: Für diese Map sind keine Spawnpunkte konfiguriert.")
        -- Spieler evtl. aus Lobby entfernen oder andere Fehlerbehandlung
        TriggerEvent('ffa:leaveLobby', mapId, src)
        return
    end
    local spawnPoints = mapConfig.spawnPoints
    local randomSpawn = spawnPoints[math.random(1, #spawnPoints)]

    -- Routing Bucket / Dimension setzen (einfache Methode, Map-Index als Bucket)
    local mapIndex = 0
    for i, m in ipairs(Config.Maps) do
        if m.id == mapId then
            mapIndex = i
            break
        end
    end
    local routingBucket = 5000 + mapIndex -- Eindeutiger Bucket pro Map, um Kollisionen zu vermeiden
    SetPlayerRoutingBucket(src, routingBucket)

    DebugPrint("Versuche Spieler " .. xPlayer.getName() .. " zu teleportieren. randomSpawn Tabelle: " .. json.encode(randomSpawn))
    if randomSpawn and randomSpawn.x and randomSpawn.y and randomSpawn.z then
        local newX, newY, newZ = tonumber(randomSpawn.x), tonumber(randomSpawn.y), tonumber(randomSpawn.z)
        if newX and newY and newZ then
            xPlayer.setCoords(newX, newY, newZ)
            DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") zu Spawn (" .. newX .. "," .. newY .. "," .. newZ .. ") teleportiert und Routing Bucket auf " .. routingBucket .. " gesetzt.")
        else
            DebugPrint("FEHLER: Konnte Koordinaten nicht in Zahlen umwandeln für Spieler " .. xPlayer.getName() .. ". x="..tostring(randomSpawn.x)..", y="..tostring(randomSpawn.y)..", z="..tostring(randomSpawn.z))
            xPlayer.showNotification("Fehler: Ungültige Spawnpunkt-Koordinaten für diese Map.")
            TriggerEvent('ffa:leaveLobby', mapId, src)
            return
        end
    else
        DebugPrint("FEHLER: randomSpawn oder dessen Koordinaten sind nil für Spieler " .. xPlayer.getName() .. ". randomSpawn: " .. json.encode(randomSpawn))
        xPlayer.showNotification("Fehler: Kritischer Fehler bei Spawnpunkt-Definition.")
        TriggerEvent('ffa:leaveLobby', mapId, src)
        return
    end

    GivePlayerMapLoadout(src, mapId) -- Waffen geben
    RegisterPlayerToFFA(src, mapId) -- Für Respawn-System und serverseitigen Status registrieren
    xPlayer.setHealth(GetPedMaxHealth(xPlayer.getPed())) -- Volle Gesundheit
    xPlayer.setArmour(100) -- Volle Rüstung

    TriggerClientEvent('ffa:playerJoinedMatch', src, mapId) -- Client benachrichtigen, dass er im Match ist (für Bubble etc.)
    DebugPrint("FFA-Match für Spieler " .. xPlayer.getName() .. " auf Map " .. mapConfig.displayName .. " gestartet/beigetreten.")
end)

-- Event Handler für Client-Anfrage zum Verlassen einer Lobby
RegisterNetEvent('ffa:leaveLobby')
AddEventHandler('ffa:leaveLobby', function(customMapId, customSrc)
    local src = customSrc or source -- Ermöglicht internen Aufruf
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then
        DebugPrint("Spieler " .. src .. " nicht gefunden beim Versuch, Lobby zu verlassen.")
        return
    end

    local mapId = customMapId or playerLobbyMap[src]

    if not mapId or not activeLobbies[mapId] or not activeLobbies[mapId].players[src] then
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") ist in keiner Lobby oder Lobby existiert nicht zum Verlassen (MapID: " .. tostring(mapId) .. ").")
        -- xPlayer.showNotification("Du bist in keiner Lobby, die du verlassen könntest.") -- Kann störend sein, wenn intern aufgerufen
        return
    end

    local mapDisplayName = activeLobbies[mapId].mapDetails.displayName

    -- Spieler aus Lobby entfernen
    activeLobbies[mapId].players[src] = nil
    activeLobbies[mapId].playerCount = activeLobbies[mapId].playerCount - 1
    playerLobbyMap[src] = nil

    DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") hat Lobby für Map '" .. mapDisplayName .. "' verlassen. Spieler in Lobby: " .. activeLobbies[mapId].playerCount)
    xPlayer.showNotification("Du hast die Lobby für " .. mapDisplayName .. " verlassen.")

    -- Wenn Lobby leer ist, kann sie aufgelöst werden (optional, oder einfach leer lassen)
    if activeLobbies[mapId].playerCount == 0 then
        DebugPrint("Lobby für Map '" .. mapDisplayName .. "' (ID: " .. mapId .. ") ist leer und wird aufgelöst.")
        activeLobbies[mapId] = nil
    end

    -- Alle Spieler (und ggf. alle Clients mit offener UI) über die Änderung informieren
    -- Sende auch die MapID, damit Clients wissen, welche Lobby aktualisiert wurde
    TriggerClientEvent('ffa:updateLobbyView', -1, mapId, activeLobbies[mapId] and activeLobbies[mapId].players or {}, activeLobbies[mapId] and activeLobbies[mapId].playerCount or 0)
end)

-- Spieler beim Verlassen des Servers aus Lobbys entfernen
-- Spieler beim Verlassen des Servers aus Lobbys und FFA entfernen
AddEventHandler('esx:playerDropped', function(playerId, reason)
    local currentMapId = playerLobbyMap[playerId]

    DebugPrint("Spieler (ID: " .. playerId .. ") hat Server verlassen. Grund: " .. reason .. ". Map-ID aus Lobby: " .. tostring(currentMapId))

    if currentMapId then
        local lobby = activeLobbies[currentMapId]
        if lobby and lobby.players[playerId] then
            lobby.players[playerId] = nil
            lobby.playerCount = lobby.playerCount - 1

            local mapDisplayName = lobby.mapDetails.displayName
            DebugPrint("Spieler (ID: " .. playerId .. ") aus Lobby für Map '" .. mapDisplayName .. "' entfernt (Disconnect). Spieler in Lobby: " .. lobby.playerCount)

            if lobby.playerCount == 0 then
                DebugPrint("Lobby für Map '" .. mapDisplayName .. "' (ID: " .. currentMapId .. ") ist leer und wird nach Disconnect aufgelöst.")
                activeLobbies[currentMapId] = nil
            end
            -- Informiere verbleibende Clients über die Änderung in der Lobby
            TriggerClientEvent('ffa:updateLobbyView', -1, currentMapId, lobby and lobby.players or {}, lobby and lobby.playerCount or 0)
        end
        playerLobbyMap[playerId] = nil -- Aus der Zuordnung Spieler -> Lobby entfernen
    end

    UnregisterPlayerFromFFA(playerId) -- Aus dem FFA-Status entfernen (wichtig!)
end)

-- Funktion zum Geben des Waffen-Loadouts für eine bestimmte Map
function GivePlayerMapLoadout(playerId, mapId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then
        DebugPrint("Loadout: Spieler " .. playerId .. " nicht gefunden.")
        return
    end

    local mapConfig = getMapConfigById(mapId)
    if not mapConfig or not mapConfig.weapons then
        DebugPrint("Loadout: Map-Konfiguration oder Waffen für MapID " .. mapId .. " nicht gefunden.")
        return
    end

    -- Alle aktuellen Waffen entfernen
    xPlayer.removeAllWeapons()
    DebugPrint("Loadout: Alle Waffen von Spieler " .. xPlayer.getName() .. " (ID: " .. playerId .. ") entfernt.")

    -- Definierte Waffen geben
    for _, weaponData in ipairs(mapConfig.weapons) do
        if weaponData.hash and weaponData.ammo then
            xPlayer.addWeapon(weaponData.hash, weaponData.ammo)
            DebugPrint("Loadout: Spieler " .. xPlayer.getName() .. " erhielt Waffe " .. weaponData.hash .. " mit " .. weaponData.ammo .. " Munition.")
        else
            DebugPrint("Loadout: Ungültige Waffendaten für MapID " .. mapId .. ": Hash=" .. tostring(weaponData.hash) .. ", Ammo=" .. tostring(weaponData.ammo))
        end
    end

    -- Standard-Komponenten oder spezifische Komponenten könnten hier auch hinzugefügt werden
    -- xPlayer.addWeaponComponent('WEAPON_PISTOL', GetComponentHash('COMPONENT_AT_PI_FLSH'))

    xPlayer.showNotification("Du hast das Waffen-Loadout für '" .. mapConfig.displayName .. "' erhalten.")
    DebugPrint("Loadout: Waffen-Loadout für Map '" .. mapConfig.displayName .. "' an Spieler " .. xPlayer.getName() .. " (ID: " .. playerId .. ") vergeben.")
end

-- [[
-- Beispielhafter Aufruf (wird später in der FFA-Logik verwendet):
-- GivePlayerMapLoadout(source, "construction_site")
-- ]]

local playerFFAState = {} -- playerId = { mapId = "map_id", isDead = false }

-- Wird aufgerufen, wenn ein Spieler einem FFA-Match beitritt (später von der FFA-Logik)
function RegisterPlayerToFFA(playerId, mapId)
    playerFFAState[playerId] = { mapId = mapId, isDead = false }
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer then
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. playerId .. ") für FFA auf Map " .. mapId .. " registriert.")
    end
end

-- Wird aufgerufen, wenn ein Spieler ein FFA-Match verlässt (später von der FFA-Logik)
function UnregisterPlayerFromFFA(playerId)
    if playerFFAState[playerId] then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. playerId .. ") aus FFA deregistriert.")
        end
        playerFFAState[playerId] = nil
    end
end

-- Event vom Client, wenn ein Spieler im FFA stirbt
RegisterNetEvent('ffa:playerDiedInMatch')
AddEventHandler('ffa:playerDiedInMatch', function(killerId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then return end
    if not playerFFAState[src] or playerFFAState[src].isDead then
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") starb, aber nicht im FFA-Match registriert oder bereits als tot markiert.")
        return
    end

    playerFFAState[src].isDead = true
    local mapId = playerFFAState[src].mapId
    local mapConfig = getMapConfigById(mapId)

    if not mapConfig then
        DebugPrint("Konnte Map-Konfiguration für " .. mapId .. " beim Tod von Spieler " .. xPlayer.getName() .. " nicht finden.")
        return
    end

    DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") starb in FFA auf Map " .. mapConfig.displayName .. ". Killer-ID: " .. tostring(killerId))
    -- Hier könnte man Kill-Logik, Punktvergabe etc. einfügen

    Citizen.CreateThread(function()
        Wait(3000) -- Respawn-Verzögerung

        if not playerFFAState[src] then -- Überprüfen, ob der Spieler das FFA in der Zwischenzeit verlassen hat
            DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") hat FFA verlassen, bevor Respawn ausgeführt wurde.")
            return
        end
        if not ESX.GetPlayerFromId(src) then -- Überprüfen, ob der Spieler offline gegangen ist
            DebugPrint("Spieler " .. src .. " ist offline, bevor Respawn ausgeführt wurde.")
            UnregisterPlayerFromFFA(src) -- Aufräumen
            return
        end


        -- Spieler respawnen
        if not mapConfig.spawnPoints or #mapConfig.spawnPoints == 0 then
            DebugPrint("FEHLER: Keine Spawnpunkte für Map " .. mapId .. " definiert! Spieler kann nicht respawned werden.")
            xPlayer.showNotification("Fehler: Für diese Map sind keine Spawnpunkte konfiguriert. Respawn nicht möglich.")
            UnregisterPlayerFromFFA(src)
            TriggerClientEvent('ffa:playerLeftMatch', src)
            SetPlayerRoutingBucket(src, Config.DefaultRoutingBucket or 0)
            return
        end
        local spawnPoints = mapConfig.spawnPoints
        local randomSpawnPoint = spawnPoints[math.random(1, #spawnPoints)]

        DebugPrint("Versuche Spieler " .. xPlayer.getName() .. " zu respawnen. randomSpawnPoint Tabelle: " .. json.encode(randomSpawnPoint))
        if randomSpawnPoint and randomSpawnPoint.x and randomSpawnPoint.y and randomSpawnPoint.z then
            local respawnX, respawnY, respawnZ = tonumber(randomSpawnPoint.x), tonumber(randomSpawnPoint.y), tonumber(randomSpawnPoint.z)
            if respawnX and respawnY and respawnZ then
                xPlayer.triggerEvent('esx_ambulancejob:revive', src)
                Wait(150) -- Etwas längere Pause nach Revive, um sicherzustellen, dass der Spieler wieder "kontrollierbar" ist

                xPlayer.setCoords(respawnX, respawnY, respawnZ)
                DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") respawned bei " .. respawnX .. ", " .. respawnY .. ", " .. respawnZ)
            else
                DebugPrint("FEHLER beim Respawn: Konnte Koordinaten nicht in Zahlen umwandeln für Spieler " .. xPlayer.getName() .. ". x="..tostring(randomSpawnPoint.x)..", y="..tostring(randomSpawnPoint.y)..", z="..tostring(randomSpawnPoint.z))
                xPlayer.showNotification("Fehler: Ungültige Respawn-Koordinaten.")
                -- Fallback: Spieler einfach nur wiederbeleben ohne Teleport, oder aus FFA entfernen
                xPlayer.triggerEvent('esx_ambulancejob:revive', src)
                UnregisterPlayerFromFFA(src)
                TriggerClientEvent('ffa:playerLeftMatch', src)
                SetPlayerRoutingBucket(src, Config.DefaultRoutingBucket or 0)
                return
            end
        else
            DebugPrint("FEHLER beim Respawn: randomSpawnPoint oder dessen Koordinaten sind nil für Spieler " .. xPlayer.getName() .. ". randomSpawnPoint: " .. json.encode(randomSpawnPoint))
            xPlayer.showNotification("Fehler: Kritischer Fehler bei Respawn-Definition.")
            xPlayer.triggerEvent('esx_ambulancejob:revive', src)
            UnregisterPlayerFromFFA(src)
            TriggerClientEvent('ffa:playerLeftMatch', src)
            SetPlayerRoutingBucket(src, Config.DefaultRoutingBucket or 0)
            return
        end

        -- Volles Leben und Rüstung
        -- ESX.HealPlayer(src) -- Diese Funktion gibt es in Standard ESX nicht direkt, muss über TriggerEvent oder xPlayer Methoden
        xPlayer.setHealth(GetPedMaxHealth(xPlayer.getPed()))
        xPlayer.setArmour(100)
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") erhielt volle Gesundheit und Rüstung.")

        -- Waffen-Loadout geben
        GivePlayerMapLoadout(src, mapId)

        playerFFAState[src].isDead = false -- Spieler ist wieder lebendig
        TriggerClientEvent('ffa:playerRespawned', src) -- Client benachrichtigen (optional, für UI etc.)
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") Respawn-Prozess abgeschlossen.")
    end)
end)

-- Beim Verlassen des Servers auch aus playerFFAState entfernen
-- Spieler beim Verlassen des Servers aus Lobbys und FFA entfernen
AddEventHandler('esx:playerDropped', function(playerId, reason)
    local currentMapId = playerLobbyMap[playerId]

    DebugPrint("Spieler (ID: " .. playerId .. ") hat Server verlassen. Grund: " .. reason .. ". Map-ID aus Lobby: " .. tostring(currentMapId))

    if currentMapId then
        local lobby = activeLobbies[currentMapId]
        if lobby and lobby.players[playerId] then
            lobby.players[playerId] = nil
            lobby.playerCount = lobby.playerCount - 1

            local mapDisplayName = lobby.mapDetails.displayName
            DebugPrint("Spieler (ID: " .. playerId .. ") aus Lobby für Map '" .. mapDisplayName .. "' entfernt (Disconnect). Spieler in Lobby: " .. lobby.playerCount)

            if lobby.playerCount == 0 then
                DebugPrint("Lobby für Map '" .. mapDisplayName .. "' (ID: " .. currentMapId .. ") ist leer und wird nach Disconnect aufgelöst.")
                activeLobbies[currentMapId] = nil
            end
            TriggerClientEvent('ffa:updateLobbyView', -1, currentMapId, lobby and lobby.players or {}, lobby and lobby.playerCount or 0)
        end
        playerLobbyMap[playerId] = nil
    end

    UnregisterPlayerFromFFA(playerId)
end)

DebugPrint("FFA Script Server-Seite geladen und Lobby-System, Loadout-Funktion sowie Respawn-System initialisiert.")
