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

local function StoreAndClearPlayerInventoryForFFA(playerId, mapWeapons)
    if not exports.ox_inventory then
        DebugPrint("Store/Clear ERROR: ox_inventory Export nicht gefunden.")
        return false
    end

    playerOriginalInventory[playerId] = exports.ox_inventory:GetInventory(playerId)
    if playerOriginalInventory[playerId] then
        DebugPrint("Store/Clear: Originalinventar für Spieler " .. playerId .. " gespeichert.")

        -- Alle Waffen aus dem Originalinventar entfernen, bevor das FFA-Loadout gegeben wird
        local itemsToRemove = {}
        if playerOriginalInventory[playerId].items then
            for slot, itemData in pairs(playerOriginalInventory[playerId].items) do
                -- Annahme: Waffen haben "weapon_" im Namen oder einen spezifischen Typ, falls ox_inventory das liefert
                -- Sicherer ist es, alle Items zu entfernen, die Waffen sind.
                -- Für diese Iteration gehen wir davon aus, dass wir alle Waffen entfernen wollen.
                -- Man könnte hier spezifischer filtern, wenn nur bestimmte Waffen weg sollen.
                if itemData.name and string.find(itemData.name, "weapon_") then
                    table.insert(itemsToRemove, {name = itemData.name, amount = itemData.amount})
                end
            end
        end

        if #itemsToRemove > 0 then
            DebugPrint("Store/Clear: Folgende Waffen werden aus dem Originalinventar von Spieler " .. playerId .. " entfernt: " .. json.encode(itemsToRemove))
            for _, itemToRemove in ipairs(itemsToRemove) do
                exports.ox_inventory:RemoveItem(playerId, itemToRemove.name, itemToRemove.amount)
            end
            DebugPrint("Store/Clear: Waffen aus Originalinventar von Spieler " .. playerId .. " entfernt.")
        else
            DebugPrint("Store/Clear: Keine Waffen im Originalinventar von Spieler " .. playerId .. " gefunden zum Entfernen.")
        end
    else
        DebugPrint("Store/Clear WARNING: Konnte Originalinventar für Spieler " .. playerId .. " nicht abrufen. Inventar wird nicht geleert.")
        -- Nicht `false` zurückgeben, da das FFA trotzdem starten kann, aber der Spieler hat evtl. noch alte Waffen.
    end
    return true
end

local function RestorePlayerOriginalInventory(playerId)
    if not exports.ox_inventory then
        DebugPrint("Restore ERROR: ox_inventory Export nicht gefunden."); return
    end

    if playerOriginalInventory[playerId] then
        DebugPrint("Restore: Versuche Originalinventar für Spieler " .. playerId .. " wiederherzustellen.")

        -- Zuerst sicherstellen, dass das aktuelle Inventar (das nur FFA-Items enthalten sollte, die schon entfernt wurden) leer ist,
        -- oder zumindest keine Konflikte verursacht. Ein ClearInventory wäre zu drastisch, wenn FFA-Items nicht 100% entfernt wurden.
        -- Wir verlassen uns darauf, dass RemovePlayerFFALoadout seinen Job gemacht hat.

        local inventoryData = playerOriginalInventory[playerId]
        local itemsToRestore = inventoryData.items or inventoryData

        if type(itemsToRestore) == "table" then
            for slot, itemData in pairs(itemsToRestore) do
                if type(itemData) == 'table' and itemData.name and itemData.amount then
                    local metadata = itemData.metadata or {}
                    local success, addedItem = exports.ox_inventory:AddItem(playerId, itemData.name, itemData.amount, metadata, itemData.slot)
                    if success and addedItem then
                        -- DebugPrint("Restore: Item " .. itemData.name .. " (x" .. itemData.amount .. ") für Spieler " .. playerId .. " in Slot " .. tostring(itemData.slot) .. " wiederhergestellt.")
                    else
                        DebugPrint("Restore WARNING: Konnte Item " .. itemData.name .. " (x" .. itemData.amount .. ") für Spieler " .. playerId .. " nicht wiederherstellen. Erfolg: " .. tostring(success))
                    end
                end
            end
            DebugPrint("Restore: Manueller Wiederherstellungsprozess für Spieler " .. playerId .. " abgeschlossen.")
        else
            DebugPrint("Restore ERROR: Gespeicherte Inventardaten für Spieler " .. playerId .. " haben nicht die erwartete Tabellenstruktur für Items.")
        end
        playerOriginalInventory[playerId] = nil
    else
        DebugPrint("Restore WARNING: Kein Originalinventar für Spieler " .. playerId .. " zum Wiederherstellen gefunden.")
    end
