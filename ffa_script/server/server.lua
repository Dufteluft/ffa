print("DEBUG: type(SetEntityHealth) is " .. type(SetEntityHealth))
ESX = exports["es_extended"]:getSharedObject()

local function DebugPrint(msg)
    if Config.Debug then
        print('[FFA_SCRIPT][SERVER] ' .. msg)
    end
end

local playerStats = {} -- Kills und Tode speichern

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if ESX ~= nil then
            DebugPrint("ESX Shared Object erfolgreich geladen.")
        else
            DebugPrint("ESX Shared Object konnte NICHT geladen werden.")
        end
        DebugPrint("FFA Script Server-Seite gestartet.")
    end
end)

local activeLobbies = {}
local playerLobbyMap = {}
local playerCurrentFFALoadout = {}
local playerLastLocation = {}
local playerOriginalInventory = {}

local function getMapConfigById(mapId)
    for _, mapConfig in ipairs(Config.Maps) do
        if mapConfig.id == mapId then
            return mapConfig
        end
    end
    return nil
end

local function getTopTenPlayers()
    local sortedPlayers = {}
    for playerId, stats in pairs(playerStats) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            table.insert(sortedPlayers, {
                name = xPlayer.getName(),
                kills = stats.kills
            })
        end
    end

    table.sort(sortedPlayers, function(a, b)
        return a.kills > b.kills
    end)

    local topTen = {}
    for i = 1, math.min(10, #sortedPlayers) do
        table.insert(topTen, sortedPlayers[i])
    end
    return topTen
end

ESX.RegisterServerCallback('ffa:requestInitialData', function(source, cb)
    local src = source
    local mapsForUI = {}
    for i, mapInfo in ipairs(Config.Maps) do
        table.insert(mapsForUI, {
            id = mapInfo.id,
            displayName = mapInfo.displayName,
            description = mapInfo.description,
            thumbnail = mapInfo.thumbnail,
            maxPlayers = mapInfo.maxPlayers,
            currentPlayers = activeLobbies[mapInfo.id] and activeLobbies[mapInfo.id].playerCount or 0
        })
    end

    local stats = playerStats[src] or {kills = 0, deaths = 0}
    local leaderboard = getTopTenPlayers()

    cb({
        maps = mapsForUI,
        stats = stats,
        leaderboard = leaderboard
    })
end)

local function StoreAndClearPlayerInventoryForFFA(playerId, mapWeapons)
    DebugPrint("Store/Clear INV: Aufgerufen für Spieler " .. playerId)
    if not exports.ox_inventory then
        DebugPrint("Store/Clear INV ERROR: ox_inventory Export nicht gefunden.")
        return false
    end
    if exports.ox_inventory.ConfiscateInventory then
        DebugPrint("Store/Clear INV: Versuche ConfiscateInventory für Spieler " .. playerId)
        local success, reason = exports.ox_inventory:ConfiscateInventory(playerId)
        if success then
            DebugPrint("Store/Clear INV: ConfiscateInventory erfolgreich für Spieler " .. playerId)
            return true
        else
            DebugPrint("Store/Clear INV: ConfiscateInventory fehlgeschlagen. Grund: " .. tostring(reason) .. ". Versuche Fallback.")
        end
    end
    DebugPrint("Store/Clear INV: Verwende manuellen Fallback für Spieler " .. playerId)
    playerOriginalInventory[playerId] = exports.ox_inventory:GetInventory(playerId)
    if not playerOriginalInventory[playerId] then
        DebugPrint("Store/Clear INV ERROR: Konnte Inventar nicht abrufen für Spieler " .. playerId)
        return false
    end
    DebugPrint("Store/Clear INV: Inventar gespeichert für Spieler " .. playerId .. ": " .. json.encode(playerOriginalInventory[playerId]))
    if playerOriginalInventory[playerId].items then
        local itemsRemoved = 0
        for slot, itemData in pairs(playerOriginalInventory[playerId].items) do
            if itemData and itemData.name and itemData.count then
                local success = exports.ox_inventory:RemoveItem(playerId, itemData.name, itemData.count, itemData.metadata, slot)
                if success then
                    itemsRemoved = itemsRemoved + 1
                    DebugPrint("Store/Clear INV: Item " .. itemData.name .. " entfernt von Slot " .. slot)
                else
                    DebugPrint("Store/Clear INV WARNING: Konnte Item " .. itemData.name .. " nicht entfernen von Slot " .. slot)
                end
            end
        end
        DebugPrint("Store/Clear INV: " .. itemsRemoved .. " Items manuell entfernt für Spieler " .. playerId)
    end
    return true
end

local function RestorePlayerOriginalInventory(playerId)
    DebugPrint("Restore INV: Aufgerufen für Spieler " .. playerId)
    if not exports.ox_inventory then
        DebugPrint("Restore INV ERROR: ox_inventory Export nicht gefunden.")
        return
    end
    if exports.ox_inventory.ReturnInventory then
        DebugPrint("Restore INV: Versuche ReturnInventory für Spieler " .. playerId)
        local success, reason = exports.ox_inventory:ReturnInventory(playerId)
        if success then
            DebugPrint("Restore INV: ReturnInventory erfolgreich für Spieler " .. playerId)
            playerOriginalInventory[playerId] = nil
            return
        else
            DebugPrint("Restore INV: ReturnInventory fehlgeschlagen. Grund: " .. tostring(reason) .. ". Versuche Fallback.")
        end
    end
    if playerOriginalInventory[playerId] and playerOriginalInventory[playerId].items then
        DebugPrint("Restore INV: Verwende manuellen Fallback für Spieler " .. playerId)
        local itemsRestored = 0
        for slot, itemData in pairs(playerOriginalInventory[playerId].items) do
            if itemData and itemData.name and itemData.count then
                local success = exports.ox_inventory:AddItem(playerId, itemData.name, itemData.count, itemData.metadata, slot)
                if success then
                    itemsRestored = itemsRestored + 1
                    DebugPrint("Restore INV: Item " .. itemData.name .. " wiederhergestellt zu Slot " .. slot)
                else
                    DebugPrint("Restore INV WARNING: Konnte Item " .. itemData.name .. " nicht wiederherstellen zu Slot " .. slot)
                end
            end
        end
        DebugPrint("Restore INV: " .. itemsRestored .. " Items manuell wiederhergestellt für Spieler " .. playerId)
        playerOriginalInventory[playerId] = nil
    else
        DebugPrint("Restore INV WARNING: Kein gespeichertes Inventar für Spieler " .. playerId .. " gefunden")
    end
end

local function RemovePlayerFFALoadout(playerId)
    DebugPrint("Loadout REMOVAL: Aufgerufen für Spieler " .. playerId)
    if exports.ox_inventory and playerCurrentFFALoadout[playerId] and #playerCurrentFFALoadout[playerId] > 0 then
        DebugPrint("Loadout REMOVAL: Aktuell getracktes FFA Loadout für Spieler " .. playerId .. ": " .. json.encode(playerCurrentFFALoadout[playerId]))
        local itemsActuallyRemovedOverall = 0
        for i, weaponData in ipairs(playerCurrentFFALoadout[playerId]) do
            if weaponData and weaponData.name then
                DebugPrint("Loadout REMOVAL: Iteration " .. i .. ", versuche Waffe '" .. weaponData.name .. "' zu entfernen.")
                local success, removedInfo = exports.ox_inventory:RemoveItem(playerId, weaponData.name, 1)
                if success then
                    local removedCount = 0
                    if type(removedInfo) == 'number' then
                        removedCount = removedInfo
                    elseif type(removedInfo) == 'table' and removedInfo.count then
                        removedCount = removedInfo.count
                    elseif success then
                        removedCount = 1
                    end
                    if removedCount > 0 then
                        itemsActuallyRemovedOverall = itemsActuallyRemovedOverall + removedCount
                        DebugPrint("Loadout REMOVAL: Waffe " .. weaponData.name .. " (entfernt: " .. removedCount .. ") von Spieler " .. playerId .. " erfolgreich via RemoveItem entfernt.")
                    else
                        DebugPrint("Loadout REMOVAL INFO: Waffe " .. weaponData.name .. " erfolgreich mit RemoveItem behandelt, aber gemeldete Anzahl entfernt war 0. Spieler " .. playerId .. ". RemovedInfo: " .. json.encode(removedInfo))
                    end
                else
                    DebugPrint("Loadout REMOVAL WARNING: ox_inventory:RemoveItem für Waffe '" .. weaponData.name .. "' bei Spieler " .. playerId .. " meldete keinen Erfolg. Details: " .. json.encode(removedInfo))
                end
            else
                DebugPrint("Loadout REMOVAL WARNING: Ungültige weaponData in playerCurrentFFALoadout für Spieler " .. playerId .. " bei Index " .. i .. ": " .. json.encode(weaponData))
            end
        end
        DebugPrint("Loadout REMOVAL: Insgesamt " .. itemsActuallyRemovedOverall .. " Item-Stacks (basierend auf Erfolgsmeldungen) versucht zu entfernen für Spieler " .. playerId)
        playerCurrentFFALoadout[playerId] = nil
    elseif not exports.ox_inventory then
        DebugPrint("Loadout REMOVAL ERROR: ox_inventory Export nicht gefunden.")
    elseif not playerCurrentFFALoadout[playerId] or #playerCurrentFFALoadout[playerId] == 0 then
        DebugPrint("Loadout REMOVAL INFO: Kein FFA-Loadout für Spieler " .. playerId .. " getrackt zum Entfernen.")
    end
    DebugPrint("Loadout REMOVAL: Prozess für Spieler " .. playerId .. " abgeschlossen.")
end

RegisterNetEvent('ffa:joinLobby')
AddEventHandler('ffa:joinLobby', function(mapId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then DebugPrint("Spieler " .. src .. " nicht gefunden."); return end
    if playerLobbyMap[src] then DebugPrint("Spieler " .. xPlayer.getName() .. " bereits in Lobby " .. playerLobbyMap[src]); TriggerEvent('ffa:leaveLobby', playerLobbyMap[src], src) end
    local mapConfig = getMapConfigById(mapId)
    if not mapConfig then DebugPrint("Ungültige Map-ID " .. mapId); return end
    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local currentCoords = GetEntityCoords(ped)
        local currentHeading = GetEntityHeading(ped)
        playerLastLocation[src] = {x = currentCoords.x, y = currentCoords.y, z = currentCoords.z, heading = currentHeading}
    else
        playerLastLocation[src] = nil
    end
    DebugPrint("FFA Join: Rufe StoreAndClearPlayerInventoryForFFA für Spieler " .. src)
    if not StoreAndClearPlayerInventoryForFFA(src, mapConfig.weapons) then
        xPlayer.showNotification("Fehler bei der Inventarvorbereitung für FFA.")
        if playerLastLocation[src] then playerLastLocation[src] = nil end
        DebugPrint("FFA Join: StoreAndClearPlayerInventoryForFFA fehlgeschlagen für Spieler " .. src)
        return
    end
    DebugPrint("FFA Join: StoreAndClearPlayerInventoryForFFA erfolgreich für Spieler " .. src)
    if not activeLobbies[mapId] then
        activeLobbies[mapId] = { players = {}, mapDetails = mapConfig, playerCount = 0 }
    end
    if activeLobbies[mapId].playerCount >= mapConfig.maxPlayers then
        xPlayer.showNotification("Die Lobby für " .. mapConfig.displayName .. " ist bereits voll.")
        DebugPrint("FFA Join: Lobby voll für Spieler " .. src .. ". Rufe RestorePlayerOriginalInventory.")
        RestorePlayerOriginalInventory(src)
        if playerLastLocation[src] then playerLastLocation[src] = nil end
        return
    end
    activeLobbies[mapId].players[src] = xPlayer
    activeLobbies[mapId].playerCount = activeLobbies[mapId].playerCount + 1
    playerLobbyMap[src] = mapId
    xPlayer.showNotification("Du bist der Lobby für " .. mapConfig.displayName .. " beigetreten.")
    TriggerClientEvent('ffa:updateLobbyView', -1, mapId, activeLobbies[mapId].players, activeLobbies[mapId].playerCount)
    if not mapConfig.spawnPoints or #mapConfig.spawnPoints == 0 then
        xPlayer.showNotification("Fehler: Keine Spawnpunkte konfiguriert.")
        TriggerEvent('ffa:leaveLobby', mapId, src)
        return
    end
    local randomSpawn = mapConfig.spawnPoints[math.random(1, #mapConfig.spawnPoints)]
    local mapIndex = 0
    for i, m in ipairs(Config.Maps) do if m.id == mapId then mapIndex = i; break end end
    local routingBucket = 5000 + mapIndex
    SetPlayerRoutingBucket(src, routingBucket)
    if randomSpawn and randomSpawn.x and randomSpawn.y and randomSpawn.z then
        TriggerClientEvent('ffa:setClientPedCoords', src, { x = tonumber(randomSpawn.x), y = tonumber(randomSpawn.y), z = tonumber(randomSpawn.z), heading = randomSpawn.h or 0.0 })
    else
        xPlayer.showNotification("Fehler: Kritischer Fehler bei Spawnpunkt-Definition.")
        TriggerEvent('ffa:leaveLobby', mapId, src)
        return
    end
    DebugPrint("FFA Join: Rufe GivePlayerMapLoadout für Spieler " .. src)
    GivePlayerMapLoadout(src, mapId)
    DebugPrint("FFA Join: GivePlayerMapLoadout abgeschlossen für Spieler " .. src)
    RegisterPlayerToFFA(src, mapId)
    if ped and ped ~= 0 then
        TriggerClientEvent('ffa:setClientPedHealthArmor', src, GetEntityMaxHealth(ped), 100)
    end
    TriggerClientEvent('ffa:playerJoinedMatch', src, mapId)
    DebugPrint("FFA-Match für Spieler " .. src .. " auf Map " .. mapConfig.displayName .. " gestartet.")
end)

RegisterNetEvent('ffa:leaveLobby')
AddEventHandler('ffa:leaveLobby', function(customMapId, customSrc)
    local src = customSrc or source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then DebugPrint("Spieler " .. src .. " nicht gefunden."); return end
    local mapId = customMapId or playerLobbyMap[src]
    if not mapId then xPlayer.showNotification("Du bist in keiner FFA-Lobby."); return end
    if not activeLobbies[mapId] or not activeLobbies[mapId].players[src] then return end
    local mapDisplayName = activeLobbies[mapId].mapDetails.displayName
    DebugPrint("FFA Leave: Spieler " .. src .. " verlässt FFA für Map " .. mapDisplayName)
    DebugPrint("FFA Leave: Rufe RemovePlayerFFALoadout für Spieler " .. src)
    RemovePlayerFFALoadout(src)
    DebugPrint("FFA Leave: RemovePlayerFFALoadout abgeschlossen für Spieler " .. src)
    DebugPrint("FFA Leave: Rufe RestorePlayerOriginalInventory für Spieler " .. src)
    RestorePlayerOriginalInventory(src)
    DebugPrint("FFA Leave: RestorePlayerOriginalInventory abgeschlossen für Spieler " .. src)
    UnregisterPlayerFromFFA(src)
    TriggerClientEvent('ffa:playerLeftMatch', src)
    SetPlayerRoutingBucket(src, Config.DefaultRoutingBucket or 0)
    if playerLastLocation[src] then
        TriggerClientEvent('ffa:setClientPedCoords', src, playerLastLocation[src])
        playerLastLocation[src] = nil
    end
    activeLobbies[mapId].players[src] = nil
    activeLobbies[mapId].playerCount = activeLobbies[mapId].playerCount - 1
    playerLobbyMap[src] = nil
    xPlayer.showNotification("Du hast die Lobby und das FFA-Match für " .. mapDisplayName .. " verlassen.")
    if activeLobbies[mapId].playerCount == 0 then activeLobbies[mapId] = nil end
    TriggerClientEvent('ffa:updateLobbyView', -1, mapId, activeLobbies[mapId] and activeLobbies[mapId].players or {}, activeLobbies[mapId] and activeLobbies[mapId].playerCount or 0)
    DebugPrint("FFA Leave: Prozess für Spieler " .. src .. " abgeschlossen.")
end)

AddEventHandler('esx:playerDropped', function(playerId, reason)
    local currentMapId = playerLobbyMap[playerId]
    DebugPrint("Player Dropped: Spieler (ID: " .. playerId .. ") hat Server verlassen. Grund: " .. reason .. ". Map-ID: " .. tostring(currentMapId))
    if currentMapId then
        DebugPrint("Player Dropped: Rufe RemovePlayerFFALoadout für Spieler " .. playerId)
        RemovePlayerFFALoadout(playerId)
        DebugPrint("Player Dropped: RemovePlayerFFALoadout abgeschlossen für Spieler " .. playerId)
        DebugPrint("Player Dropped: Rufe RestorePlayerOriginalInventory für Spieler " .. playerId)
        RestorePlayerOriginalInventory(playerId)
        DebugPrint("Player Dropped: RestorePlayerOriginalInventory abgeschlossen für Spieler " .. playerId)
        playerLastLocation[playerId] = nil
        local lobby = activeLobbies[currentMapId]
        if lobby and lobby.players[playerId] then
            lobby.players[playerId] = nil
            lobby.playerCount = lobby.playerCount - 1
            if lobby.playerCount == 0 then activeLobbies[currentMapId] = nil end
            TriggerClientEvent('ffa:updateLobbyView', -1, currentMapId, lobby and lobby.players or {}, lobby and lobby.playerCount or 0)
        end
        playerLobbyMap[playerId] = nil
    end
    UnregisterPlayerFromFFA(playerId)
    DebugPrint("Player Dropped: Prozess für Spieler " .. playerId .. " abgeschlossen.")
end)

function GivePlayerMapLoadout(playerId, mapId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local mapConfig = getMapConfigById(mapId)
    DebugPrint("Loadout GIVE: Aufgerufen für Spieler " .. playerId .. ", MapID " .. mapId)
    if not mapConfig then DebugPrint("Loadout GIVE ERROR: Map-Konfig nicht gefunden für MapID " .. mapId); return end
    if not mapConfig.weapons or #mapConfig.weapons == 0 then DebugPrint("Loadout GIVE WARNING: Keine Waffen in Config für MapID " .. mapId); if xPlayer then xPlayer.showNotification("Keine Waffen für diese Map konfiguriert.") end; return end
    DebugPrint("Loadout GIVE: Waffenkonfig für '" .. mapConfig.displayName .. "': " .. json.encode(mapConfig.weapons))
    playerCurrentFFALoadout[playerId] = {}
    if exports.ox_inventory then
        DebugPrint("Loadout GIVE: ox_inventory Export gefunden für Spieler " .. playerId)
        for i, weaponData in ipairs(mapConfig.weapons) do
            DebugPrint("Loadout GIVE: Verarbeite Waffe " .. i .. ": " .. json.encode(weaponData) .. " für Spieler " .. playerId)
            local weaponName = weaponData.name or weaponData.hash
            local weaponAmmo = tonumber(weaponData.ammo)
            if weaponName and weaponAmmo then
                weaponName = tostring(weaponName)
                local metadata = { ammo = weaponAmmo }
                DebugPrint("Loadout GIVE: Versuche ox_inventory:AddItem für Spieler " .. playerId .. " - Waffe: " .. weaponName .. ", Munition: " .. weaponAmmo)
                local success, itemData = exports.ox_inventory:AddItem(playerId, weaponName, 1, metadata)
                if success and itemData then
                    table.insert(playerCurrentFFALoadout[playerId], {name = weaponName, ammo = weaponAmmo})
                    DebugPrint("Loadout GIVE: Spieler " .. playerId .. " erhielt " .. weaponName .. " (Munition: " .. weaponAmmo .. ") via ox_inventory.")
                else
                    DebugPrint("Loadout GIVE ERROR: ox_inventory:AddItem für " .. weaponName .. " (Spieler: " .. playerId .. ") fehlgeschlagen. Erfolg: "..tostring(success))
                end
            else
                DebugPrint("Loadout GIVE WARNING: Ungültige Waffendaten für Spieler " .. playerId .. ": Name/Hash=" .. tostring(weaponName) .. ", Ammo=" .. tostring(weaponAmmo))
            end
        end
        if xPlayer then xPlayer.showNotification("FFA-Loadout für '" .. mapConfig.displayName .. "' erhalten.") end
        DebugPrint("Loadout GIVE: Prozess für Spieler " .. playerId .. " abgeschlossen. Finales getracktes Loadout: " .. json.encode(playerCurrentFFALoadout[playerId]))
    else
        DebugPrint("Loadout GIVE ERROR: ox_inventory Export nicht gefunden. Waffen können nicht gegeben werden für Spieler " .. playerId)
        if xPlayer then xPlayer.showNotification("Fehler: Inventarsystem nicht gefunden.") end
    end
end

local playerFFAState = {}

function RegisterPlayerToFFA(playerId, mapId)
    playerFFAState[playerId] = { mapId = mapId, isDead = false }
    if not playerStats[playerId] then
        playerStats[playerId] = { kills = 0, deaths = 0 }
    end
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if xPlayer then DebugPrint("Spieler " .. xPlayer.getName() .. " für FFA auf Map " .. mapId .. " registriert.") end
end

function UnregisterPlayerFromFFA(playerId)
    if playerFFAState[playerId] then
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then DebugPrint("Spieler " .. xPlayer.getName() .. " aus FFA deregistriert.")
        else DebugPrint("Spieler (ID: " .. playerId .. ") aus FFA deregistriert (offline/ungültig).") end
        playerFFAState[playerId] = nil
    end
end

RegisterNetEvent('ffa:playerDiedInMatch')
AddEventHandler('ffa:playerDiedInMatch', function(killerId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then return end
    if not playerFFAState[src] or playerFFAState[src].isDead then DebugPrint("Spieler " .. src .. " starb, nicht im FFA oder schon tot."); return end

    playerFFAState[src].isDead = true
    playerStats[src].deaths = playerStats[src].deaths + 1
    TriggerClientEvent('ffa:updateStats', src, playerStats[src])

    if killerId ~= -1 and killerId ~= src then
        local killerPlayer = ESX.GetPlayerFromId(killerId)
        if killerPlayer and playerStats[killerId] then
            playerStats[killerId].kills = playerStats[killerId].kills + 1
            TriggerClientEvent('ffa:updateStats', killerId, playerStats[killerId])
        end
    end

    TriggerClientEvent('ffa:updateLeaderboard', -1, getTopTenPlayers())

    local mapId = playerFFAState[src].mapId
    local mapConfig = getMapConfigById(mapId)
    if not mapConfig then DebugPrint("Konnte Map-Konfig für Tod nicht finden: " .. mapId); return end
    DebugPrint("Spieler " .. src .. " starb in FFA auf Map " .. mapConfig.displayName .. ". Killer: " .. killerId)

    Citizen.CreateThread(function()
        Wait(Config.RespawnDelay or 3000)
        if not playerFFAState[src] then DebugPrint("Spieler " .. src .. " hat FFA verlassen vor Respawn."); return end
        local currentXPlayer = ESX.GetPlayerFromId(src)
        if not currentXPlayer then DebugPrint("Spieler " .. src .. " offline vor Respawn."); UnregisterPlayerFromFFA(src); return end

        if not mapConfig.spawnPoints or #mapConfig.spawnPoints == 0 then
            DebugPrint("FEHLER: Keine Spawnpunkte für Respawn auf Map " .. mapId)
            currentXPlayer.showNotification("Fehler: Respawn nicht möglich (keine Spawns).")
            UnregisterPlayerFromFFA(src); TriggerClientEvent('ffa:playerLeftMatch', src); SetPlayerRoutingBucket(src, Config.DefaultRoutingBucket or 0)
            return
        end
        local randomSpawnPoint = mapConfig.spawnPoints[math.random(1, #mapConfig.spawnPoints)]

        if randomSpawnPoint and randomSpawnPoint.x and randomSpawnPoint.y and randomSpawnPoint.z then
            TriggerClientEvent('ffa:setClientPedCoords', src, { x = tonumber(randomSpawnPoint.x), y = tonumber(randomSpawnPoint.y), z = tonumber(randomSpawnPoint.z), heading = randomSpawnPoint.h or 0.0 })
            currentXPlayer.triggerEvent('esx_ambulancejob:revive', src)
            Wait(150)
        else
            DebugPrint("FEHLER: Kritischer Fehler bei Respawn-Definition (Koordinaten).")
            currentXPlayer.showNotification("Fehler: Kritischer Fehler bei Respawn-Definition.")
            currentXPlayer.triggerEvent('esx_ambulancejob:revive', src)
            UnregisterPlayerFromFFA(src); TriggerClientEvent('ffa:playerLeftMatch', src); SetPlayerRoutingBucket(src, Config.DefaultRoutingBucket or 0)
            return
        end

        local pedRespawn = GetPlayerPed(src)
        if pedRespawn and pedRespawn ~= 0 then
            TriggerClientEvent('ffa:setClientPedHealthArmor', src, GetEntityMaxHealth(pedRespawn), 100)
        else
            DebugPrint("FEHLER: Konnte Ped für Health/Armor Set beim Respawn nicht bekommen.")
        end

        DebugPrint("RESPAWN: Rufe GivePlayerMapLoadout für Spieler " .. src)
        GivePlayerMapLoadout(src, mapId)
        DebugPrint("RESPAWN: GivePlayerMapLoadout abgeschlossen für Spieler " .. src)

        playerFFAState[src].isDead = false
        TriggerClientEvent('ffa:playerRespawned', src)
        DebugPrint("Spieler " .. src .. " Respawn-Prozess abgeschlossen.")
    end)
end)

DebugPrint("FFA Script Server-Seite geladen und Lobby-System, Loadout-Funktion sowie Respawn-System initialisiert.")
