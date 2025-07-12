ESX = exports["es_extended"]:getSharedObject()

local activeLobbies = {}
local playerLobbyMap = {}

local function generateLobbyId()
    return string.format("lobby_%s", math.random(1000, 9999))
end

function getMapConfigById(mapId)
    for _, mapConfig in ipairs(Config.Maps) do
        if mapConfig.id == mapId then
            return mapConfig
        end
    end
    return nil
end

RegisterNetEvent('ffa:createLobby')
AddEventHandler('ffa:createLobby', function(lobbyData)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local mapConfig = getMapConfigById(lobbyData.mapId)
    if not mapConfig then
        xPlayer.showNotification("Ungültige Karte ausgewählt.")
        return
    end

    local newLobbyId = generateLobbyId()
    local newLobby = {
        id = newLobbyId,
        name = lobbyData.lobbyName,
        mapId = lobbyData.mapId,
        mapDetails = mapConfig,
        maxPlayers = tonumber(lobbyData.maxPlayers) or 16,
        password = lobbyData.password and lobbyData.password ~= "" and lobbyData.password or nil,
        duration = tonumber(lobbyData.duration) or 15,
        weapons = lobbyData.weapons or {},
        players = {},
        playerCount = 0
    }

    activeLobbies[newLobbyId] = newLobby
    DebugPrint("Neue Lobby erstellt: " .. newLobby.name .. " (ID: " .. newLobbyId .. ")")

    -- Automatically join the player to the lobby they created
    TriggerEvent('ffa:joinLobby', newLobbyId, src)
end)

RegisterNetEvent('ffa:joinLobby')
AddEventHandler('ffa:joinLobby', function(lobbyId, customSrc)
    local src = customSrc or source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then DebugPrint("Spieler " .. src .. " nicht gefunden."); return end
    if playerLobbyMap[src] then DebugPrint("Spieler " .. xPlayer.getName() .. " bereits in Lobby " .. playerLobbyMap[src]); TriggerEvent('ffa:leaveLobby', playerLobbyMap[src], src) end

    local lobby = activeLobbies[lobbyId]
    if not lobby then
        xPlayer.showNotification("Lobby nicht gefunden.")
        return
    end

    -- Password check
    if lobby.password then
        xPlayer.showNotification("Diese Lobby ist passwortgeschützt.")
        return
    end

    if lobby.playerCount >= lobby.maxPlayers then
        xPlayer.showNotification("Die Lobby ist bereits voll.")
        return
    end

    local mapConfig = lobby.mapDetails
    if not mapConfig then DebugPrint("Ungültige Map-ID in Lobby " .. lobbyId); return end

    playerLobbyMap[src] = lobbyId
    lobby.players[src] = xPlayer
    lobby.playerCount = lobby.playerCount + 1

    xPlayer.showNotification("Du bist der Lobby '" .. lobby.name .. "' beigetreten.")

    -- Teleport player to map, give weapons, etc.
    -- This part needs to be integrated with the existing FFA logic

    TriggerClientEvent('ffa:updateLobbyView', -1, lobbyId, lobby.players, lobby.playerCount)
    TriggerEvent('ffa:requestLobbies') -- Update everyone's lobby list
end)

RegisterNetEvent('ffa:leaveLobby')
AddEventHandler('ffa:leaveLobby', function(customLobbyId, customSrc)
    local src = customSrc or source
    local xPlayer = ESX.GetPlayerFromId(src)

    if not xPlayer then DebugPrint("Spieler " .. src .. " nicht gefunden."); return end
    local lobbyId = customLobbyId or playerLobbyMap[src]
    if not lobbyId then xPlayer.showNotification("Du bist in keiner FFA-Lobby."); return end
    local lobby = activeLobbies[lobbyId]
    if not lobby or not lobby.players[src] then return end

    local lobbyName = lobby.name
    DebugPrint("FFA Leave: Spieler " .. src .. " verlässt FFA für Lobby " .. lobbyName)

    playerLobbyMap[src] = nil
    lobby.players[src] = nil
    lobby.playerCount = lobby.playerCount - 1

    xPlayer.showNotification("Du hast die Lobby '" .. lobbyName .. "' verlassen.")

    if lobby.playerCount == 0 then
        activeLobbies[lobbyId] = nil
        DebugPrint("Lobby " .. lobbyId .. " ist leer und wird entfernt.")
    end

    -- This part needs to be integrated with the existing FFA logic to teleport the player back

    TriggerClientEvent('ffa:updateLobbyView', -1, lobbyId, {}, 0)
    TriggerEvent('ffa:requestLobbies') -- Update everyone's lobby list
end)

RegisterNetEvent('ffa:requestLobbies')
AddEventHandler('ffa:requestLobbies', function()
    local src = source
    local lobbies = {}
    for lobbyId, lobby in pairs(activeLobbies) do
        table.insert(lobbies, {
            id = lobby.id,
            name = lobby.name,
            mapName = lobby.mapDetails.displayName,
            currentPlayers = lobby.playerCount,
            maxPlayers = lobby.maxPlayers,
            hasPassword = lobby.password ~= nil
        })
    end
    TriggerClientEvent('ffa:updateLobbyList', src, lobbies)
end)

AddEventHandler('esx:playerDropped', function(playerId, reason)
    local lobbyId = playerLobbyMap[playerId]
    if lobbyId then
        local lobby = activeLobbies[lobbyId]
        if lobby and lobby.players[playerId] then
            lobby.players[playerId] = nil
            lobby.playerCount = lobby.playerCount - 1
            if lobby.playerCount == 0 then
                activeLobbies[lobbyId] = nil
            end
            playerLobbyMap[playerId] = nil
            TriggerEvent('ffa:requestLobbies')
        end
    end
end)