end

local function RemovePlayerFFALoadout(playerId)
    if exports.ox_inventory and playerCurrentFFALoadout[playerId] and #playerCurrentFFALoadout[playerId] > 0 then
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
            else
                DebugPrint("Loadout Removal INFO: Waffe " .. weaponData.name .. " nicht im Inventar von Spieler " .. playerId .. " gefunden (Anzahl 0 oder weniger).")
            end
        end
        playerCurrentFFALoadout[playerId] = nil
    elseif not exports.ox_inventory then
        DebugPrint("Loadout Removal ERROR: ox_inventory Export nicht gefunden.")
    elseif not playerCurrentFFALoadout[playerId] or #playerCurrentFFALoadout[playerId] == 0 then
        DebugPrint("Loadout Removal INFO: Kein FFA-Loadout für Spieler " .. playerId .. " getrackt zum Entfernen.")
    end
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

    if not StoreAndClearPlayerInventoryForFFA(src, mapConfig.weapons) then
        xPlayer.showNotification("Fehler bei der Inventarvorbereitung für FFA.")
        if playerLastLocation[src] then playerLastLocation[src] = nil end
        return
    end

    if not activeLobbies[mapId] then
        activeLobbies[mapId] = { players = {}, mapDetails = mapConfig, playerCount = 0 }
    end

    if activeLobbies[mapId].playerCount >= mapConfig.maxPlayers then
        xPlayer.showNotification("Die Lobby für " .. mapConfig.displayName .. " ist bereits voll.")
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

    GivePlayerMapLoadout(src, mapId)
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

    RemovePlayerFFALoadout(src)
    RestorePlayerOriginalInventory(src)

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
end)

AddEventHandler('esx:playerDropped', function(playerId, reason)
    local currentMapId = playerLobbyMap[playerId]
    DebugPrint("Spieler (ID: " .. playerId .. ") hat Server verlassen. Grund: " .. reason .. ". Map-ID: " .. tostring(currentMapId))

    if currentMapId then
        RemovePlayerFFALoadout(playerId)
        RestorePlayerOriginalInventory(playerId)
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
end)

function GivePlayerMapLoadout(playerId, mapId)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    local mapConfig = getMapConfigById(mapId)

    DebugPrint("Loadout: GivePlayerMapLoadout für Spieler " .. playerId .. ", MapID " .. mapId)
    if not mapConfig then DebugPrint("Loadout ERROR: Map-Konfig nicht gefunden."); return end
    if not mapConfig.weapons or #mapConfig.weapons == 0 then DebugPrint("Loadout WARNING: Keine Waffen in Config."); if xPlayer then xPlayer.showNotification("Keine Waffen für diese Map konfiguriert.") end; return end
    DebugPrint("Loadout: Waffenkonfig: " .. json.encode(mapConfig.weapons))

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
                    DebugPrint("Loadout: Spieler " .. playerId .. " erhielt " .. weaponName .. " via ox_inventory.")
                else
                    DebugPrint("Loadout ERROR: ox_inventory:AddItem für " .. weaponName .. " fehlgeschlagen. Erfolg: "..tostring(success))
                end
            else
                DebugPrint("Loadout WARNING: Ungültige Waffendaten: Name=" .. tostring(weaponData.name) .. ", Ammo=" .. tostring(weaponData.ammo))
            end
        end
        if xPlayer then xPlayer.showNotification("FFA-Loadout für '" .. mapConfig.displayName .. "' erhalten.") end
        DebugPrint("Loadout: Prozess für Spieler " .. playerId .. " abgeschlossen.")
    else
        DebugPrint("Loadout ERROR: ox_inventory Export nicht gefunden.")
        if xPlayer then xPlayer.showNotification("Fehler: Inventarsystem nicht gefunden.") end
    end
