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
local playerOriginalInventory = {} -- NEU: Zum Speichern des Original-Inventars

local function getMapConfigById(mapId)
    for _, mapConfig in ipairs(Config.Maps) do
        if mapConfig.id == mapId then
            return mapConfig
        end
    end
    return nil
end

-- Funktion zum Speichern des aktuellen Inventars und zum Leeren (oder nur Waffen entfernen)
local function StoreAndClearPlayerInventoryForFFA(playerId, mapWeapons)
    if not exports.ox_inventory then
        DebugPrint("Store/Clear ERROR: ox_inventory Export nicht gefunden.")
        return false
    end

    -- 1. Originalinventar speichern
    local currentInventory = exports.ox_inventory:GetInventory(playerId)
    if currentInventory then
        playerOriginalInventory[playerId] = currentInventory
        DebugPrint("Store/Clear: Originalinventar für Spieler " .. playerId .. " gespeichert: " .. json.encode(currentInventory))
    else
        DebugPrint("Store/Clear WARNING: Konnte Originalinventar für Spieler " .. playerId .. " nicht abrufen.")
        playerOriginalInventory[playerId] = nil -- Sicherstellen, dass kein altes verwendet wird
    end

    -- 2. Bestehende Waffen (insbesondere die, die im neuen Loadout sind) entfernen, um Duplikate zu vermeiden
    --    Oder alternativ: Alle Waffen entfernen. Für FFA ist es oft sauberer, nur die FFA-Waffen zu haben.
    --    Hier entfernen wir gezielt Waffen, die im neuen Loadout vorkommen, falls sie schon da sind.
    --    Eine aggressivere Methode wäre, alle Waffen zu entfernen: exports.ox_inventory:RemoveItem(playerId, 'weapon_.*', nil, nil, true) -- Regex, falls unterstützt
    --    oder durch alle Slots iterieren und Waffen entfernen.
    --    Fürs Erste: Gezieltes Entfernen von Waffen, die im FFA-Loadout vorkommen.
    if mapWeapons and #mapWeapons > 0 then
        for _, weaponData in ipairs(mapWeapons) do
            local count = exports.ox_inventory:Search('count', weaponData.name, playerId)
            if count and count > 0 then
                exports.ox_inventory:RemoveItem(playerId, weaponData.name, count)
                DebugPrint("Store/Clear: Vorhandene Instanz von " .. weaponData.name .. " (" .. count .. ") aus Inventar von Spieler " .. playerId .. " entfernt vor FFA-Loadout.")
            end
        end
    end
    -- TODO: Hier könnte man auch andere Item-Typen entfernen, die im FFA nicht erlaubt sein sollen (z.B. Rüstung, Essen).

    return true
end

