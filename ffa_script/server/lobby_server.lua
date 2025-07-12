ESX = exports["es_extended"]:getSharedObject()

local lobbies = {}
local nextLobbyId = 1

for i, map in ipairs(Config.Maps) do
    table.insert(lobbies, {
        id = nextLobbyId,
        name = map.displayName,
        players = 0,
        maxPlayers = map.maxPlayers,
        mapId = map.id,
        weapons = map.weapons,
        isPermanent = true -- Mark permanent lobbies
    })
    nextLobbyId = nextLobbyId + 1
end

function getPlayerStats(playerId)
    -- Diese Funktion müsste implementiert werden, um die echten Spielerstatistiken abzurufen
    return {
        kd = 1.5,
        kills = 150,
        deaths = 100
    }
end

function getLeaderboard()
    -- Diese Funktion müsste implementiert werden, um die echte Rangliste abzurufen
    return {
        { name = 'Player1', kd = 2.5 },
        { name = 'Player2', kd = 2.1 },
        { name = 'Player3', kd = 1.8 },
    }
end

RegisterNetEvent('esx_ffa:createLobby')
AddEventHandler('esx_ffa:createLobby', function(data)
    local src = source
    local map = nil
    for _, m in ipairs(Config.Maps) do
        if m.id == data.map then
            map = m
            break
        end
    end

    if not map then
        print('[FFA_SCRIPT][SERVER] Invalid map received from client: ' .. data.map)
        return
    end

    local newLobby = {
        id = nextLobbyId,
        name = data.name,
        players = 0,
        maxPlayers = map.maxPlayers,
        mapId = map.id,
        weapons = data.weapons,
        owner = src
    }
    table.insert(lobbies, newLobby)
    nextLobbyId = nextLobbyId + 1
    TriggerClientEvent('esx_ffa:updateLobbies', -1, lobbies)
end)

RegisterNetEvent('esx_ffa:joinLobby')
AddEventHandler('esx_ffa:joinLobby', function(lobbyId)
    local src = source
    for i, lobby in ipairs(lobbies) do
        if lobby.id == lobbyId then
            -- Hier müsste die Logik zum Beitreten der Lobby implementiert werden
            print('Player ' .. GetPlayerName(src) .. ' joined lobby ' .. lobby.name .. ' with mapId ' .. lobby.mapId)
            break
        end
    end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    -- Hier müsste die Logik implementiert werden, um den Spieler aus allen Lobbies zu entfernen
end)

ESX.RegisterCommand('ffa', 'user', function(xPlayer, args, showError)
    local src = xPlayer.source
    local playerStats = getPlayerStats(src)
    local leaderboard = getLeaderboard()
    TriggerClientEvent('esx_ffa:openMenu', src, lobbies, playerStats, leaderboard, Config.Maps, Config.Weapons)
end, false, { help = 'Öffnet das FFA Menü' })

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(5000)
        TriggerClientEvent('esx_ffa:updateLobbies', -1, lobbies)
    end
end)
