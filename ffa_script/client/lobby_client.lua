ESX = exports["es_extended"]:getSharedObject()

RegisterNetEvent('esx_ffa:openMenu')
AddEventHandler('esx_ffa:openMenu', function(lobbies, playerStats, leaderboard, maps, weapons)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openMenu",
        lobbies = lobbies,
        playerStats = playerStats,
        leaderboard = leaderboard,
        maps = maps,
        weapons = weapons
    })
end)

RegisterNUICallback('closeMenu', function(_, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('createLobby', function(data, cb)
    TriggerServerEvent('esx_ffa:createLobby', data)
    cb('ok')
end)

RegisterNUICallback('joinLobby', function(data, cb)
    TriggerServerEvent('esx_ffa:joinLobby', data.lobbyId)
    cb('ok')
end)

RegisterNUICallback('leaveLobby', function(data, cb)
    TriggerServerEvent('esx_ffa:leaveLobby')
    cb('ok')
end)

RegisterNetEvent('esx_ffa:updateLobbies')
AddEventHandler('esx_ffa:updateLobbies', function(lobbies)
    SendNUIMessage({
        action = "updateLobbies",
        lobbies = lobbies
    })
end)
