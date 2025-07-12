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
local playerCurrentFFALoadout = {} -- Speichert das aktuelle Loadout eines Spielers im FFA: playerId = { {name='weapon_pistol', ammo=100}, ... }
local playerLastLocation = {} -- Speichert die letzte Position des Spielers vor dem FFA-Beitritt: playerId = {x,y,z, heading} (heading hinzugefügt)

local function getMapConfigById(mapId)
    for _, mapConfig in ipairs(Config.Maps) do
        if mapConfig.id == mapId then
            return mapConfig
        end
    end
    return nil
end

-- Funktion zum Entfernen des aktuellen FFA-Loadouts eines Spielers aus ox_inventory
local function RemovePlayerFFALoadout(playerId)
    if exports.ox_inventory and playerCurrentFFALoadout[playerId] then
        DebugPrint("Loadout Removal: Versuche FFA Loadout für Spieler " .. playerId .. " zu entfernen. Loadout: " .. json.encode(playerCurrentFFALoadout[playerId]))
        for _, weaponData in ipairs(playerCurrentFFALoadout[playerId]) do
            local currentAmount = exports.ox_inventory:Search('count', weaponData.name, playerId)
            DebugPrint("Loadout Removal: ox_inventory:Search('count', '"..weaponData.name.."', "..playerId..") ergab: " .. tostring(currentAmount) .. " (Typ: " .. type(currentAmount) .. ")")

            if currentAmount and type(currentAmount) == 'number' and currentAmount > 0 then
                local success, removedCount = exports.ox_inventory:RemoveItem(playerId, weaponData.name, currentAmount)
                if success and removedCount > 0 then
                    DebugPrint("Loadout Removal: Waffe " .. weaponData.name .. " (" .. removedCount .. " von " .. currentAmount .. ") von Spieler " .. playerId .. " entfernt.")
                else
                    DebugPrint("Loadout Removal WARNING: Konnte Waffe " .. weaponData.name .. " nicht (vollständig) von Spieler " .. playerId .. " entfernen. Angefragt: " .. currentAmount .. ", Erfolgreich: " .. tostring(success) .. ", Anzahl entfernt: " .. tostring(removedCount))
                end
            elseif not (currentAmount and type(currentAmount) == 'number') then
                DebugPrint("Loadout Removal INFO: Waffe " .. weaponData.name .. " nicht als zählbare Menge im Inventar von Spieler " .. playerId .. " gefunden (Search ergab: " .. tostring(currentAmount) .. ").")
            else -- currentAmount ist 0 oder weniger
                DebugPrint("Loadout Removal INFO: Waffe " .. weaponData.name .. " nicht im Inventar von Spieler " .. playerId .. " gefunden (Anzahl 0 oder weniger).")
            end
        end
        playerCurrentFFALoadout[playerId] = nil
    elseif not exports.ox_inventory then
        DebugPrint("Loadout Removal ERROR: ox_inventory Export nicht gefunden.")
    else
        DebugPrint("Loadout Removal INFO: Kein FFA-Loadout für Spieler " .. playerId .. " getrackt oder ox_inventory nicht verfügbar.")
    end
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

    -- Spielerposition und Heading vor dem FFA speichern
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local currentCoords = GetEntityCoords(ped)
        local currentHeading = GetEntityHeading(ped)
        playerLastLocation[src] = {x = currentCoords.x, y = currentCoords.y, z = currentCoords.z, heading = currentHeading}
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") Position vor FFA gespeichert: " .. json.encode(playerLastLocation[src]))
    else
        DebugPrint("WARNUNG: Konnte Ped für Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") nicht bekommen, um Position zu speichern.")
        playerLastLocation[src] = nil
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
        if playerLastLocation[src] then playerLastLocation[src] = nil end -- Gespeicherte Pos. löschen, da Join fehlschlug
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

    if randomSpawn and randomSpawn.x and randomSpawn.y and randomSpawn.z then
        local newX, newY, newZ = tonumber(randomSpawn.x), tonumber(randomSpawn.y), tonumber(randomSpawn.z)
        if newX and newY and newZ then
            TriggerClientEvent('ffa:setClientPedCoords', src, { x = newX, y = newY, z = newZ, heading = randomSpawn.h or 0.0 }) -- Optionales Heading aus Config
            DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") Teleport-Event an Client gesendet. Routing Bucket: " .. routingBucket)
        else
            DebugPrint("FEHLER: Konnte Koordinaten nicht in Zahlen umwandeln. x="..tostring(randomSpawn.x)..", y="..tostring(randomSpawn.y)..", z="..tostring(randomSpawn.z))
            xPlayer.showNotification("Fehler: Ungültige Spawnpunkt-Koordinaten.")
            TriggerEvent('ffa:leaveLobby', mapId, src)
            return
        end
    else
        DebugPrint("FEHLER: randomSpawn oder dessen Koordinaten sind nil. randomSpawn: " .. json.encode(randomSpawn))
        xPlayer.showNotification("Fehler: Kritischer Fehler bei Spawnpunkt-Definition.")
        TriggerEvent('ffa:leaveLobby', mapId, src)
        return
    end

    GivePlayerMapLoadout(src, mapId)
    RegisterPlayerToFFA(src, mapId)

    local playerPedForHealth = GetPlayerPed(src)
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

    if not mapId then -- Zusätzliche Prüfung, falls playerLobbyMap[src] nil ist
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") versuchte Lobby zu verlassen, aber keine mapId gefunden (nicht in einer Lobby).")
        xPlayer.showNotification("Du bist in keiner FFA-Lobby.")
        return
    end

    if not activeLobbies[mapId] or not activeLobbies[mapId].players[src] then
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") ist in keiner aktiven Lobby oder Lobby existiert nicht (MapID: " .. tostring(mapId) .. ").")
        return
    end

    local mapDisplayName = activeLobbies[mapId].mapDetails.displayName

    RemovePlayerFFALoadout(src)

    UnregisterPlayerFromFFA(src)
    TriggerClientEvent('ffa:playerLeftMatch', src)
    SetPlayerRoutingBucket(src, Config.DefaultRoutingBucket or 0)
    DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") aus FFA-Match auf Map '" .. mapDisplayName .. "' entfernt und Routing Bucket zurückgesetzt.")

    if playerLastLocation[src] then
        TriggerClientEvent('ffa:setClientPedCoords', src, playerLastLocation[src])
        DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") zurück zur vorherigen Position teleportiert: " .. json.encode(playerLastLocation[src]))
        playerLastLocation[src] = nil
    else
        DebugPrint("WARNUNG: Keine vorherige Position für Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") gespeichert.")
    end

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
        RemovePlayerFFALoadout(playerId)
        playerLastLocation[playerId] = nil

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

    DebugPrint("Loadout: GivePlayerMapLoadout aufgerufen für Spieler " .. playerId .. " und MapID " .. mapId)

    if not mapConfig then
        DebugPrint("Loadout ERROR: Map-Konfiguration für MapID " .. mapId .. " nicht gefunden.")
        return
    end
    DebugPrint("Loadout: Map-Konfiguration für '" .. mapConfig.displayName .. "' gefunden.")

    if not mapConfig.weapons or #mapConfig.weapons == 0 then
        DebugPrint("Loadout WARNING: Keine Waffen in der Konfiguration für MapID " .. mapId .. " definiert.")
        if xPlayer then
            xPlayer.showNotification("Für diese Map sind keine spezifischen Waffen konfiguriert.")
        end
        return
    end
    DebugPrint("Loadout: Waffenkonfiguration für Map '" .. mapConfig.displayName .. "': " .. json.encode(mapConfig.weapons))

    RemovePlayerFFALoadout(playerId)
    playerCurrentFFALoadout[playerId] = {}

    if exports.ox_inventory then
        for i, weaponData in ipairs(mapConfig.weapons) do
            if weaponData.name and weaponData.ammo and tonumber(weaponData.ammo) then
                local weaponName = tostring(weaponData.name)
                local weaponAmmo = tonumber(weaponData.ammo)
                local metadata = { ammo = weaponAmmo }

                local success, itemData = exports.ox_inventory:AddItem(playerId, weaponName, 1, metadata)
                if success and itemData then
                    table.insert(playerCurrentFFALoadout[playerId], {name = weaponName, ammo = weaponAmmo})
                    DebugPrint("Loadout: Spieler " .. playerId .. " erhielt Waffe " .. weaponName .. " mit " .. weaponAmmo .. " Munition via ox_inventory. ItemData: " .. json.encode(itemData))
                else
                    DebugPrint("Loadout ERROR: Konnte Waffe " .. weaponName .. " nicht zu ox_inventory für Spieler " .. playerId .. " hinzufügen. Erfolg: "..tostring(success))
                end
            else
                DebugPrint("Loadout WARNING: Ungültige oder fehlende Waffendaten/Munition für MapID " .. mapId .. " (Index " .. i .. "): Name=" .. tostring(weaponData.name) .. ", Ammo=" .. tostring(weaponData.ammo))
            end
        end
        if xPlayer then
            xPlayer.showNotification("Du hast das Waffen-Loadout für '" .. mapConfig.displayName .. "' via ox_inventory erhalten.")
        end
        DebugPrint("Loadout: Waffen-Loadout-Prozess via ox_inventory für Map '" .. mapConfig.displayName .. "' an Spieler " .. playerId .. " abgeschlossen.")
    else
        DebugPrint("Loadout ERROR: ox_inventory Export nicht gefunden. Waffen können nicht gegeben werden.")
        if xPlayer then
            xPlayer.showNotification("Fehler: Inventarsystem (ox_inventory) nicht gefunden.")
        end
    end
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

        if randomSpawnPoint and randomSpawnPoint.x and randomSpawnPoint.y and randomSpawnPoint.z then
            local respawnX, respawnY, respawnZ = tonumber(randomSpawnPoint.x), tonumber(randomSpawnPoint.y), tonumber(randomSpawnPoint.z)
            if respawnX and respawnY and respawnZ then
                xPlayer.triggerEvent('esx_ambulancejob:revive', src)
                Wait(150)

                TriggerClientEvent('ffa:setClientPedCoords', src, { x = respawnX, y = respawnY, z = respawnZ, heading = randomSpawnPoint.h or 0.0 })
                DebugPrint("Spieler " .. xPlayer.getName() .. " (ID: " .. src .. ") Respawn-Teleport-Event an Client gesendet.")
            else
                DebugPrint("FEHLER beim Respawn: Konnte Koordinaten nicht in Zahlen umwandeln. x="..tostring(randomSpawnPoint.x)..", y="..tostring(randomSpawnPoint.y)..", z="..tostring(randomSpawnPoint.z))
                xPlayer.showNotification("Fehler: Ungültige Respawn-Koordinaten.")
                xPlayer.triggerEvent('esx_ambulancejob:revive', src)
                UnregisterPlayerFromFFA(src)
                TriggerClientEvent('ffa:playerLeftMatch', src)
                SetPlayerRoutingBucket(src, Config.DefaultRoutingBucket or 0)
                return
            end
        else
            DebugPrint("FEHLER beim Respawn: randomSpawnPoint oder dessen Koordinaten sind nil. randomSpawnPoint: " .. json.encode(randomSpawnPoint))
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
