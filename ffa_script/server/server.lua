print("DEBUG: type(SetEntityHealth) is " .. type(SetEntityHealth)) -- Diese Zeile kann nach erfolgreichem Test entfernt werden
ESX = exports["es_extended"]:getSharedObject()

-- Hilfsfunktion für Debug-Nachrichten auf dem Server
local function DebugPrint(msg)
    if Config.Debug then
        print('[FFA_SCRIPT][SERVER] ' .. msg)
    end
end

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if ESX ~= nil then
            DebugPrint("ESX Shared Object erfolgreich geladen (via export).")
        else
            DebugPrint("ESX Shared Object konnte NICHT geladen werden (via export). Stelle sicher, dass es_extended gestartet ist UND exports korrekt definiert sind.")
        end
        DebugPrint("FFA Script Server-Seite gestartet.")
    end
end)

local activeLobbies = {}
local playerLobbyMap = {}

local function getMapConfigById(mapId)
    for _, mapConfig in ipairs(Config.Maps) do
        if mapConfig.id == mapId then
            return mapConfig
        end
    end
    return nil
end

RegisterNetEvent('ffa:joinLobby')
AddEventHandler('ffa:joinLobby', function(mapId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then
        DebugPrint("Spieler " .. src .. " nicht gefunden beim Versuch, Lobby beizutreten.")
        return
    end

    if playerLobbyMap[src] then
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") ist bereits in Lobby: " .. playerLobbyMap[src] .. ". Verlässt alte Lobby zuerst.")
        TriggerEvent('ffa:leaveLobby', playerLobbyMap[src], src)
    end

    local mapConfig = getMapConfigById(mapId)
    if not mapConfig then
        DebugPrint("Ungültige Map-ID " .. mapId .. " von Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") empfangen.")
        return
    end

    if not activeLobbies[mapId] then
        activeLobbies[mapId] = {
            players = {},
            mapDetails = mapConfig,
            playerCount = 0
        }
        DebugPrint("Lobby für Map '" .. mapConfig.displayName .. "' (ID: " .. mapId .. ") erstellt.")
    end

    if activeLobbies[mapId].playerCount >= mapConfig.maxPlayers then
        DebugPrint("Lobby für Map '" .. mapConfig.displayName .. "' ist voll. Spieler " .. xPlayer.getName() .. " kann nicht beitreten.")
        xPlayer.showNotification("Die Lobby für " .. mapConfig.displayName .. " ist bereits voll.")
        return
    end

    activeLobbies[mapId].players[src] = xPlayer
    activeLobbies[mapId].playerCount = activeLobbies[mapId].playerCount + 1
    playerLobbyMap[src] = mapId

    DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") ist Lobby für Map '" .. mapConfig.displayName .. "' beigetreten. Spieler in Lobby: " .. activeLobbies[mapId].playerCount)
    xPlayer.showNotification("Du bist der Lobby für " .. mapConfig.displayName .. " beigetreten.")

    TriggerClientEvent('ffa:updateLobbyView', -1, mapId, activeLobbies[mapId].players, activeLobbies[mapId].playerCount)

    if not mapConfig.spawnPoints or #mapConfig.spawnPoints == 0 then
        DebugPrint("FEHLER: Keine Spawnpunkte für Map " .. mapId .. " definiert! Spieler kann nicht teleportiert werden.")
        xPlayer.showNotification("Fehler: Für diese Map sind keine Spawnpunkte konfiguriert.")
        TriggerEvent('ffa:leaveLobby', mapId, src)
        return
    end
    local spawnPoints = mapConfig.spawnPoints
    local randomSpawn = spawnPoints[math.random(1, #spawnPoints)]

    local mapIndex = 0
    for i, m in ipairs(Config.Maps) do
        if m.id == mapId then
            mapIndex = i
            break
        end
    end
    local routingBucket = 5000 + mapIndex
    SetPlayerRoutingBucket(src, routingBucket)

    DebugPrint("Versuche Spieler " .. xPlayer.getName() .. " zu teleportieren. randomSpawn Tabelle: " .. json.encode(randomSpawn))
    if randomSpawn and randomSpawn.x and randomSpawn.y and randomSpawn.z then
        local newX, newY, newZ = tonumber(randomSpawn.x), tonumber(randomSpawn.y), tonumber(randomSpawn.z)
        if newX and newY and newZ then
            TriggerClientEvent('ffa:setClientPedCoords', src, { x = newX, y = newY, z = newZ })
            DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") Teleport-Event an Client gesendet für Coords (" .. newX .. "," .. newY .. "," .. newZ .. "). Routing Bucket: " .. routingBucket)
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

    GivePlayerMapLoadout(src, mapId)
    RegisterPlayerToFFA(src, mapId)

    local playerPedForHealth = GetPlayerPed(src) -- Ped holen für Max Health
    if playerPedForHealth and playerPedForHealth ~= 0 then
        local maxHealth = GetEntityMaxHealth(playerPedForHealth)
        TriggerClientEvent('ffa:setClientPedHealthArmor', src, maxHealth, 100)
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") Health/Armor-Event an Client gesendet.")
    else
        DebugPrint("FEHLER: Konnte Ped für Spieler " .. xPlayer.getName() .. " nicht bekommen für initiales Health/Armor Set.")
    end

    TriggerClientEvent('ffa:playerJoinedMatch', src, mapId)
    DebugPrint("FFA-Match für Spieler " .. xPlayer.getName() .. " auf Map " .. mapConfig.displayName .. " gestartet/beigetreten.")
