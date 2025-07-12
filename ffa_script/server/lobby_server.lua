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

    local validWeapons = {}
    for _, clientWeapon in ipairs(data.weapons) do
        for _, configWeapon in ipairs(Config.Weapons) do
            if clientWeapon.name == configWeapon.name then
                table.insert(validWeapons, clientWeapon)
                break
            end
        end
    end

    local newLobby = {
        id = nextLobbyId,
        name = data.name,
        players = 0,
        maxPlayers = map.maxPlayers,
        mapId = map.id,
        weapons = validWeapons,
        owner = src
    }
    table.insert(lobbies, newLobby)
    nextLobbyId = nextLobbyId + 1
    TriggerClientEvent('esx_ffa:updateLobbies', -1, lobbies)
end)

RegisterNetEvent('esx_ffa:joinLobby')
AddEventHandler('esx_ffa:joinLobby', function(lobbyId, mapId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local lobby = nil
    for i, l in ipairs(lobbies) do
        if l.id == lobbyId then
            lobby = l
            break
        end
    end

    if not lobby then
        print('[FFA_SCRIPT][SERVER] Invalid lobbyId received from client: ' .. lobbyId)
        return
    end

    if lobby.mapId ~= mapId then
        print('[FFA_SCRIPT][SERVER] Map ID mismatch. Lobby has mapId ' .. lobby.mapId .. ' but received ' .. mapId)
        return
    end

    local map = nil
    for i, m in ipairs(Config.Maps) do
        if m.id == mapId then
            map = m
            break
        end
    end

    if not map then
        print('[FFA_SCRIPT][SERVER] Could not find map with id: ' .. mapId)
        return
    end

    -- Set routing bucket
    SetPlayerRoutingBucket(src, lobby.id)

    -- Spawn player
    local spawnPoint = map.spawnPoints[math.random(1, #map.spawnPoints)]
    xPlayer.setCoords(spawnPoint.x, spawnPoint.y, spawnPoint.z)

    -- Give weapons
    xPlayer.removeAllWeapons()
    for _, weapon in ipairs(lobby.weapons) do
        xPlayer.addWeapon(weapon.name, weapon.ammo or 100)
    end

    -- Update player count
    lobby.players = lobby.players + 1
    TriggerClientEvent('esx_ffa:updateLobbies', -1, lobbies)

    print('Player ' .. GetPlayerName(src) .. ' joined lobby ' .. lobby.name .. ' with mapId ' .. lobby.mapId)
end)

RegisterNetEvent('esx_ffa:leaveLobby')
AddEventHandler('esx_ffa:leaveLobby', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    -- Find the lobby the player is in
    local playerLobby = nil
    for i, lobby in ipairs(lobbies) do
        if GetPlayerRoutingBucket(src) == lobby.id then
            playerLobby = lobby
            break
        end
    end

    if playerLobby then
        playerLobby.players = playerLobby.players - 1
        if playerLobby.players < 0 then playerLobby.players = 0 end
        TriggerClientEvent('esx_ffa:updateLobbies', -1, lobbies)
    end

    -- Reset routing bucket and spawn player
    SetPlayerRoutingBucket(src, 0)
    xPlayer.setCoords(Config.Maps[1].spawnPoints[1].x, Config.Maps[1].spawnPoints[1].y, Config.Maps[1].spawnPoints[1].z) -- Example spawn
    xPlayer.removeAllWeapons()

    print('Player ' .. GetPlayerName(src) .. ' left a lobby.')
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    -- Hier müsste die Logik implementiert werden, um den Spieler aus allen Lobbies zu entfernen
    TriggerEvent('esx_ffa:leaveLobby', src)
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
