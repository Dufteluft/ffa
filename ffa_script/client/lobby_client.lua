ESX = exports["es_extended"]:getSharedObject()
local isLobbyMenuOpen = false

RegisterCommand(Config.LobbyCommandName, function(source, args, rawCommand)
    if not ESX or not ESX.IsPlayerLoaded() then
        DebugPrint("ESX ist noch nicht bereit oder Spieler nicht geladen.")
        ESX.ShowNotification("Lobby-System ist noch nicht bereit oder Spielerdaten nicht geladen. Bitte warte einen Moment.")
        return
    end

    if not isLobbyMenuOpen then
        TriggerServerEvent('ffa:requestLobbies')
        local mapsForUI = {}
        for i, mapInfo in ipairs(Config.Maps) do
            table.insert(mapsForUI, {
                id = mapInfo.id,
                displayName = mapInfo.displayName,
                description = mapInfo.description,
                thumbnail = mapInfo.thumbnail,
                maxPlayers = mapInfo.maxPlayers,
                currentPlayers = 0 -- Placeholder, will be updated by server
            })
        end

        SendNUIMessage({
            action = "openLobbyMenu",
            maps = mapsForUI,
            weapons = Config.Lobby.Weapons
        })
        SetNuiFocus(true, true)
        isLobbyMenuOpen = true
        DebugPrint("Lobby UI geöffnet.")
    else
        SendNUIMessage({
            action = "closeLobbyMenu"
        })
        SetNuiFocus(false, false)
        isLobbyMenuOpen = false
        DebugPrint("Lobby UI geschlossen.")
    end
end, false)

RegisterNUICallback('closeLobbyMenu', function(data, cb)
    SetNuiFocus(false, false)
    isLobbyMenuOpen = false
    DebugPrint("Lobby UI durch NUI Callback geschlossen.")
    cb('ok')
end)

RegisterNUICallback('createLobby', function(data, cb)
    TriggerServerEvent('ffa:createLobby', data)
    cb('ok')
end)

RegisterNetEvent('ffa:updateLobbyList')
AddEventHandler('ffa:updateLobbyList', function(lobbies)
    DebugPrint("Client Event: ffa:updateLobbyList erhalten")
    SendNUIMessage({
        action = "updateLobbyList",
        lobbies = lobbies
    })
end)