end)

RegisterNetEvent('ffa:leaveLobby')
AddEventHandler('ffa:leaveLobby', function(customMapId, customSrc)
    local src = customSrc or source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then
        DebugPrint("Spieler " .. src .. " nicht gefunden beim Versuch, Lobby zu verlassen.")
        return
    end

    local mapId = customMapId or playerLobbyMap[src]

    if not mapId or not activeLobbies[mapId] or not activeLobbies[mapId].players[src] then
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") ist in keiner Lobby oder Lobby existiert nicht zum Verlassen (MapID: " .. tostring(mapId) .. ").")
        return
    end

    local mapDisplayName = activeLobbies[mapId].mapDetails.displayName

    UnregisterPlayerFromFFA(src)
    TriggerClientEvent('ffa:playerLeftMatch', src)
    SetPlayerRoutingBucket(src, Config.DefaultRoutingBucket or 0)
    DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") aus FFA-Match auf Map '" .. mapDisplayName .. "' entfernt und Routing Bucket zurückgesetzt.")
    -- Hier könnte man den Spieler auch an einen sicheren Ort teleportieren via Client-Event

    activeLobbies[mapId].players[src] = nil
    activeLobbies[mapId].playerCount = activeLobbies[mapId].playerCount - 1
    playerLobbyMap[src] = nil

    DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") hat Lobby für Map '" .. mapDisplayName .. "' verlassen. Spieler in Lobby: " .. activeLobbies[mapId].playerCount)
    xPlayer.showNotification("Du hast die Lobby und das FFA-Match für " .. mapDisplayName .. " verlassen.")

    if activeLobbies[mapId].playerCount == 0 then
        DebugPrint("Lobby für Map '" .. mapDisplayName .. "' (ID: " .. mapId .. ") ist leer und wird aufgelöst.")
        activeLobbies[mapId] = nil
    end

    TriggerClientEvent('ffa:updateLobbyView', -1, mapId, activeLobbies[mapId] and activeLobbies[mapId].players or {}, activeLobbies[mapId] and activeLobbies[mapId].playerCount or 0)
end)

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

