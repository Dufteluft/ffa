ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local lobbies = {
    { id = 1, name = 'Standard Map 1', players = 5, maxPlayers = 10, map = 'Standard Map 1', weapons = {'Pistol', 'SMG'} },
    { id = 2, name = 'Standard Map 2', players = 8, maxPlayers = 10, map = 'Standard Map 2', weapons = {'Assault Rifle', 'Sniper Rifle'} },
    { id = 3, name = 'Standard Map 3', players = 2, maxPlayers = 10, map = 'Standard Map 3', weapons = {'Shotgun'} },
}

local nextLobbyId = 4

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
    local newLobby = {
        id = nextLobbyId,
        name = data.name,
        players = 0,
        maxPlayers = 10, -- oder einen Wert aus data
        map = data.map,
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
            print('Player ' .. GetPlayerName(src) .. ' joined lobby ' .. lobby.name)
            break
        end
    end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    -- Hier müsste die Logik implementiert werden, um den Spieler aus allen Lobbies zu entfernen
end)

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

ESX.RegisterCommand('ffa', 'user', function(xPlayer, args, showError)
    local src = xPlayer.source
    local playerStats = getPlayerStats(src)
    local leaderboard = getLeaderboard()
    TriggerClientEvent('esx_ffa:openMenu', src, lobbies, playerStats, leaderboard)
end, false, { help = 'Öffnet das FFA Menü' })