-- Funktion zum Wiederherstellen des Originalinventars
local function RestorePlayerOriginalInventory(playerId)
    if not exports.ox_inventory then
        DebugPrint("Restore ERROR: ox_inventory Export nicht gefunden.")
        return
    end

    if playerOriginalInventory[playerId] then
        DebugPrint("Restore: Versuche Originalinventar für Spieler " .. playerId .. " wiederherzustellen. Gespeichertes Inventar: " .. json.encode(playerOriginalInventory[playerId]))

        -- Da SetInventory nicht existiert, iterieren wir durch die gespeicherten Items und fügen sie einzeln hinzu.
        -- Wir gehen davon aus, dass playerOriginalInventory[playerId] die Struktur hat, die GetInventory zurückgibt,
        -- und dass es eine Tabelle 'items' enthält oder direkt eine Liste von Item-Objekten ist.
        -- ox_inventory:GetInventory gibt oft eine Tabelle zurück, wo die Schlüssel Slot-IDs sind.

        local inventoryData = playerOriginalInventory[playerId]
        local itemsToRestore = inventoryData.items or inventoryData -- Fallback, falls es direkt eine Item-Liste ist

        if type(itemsToRestore) == "table" then
            -- Optional: Inventar leeren, bevor Items hinzugefügt werden? Vorsicht!
            -- exports.ox_inventory:ClearInventory(playerId)
            -- DebugPrint("Restore: Inventar für Spieler " .. playerId .. " vor Restore geleert (ClearInventory).")

            for slot, itemData in pairs(itemsToRestore) do
                if type(itemData) == 'table' and itemData.name and itemData.amount then
                    -- Stelle sicher, dass Metadaten, falls nicht vorhanden, eine leere Tabelle sind, um Fehler zu vermeiden
                    local metadata = itemData.metadata or {}
                    -- Der Slot-Parameter bei AddItem ist oft optional oder dient als Vorschlag.
                    -- Wenn wir den exakten Slot wiederherstellen wollen, müssen wir sicherstellen, dass der Slot frei ist oder AddItem das handhaben kann.
                    local success, addedItem = exports.ox_inventory:AddItem(playerId, itemData.name, itemData.amount, metadata, itemData.slot)
                    if success and addedItem then
                        DebugPrint("Restore: Item " .. itemData.name .. " (x" .. itemData.amount .. ") für Spieler " .. playerId .. " in Slot " .. tostring(itemData.slot) .. " wiederhergestellt.")
                    else
                        DebugPrint("Restore WARNING: Konnte Item " .. itemData.name .. " (x" .. itemData.amount .. ") für Spieler " .. playerId .. " nicht wiederherstellen. Erfolg: " .. tostring(success))
                    end
                else
                    DebugPrint("Restore WARNING: Ungültige Item-Daten im gespeicherten Inventar für Spieler " .. playerId .. " bei Slot/Index " .. tostring(slot) .. ": " .. json.encode(itemData))
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
            else
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

    if not xPlayer then DebugPrint("Spieler " .. src .. " nicht gefunden."); return end
    if playerLobbyMap[src] then DebugPrint("Spieler " .. xPlayer.getName() .. " bereits in Lobby " .. playerLobbyMap[src]); TriggerEvent('ffa:leaveLobby', playerLobbyMap[src], src) end

    local mapConfig = getMapConfigById(mapId)
    if not mapConfig then DebugPrint("Ungültige Map-ID " .. mapId); return end

    local ped = GetPlayerPed(src)
    if ped and ped ~= 0 then
        local currentCoords = GetEntityCoords(ped)
        local currentHeading = GetEntityHeading(ped)
        playerLastLocation[src] = {x = currentCoords.x, y = currentCoords.y, z = currentCoords.z, heading = currentHeading}
        DebugPrint("Position für Spieler " .. src .. " gespeichert: " .. json.encode(playerLastLocation[src]))
    else
        DebugPrint("WARNUNG: Konnte Ped für Spieler " .. src .. " nicht bekommen, um Position zu speichern.")
        playerLastLocation[src] = nil
    end

    -- Inventar sichern und für FFA vorbereiten
    if not StoreAndClearPlayerInventoryForFFA(src, mapConfig.weapons) then
        xPlayer.showNotification("Fehler bei der Inventarvorbereitung.")
        if playerLastLocation[src] then playerLastLocation[src] = nil end
        return -- Abbruch, wenn Inventar nicht vorbereitet werden kann
    end

    if not activeLobbies[mapId] then
        activeLobbies[mapId] = { players = {}, mapDetails = mapConfig, playerCount = 0 }
        DebugPrint("Lobby für Map '" .. mapConfig.displayName .. "' erstellt.")
    end

    if activeLobbies[mapId].playerCount >= mapConfig.maxPlayers then
        DebugPrint("Lobby für Map '" .. mapConfig.displayName .. "' ist voll.")
        xPlayer.showNotification("Die Lobby für " .. mapConfig.displayName .. " ist bereits voll.")
        RestorePlayerOriginalInventory(src) -- Gespeichertes Inventar zurückgeben, da Join fehlschlug
        if playerLastLocation[src] then playerLastLocation[src] = nil end
        return
    end

    activeLobbies[mapId].players[src] = xPlayer
    activeLobbies[mapId].playerCount = activeLobbies[mapId].playerCount + 1
    playerLobbyMap[src] = mapId
    xPlayer.showNotification("Du bist der Lobby für " .. mapConfig.displayName .. " beigetreten.")
    TriggerClientEvent('ffa:updateLobbyView', -1, mapId, activeLobbies[mapId].players, activeLobbies[mapId].playerCount)

    if not mapConfig.spawnPoints or #mapConfig.spawnPoints == 0 then
        DebugPrint("FEHLER: Keine Spawnpunkte für Map " .. mapId)
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
        local newX, newY, newZ = tonumber(randomSpawn.x), tonumber(randomSpawn.y), tonumber(randomSpawn.z)
        if newX and newY and newZ then
            TriggerClientEvent('ffa:setClientPedCoords', src, { x = newX, y = newY, z = newZ, heading = randomSpawn.h or 0.0 })
        else
            DebugPrint("FEHLER: Ungültige Spawnpunkt-Koordinaten.")
            xPlayer.showNotification("Fehler: Ungültige Spawnpunkt-Koordinaten.")
            TriggerEvent('ffa:leaveLobby', mapId, src)
            return
        end
    else
        DebugPrint("FEHLER: Kritischer Fehler bei Spawnpunkt-Definition.")
        xPlayer.showNotification("Fehler: Kritischer Fehler bei Spawnpunkt-Definition.")
        TriggerEvent('ffa:leaveLobby', mapId, src)
        return
    end

    GivePlayerMapLoadout(src, mapId)
    RegisterPlayerToFFA(src, mapId)

    if ped and ped ~= 0 then -- Ped von oben wiederverwenden
        local maxHealth = GetEntityMaxHealth(ped)
        TriggerClientEvent('ffa:setClientPedHealthArmor', src, maxHealth, 100)
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
    if not mapId then DebugPrint("Spieler " .. src .. " nicht in Lobby."); xPlayer.showNotification("Du bist in keiner FFA-Lobby."); return end
    if not activeLobbies[mapId] or not activeLobbies[mapId].players[src] then DebugPrint("Spieler " .. src .. " nicht in aktiver Lobby."); return end

    local mapDisplayName = activeLobbies[mapId].mapDetails.displayName

    RemovePlayerFFALoadout(src)
    RestorePlayerOriginalInventory(src) -- Originalinventar wiederherstellen

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

    if activeLobbies[mapId].playerCount == 0 then
        DebugPrint("Lobby für Map '" .. mapDisplayName .. "' ist leer und wird aufgelöst.")
        activeLobbies[mapId] = nil
    end
    TriggerClientEvent('ffa:updateLobbyView', -1, mapId, activeLobbies[mapId] and activeLobbies[mapId].players or {}, activeLobbies[mapId] and activeLobbies[mapId].playerCount or 0)
