ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterNetEvent('esx_ffa:openMenu')
AddEventHandler('esx_ffa:openMenu', function(lobbies, playerStats, leaderboard)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "openMenu",
        lobbies = lobbies,
        playerStats = playerStats,
        leaderboard = leaderboard
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

RegisterNetEvent('esx_ffa:updateLobbies')
AddEventHandler('esx_ffa:updateLobbies', function(lobbies)
    SendNUIMessage({
        action = "updateLobbies",
        lobbies = lobbies
    })
end)