function GivePlayerMapLoadout(playerId, mapId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local mapConfig = getMapConfigById(mapId)

    if not mapConfig or not mapConfig.weapons then
        DebugPrint("Loadout: Map-Konfiguration oder Waffen für MapID " .. mapId .. " nicht gefunden.")
        return
    end

    local playerPed = GetPlayerPed(playerId)
    if not playerPed or playerPed == 0 then
        DebugPrint("Loadout: Konnte Ped für Spieler " .. playerId .. " nicht bekommen. Waffen können nicht geändert werden.")
        if xPlayer then
            xPlayer.showNotification("Fehler: Spieler-Entität nicht gefunden für Waffen-Loadout.")
        end
        return
    end

    RemoveAllPedWeapons(playerPed, true)
    DebugPrint("Loadout: Alle Waffen von Spieler " .. playerId .. " (Ped: " .. playerPed .. ") entfernt via Native.")

    for _, weaponData in ipairs(mapConfig.weapons) do
        if weaponData.hash and weaponData.ammo then
            local weaponHashKey = GetHashKey(weaponData.hash)
            GiveWeaponToPed(playerPed, weaponHashKey, weaponData.ammo, false, true)
            DebugPrint("Loadout: Spieler " .. playerId .. " (Ped: " .. playerPed .. ") erhielt Waffe " .. weaponData.hash .. " (Hash: " .. weaponHashKey .. ") mit " .. weaponData.ammo .. " Munition via Native.")
        else
            DebugPrint("Loadout: Ungültige Waffendaten für MapID " .. mapId .. ": Hash=" .. tostring(weaponData.hash) .. ", Ammo=" .. tostring(weaponData.ammo))
        end
    end

    if xPlayer then
        xPlayer.showNotification("Du hast das Waffen-Loadout für '" .. mapConfig.displayName .. "' erhalten.")
    end
    DebugPrint("Loadout: Waffen-Loadout für Map '" .. mapConfig.displayName .. "' an Spieler " .. playerId .. " (Ped: " .. playerPed .. ") vergeben via Native.")
end

local playerFFAState = {}

function RegisterPlayerToFFA(playerId, mapId)
    playerFFAState[playerId] = { mapId = mapId, isDead = false }
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer then
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. playerId .. ") für FFA auf Map " .. mapId .. " registriert.")
    end
end

function UnregisterPlayerFromFFA(playerId)
    if playerFFAState[playerId] then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. playerId .. ") aus FFA deregistriert.")
        else
            DebugPrint("Spieler (ID: " .. playerId .. ") aus FFA deregistriert (war bereits offline oder ungültig).")
        end
        playerFFAState[playerId] = nil
    end
end

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

    Citizen.CreateThread(function()
        Wait(Config.RespawnDelay or 3000)

        if not playerFFAState[src] then
            DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") hat FFA verlassen, bevor Respawn ausgeführt wurde.")
            return
        end
        if not ESX.GetPlayerFromId(src) then
            DebugPrint("Spieler " .. src .. " ist offline, bevor Respawn ausgeführt wurde.")
            UnregisterPlayerFromFFA(src)
            return
        end

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
                Wait(150)

                TriggerClientEvent('ffa:setClientPedCoords', src, { x = respawnX, y = respawnY, z = respawnZ })
                DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") Respawn-Teleport-Event an Client gesendet für Coords (" .. respawnX .. "," .. respawnY .. "," .. respawnZ .. ").")
            else
                DebugPrint("FEHLER beim Respawn: Konnte Koordinaten nicht in Zahlen umwandeln für Spieler " .. xPlayer.getName() .. ". x="..tostring(randomSpawnPoint.x)..", y="..tostring(randomSpawnPoint.y)..", z="..tostring(randomSpawnPoint.z))
                xPlayer.showNotification("Fehler: Ungültige Respawn-Koordinaten.")
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

        local playerPedForHealthAndArmorRespawn = GetPlayerPed(src)
        if playerPedForHealthAndArmorRespawn and playerPedForHealthAndArmorRespawn ~= 0 then
            local maxHealthRespawn = GetEntityMaxHealth(playerPedForHealthAndArmorRespawn)
            TriggerClientEvent('ffa:setClientPedHealthArmor', src, maxHealthRespawn, 100)
            DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") Health/Armor-Event für Respawn an Client gesendet.")
        else
            DebugPrint("FEHLER: Konnte Ped für Spieler " .. xPlayer.getName() .. " nicht bekommen für Health/Armor Set beim Respawn.")
        end

        GivePlayerMapLoadout(src, mapId)

        playerFFAState[src].isDead = false
        TriggerClientEvent('ffa:playerRespawned', src)
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") Respawn-Prozess abgeschlossen.")
    end)
end)

DebugPrint("FFA Script Server-Seite geladen und Lobby-System, Loadout-Funktion sowie Respawn-System initialisiert.")