end)

AddEventHandler('esx:playerDropped', function(playerId, reason)
    local currentMapId = playerLobbyMap[playerId]
    DebugPrint("Spieler (ID: " .. playerId .. ") hat Server verlassen. Grund: " .. reason .. ". Map-ID: " .. tostring(currentMapId))

    if currentMapId then
        RemovePlayerFFALoadout(playerId)
        -- Original Inventar bei Disconnect wiederherstellen (Best-Effort, da Spieler offline)
        -- ox_inventory könnte dies ggf. nicht mehr verarbeiten. Sicherer wäre DB-Speicherung.
        -- Vorerst versuchen wir es direkt, wenn ox_inventory noch reagiert.
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

    -- playerCurrentFFALoadout[playerId] wird hier nicht mehr direkt gelöscht, da StoreAndClear dies implizit tun sollte bzw. RemovePlayerFFALoadout
    -- Stattdessen wird es neu aufgebaut.
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
            local respawnX, respawnY, respawnZ = tonumber(randomSpawnPoint.x), tonumber(randomSpawnPoint.y), tonumber(randomSpawnPoint.z)
            if respawnX and respawnY and respawnZ then
                xPlayer.triggerEvent('esx_ambulancejob:revive', src)
                Wait(150)
                TriggerClientEvent('ffa:setClientPedCoords', src, { x = respawnX, y = respawnY, z = respawnZ, heading = randomSpawnPoint.h or 0.0 })
            else
                DebugPrint("FEHLER: Ungültige Respawn-Koordinaten.")
                xPlayer.showNotification("Fehler: Ungültige Respawn-Koordinaten.")
                xPlayer.triggerEvent('esx_ambulancejob:revive', src)
                UnregisterPlayerFromFFA(src); TriggerClientEvent('ffa:playerLeftMatch', src); SetPlayerRoutingBucket(src, Config.DefaultRoutingBucket or 0)
                return
            end
        else
            DebugPrint("FEHLER: Kritischer Fehler bei Respawn-Definition.")
            xPlayer.showNotification("Fehler: Kritischer Fehler bei Respawn-Definition.")
            xPlayer.triggerEvent('esx_ambulancejob:revive', src)
            UnregisterPlayerFromFFA(src); TriggerClientEvent('ffa:playerLeftMatch', src); SetPlayerRoutingBucket(src, Config.DefaultRoutingBucket or 0)
            return
        end

        local pedRespawn = GetPlayerPed(src)
        if pedRespawn and pedRespawn ~= 0 then
            local maxHealthRespawn = GetEntityMaxHealth(pedRespawn)
            TriggerClientEvent('ffa:setClientPedHealthArmor', src, maxHealthRespawn, 100)
        else
            DebugPrint("FEHLER: Konnte Ped für Health/Armor Set beim Respawn nicht bekommen.")
        end

        GivePlayerMapLoadout(src, mapId) -- Gibt Waffen erneut via ox_inventory

        playerFFAState[src].isDead = false
        TriggerClientEvent('ffa:playerRespawned', src)
        DebugPrint("Spieler " .. src .. " Respawn-Prozess abgeschlossen.")
    end)
end)

DebugPrint("FFA Script Server-Seite geladen und Lobby-System, Loadout-Funktion sowie Respawn-System initialisiert.")