end

local playerFFAState = {}

function RegisterPlayerToFFA(playerId, mapId)
    playerFFAState[playerId] = { mapId = mapId, isDead = false }
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
    local mapId = playerFFAState[src].mapId
    local mapConfig = getMapConfigById(mapId)
    if not mapConfig then DebugPrint("Konnte Map-Konfig für Tod nicht finden: " .. mapId); return end
    DebugPrint("Spieler " .. src .. " starb in FFA auf Map " .. mapConfig.displayName .. ". Killer: " .. killerId)

    Citizen.CreateThread(function()
        Wait(Config.RespawnDelay or 3000)
        if not playerFFAState[src] then DebugPrint("Spieler " .. src .. " hat FFA verlassen vor Respawn."); return end
        if not ESX.GetPlayerFromId(src) then DebugPrint("Spieler " .. src .. " offline vor Respawn."); UnregisterPlayerFromFFA(src); return end

        if not mapConfig.spawnPoints or #mapConfig.spawnPoints == 0 then
            DebugPrint("FEHLER: Keine Spawnpunkte für Respawn auf Map " .. mapId)
            xPlayer.showNotification("Fehler: Respawn nicht möglich (keine Spawns).")
            UnregisterPlayerFromFFA(src); TriggerClientEvent('ffa:playerLeftMatch', src); SetPlayerRoutingBucket(src, Config.DefaultRoutingBucket or 0)
            return
        end
        local randomSpawnPoint = mapConfig.spawnPoints[math.random(1, #mapConfig.spawnPoints)]

        if randomSpawnPoint and randomSpawnPoint.x and randomSpawnPoint.y and randomSpawnPoint.z then
            TriggerClientEvent('ffa:setClientPedCoords', src, { x = tonumber(randomSpawnPoint.x), y = tonumber(randomSpawnPoint.y), z = tonumber(randomSpawnPoint.z), heading = randomSpawnPoint.h or 0.0 })
            xPlayer.triggerEvent('esx_ambulancejob:revive', src)
            Wait(150) -- Wait for revive to potentially complete before other actions
        else
            DebugPrint("FEHLER: Kritischer Fehler bei Respawn-Definition (Koordinaten).")
            xPlayer.showNotification("Fehler: Kritischer Fehler bei Respawn-Definition.")
            xPlayer.triggerEvent('esx_ambulancejob:revive', src)
            UnregisterPlayerFromFFA(src); TriggerClientEvent('ffa:playerLeftMatch', src); SetPlayerRoutingBucket(src, Config.DefaultRoutingBucket or 0)
            return
        end

        local pedRespawn = GetPlayerPed(src)
        if pedRespawn and pedRespawn ~= 0 then
            TriggerClientEvent('ffa:setClientPedHealthArmor', src, GetEntityMaxHealth(pedRespawn), 100)
        else
            DebugPrint("FEHLER: Konnte Ped für Health/Armor Set beim Respawn nicht bekommen.")
        end

        GivePlayerMapLoadout(src, mapId)

        playerFFAState[src].isDead = false
        TriggerClientEvent('ffa:playerRespawned', src)
        DebugPrint("Spieler " .. src .. " Respawn-Prozess abgeschlossen.")
    end)
end)

DebugPrint("FFA Script Server-Seite geladen und Lobby-System, Loadout-Funktion sowie Respawn-System initialisiert.")
