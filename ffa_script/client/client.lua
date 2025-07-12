ESX = exports["es_extended"]:getSharedObject()
local isMenuOpen = false

Citizen.CreateThread(function()
    while not ESX do Citizen.Wait(100) end
    while not ESX.IsPlayerLoaded() do
        Citizen.Wait(100)
    end
    DebugPrint("ESX Player ist geladen.")
end)

local function DebugPrint(msg)
    if Config.Debug then
        print('[FFA_SCRIPT][CLIENT] ' .. msg)
    end
end

RegisterCommand(Config.CommandName, function(source, args, rawCommand)
    if not ESX or not ESX.IsPlayerLoaded() then
        DebugPrint("ESX ist noch nicht bereit oder Spieler nicht geladen.")
        ESX.ShowNotification("FFA-System ist noch nicht bereit oder Spielerdaten nicht geladen. Bitte warte einen Moment.")
        return
    end

    if not isMenuOpen then
        ESX.TriggerServerCallback('ffa:requestInitialData', function(data)
            SendNUIMessage({
                action = "openMenu",
                maps = data.maps,
                stats = data.stats,
                leaderboard = data.leaderboard
            })
            SetNuiFocus(true, true)
            isMenuOpen = true
            DebugPrint("FFA UI geöffnet.")
        end)
    else
        SendNUIMessage({
            action = "closeMenu"
        })
        SetNuiFocus(false, false)
        isMenuOpen = false
        DebugPrint("FFA UI geschlossen.")
    end
end, false)

RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    isMenuOpen = false
    DebugPrint("FFA UI durch NUI Callback geschlossen.")
    cb('ok')
end)

RegisterNUICallback('joinLobby', function(data, cb)
    if data and data.mapId then
        DebugPrint("NUI Callback: joinLobby für MapID: " .. data.mapId)
        TriggerServerEvent('ffa:joinLobby', data.mapId)
        cb('ok')
    else
        DebugPrint("NUI Callback: joinLobby ohne mapId aufgerufen.")
        cb('error')
    end
end)

RegisterNUICallback('leaveLobby', function(data, cb)
    DebugPrint("NUI Callback: leaveLobby")
    TriggerServerEvent('ffa:leaveLobby')
    cb('ok')
end)

RegisterNetEvent('ffa:updateLobbyView')
AddEventHandler('ffa:updateLobbyView', function(mapId, playersTable, playerCount)
    DebugPrint("Client Event: ffa:updateLobbyView für MapID: " .. mapId .. " Spieleranzahl: " .. playerCount)

    SendNUIMessage({
        action = "updateMapPlayerCounts",
        mapId = mapId,
        currentPlayers = playerCount
    })

    local playerNames = {}
    if playersTable then
        for sourceId, xPlayer in pairs(playersTable) do
            if xPlayer and xPlayer.name then
                 table.insert(playerNames, xPlayer.name)
            else
                table.insert(playerNames, "Spieler ID: " .. sourceId)
            end
        end
    end

    SendNUIMessage({
        action = "updateLobbyView",
        mapId = mapId,
        currentPlayers = playerCount,
        players = playerNames
    })
end)

RegisterNetEvent('ffa:updateStats')
AddEventHandler('ffa:updateStats', function(stats)
    SendNUIMessage({
        action = "updateStats",
        stats = stats
    })
end)

RegisterNetEvent('ffa:updateLeaderboard')
AddEventHandler('ffa:updateLeaderboard', function(leaderboard)
    SendNUIMessage({
        action = "updateLeaderboard",
        leaderboard = leaderboard
    })
end)

local isInFFA = false
local currentFFAMapId = nil
local currentFFAMapBoundaries = nil
local lastWarningTime = 0
local warningInterval = 5000
local boundaryCheckInterval = 1000

RegisterNetEvent('ffa:playerJoinedMatch')
AddEventHandler('ffa:playerJoinedMatch', function(mapId)
    DebugPrint("Event: playerJoinedMatch für MapID: " .. mapId)
    local mapConfig = nil
    for _, mc in ipairs(Config.Maps) do
        if mc.id == mapId then
            mapConfig = mc
            break
        end
    end

    if mapConfig and mapConfig.boundaries then
        isInFFA = true
        currentFFAMapId = mapId
        currentFFAMapBoundaries = mapConfig.boundaries
        DebugPrint("FFA beigetreten. Map: " .. mapConfig.displayName .. ". Grenzen aktiv.")
        ESX.ShowNotification("Du bist dem FFA-Match auf der Map '" .. mapConfig.displayName .. "' beigetreten. Bleibe im Kampfgebiet!")
    else
        DebugPrint("Fehler: Map-Konfiguration oder Grenzen für MapID " .. mapId .. " nicht gefunden.")
        isInFFA = false
        currentFFAMapId = nil
        currentFFAMapBoundaries = nil
    end
end)

RegisterNetEvent('ffa:playerLeftMatch')
AddEventHandler('ffa:playerLeftMatch', function()
    DebugPrint("Event: playerLeftMatch. FFA-Status zurückgesetzt.")
    if isInFFA then
        ESX.ShowNotification("Du hast das FFA-Match verlassen.")
    end
    isInFFA = false
    currentFFAMapId = nil
    currentFFAMapBoundaries = nil
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(boundaryCheckInterval)

        if isInFFA and currentFFAMapBoundaries then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local boundaries = currentFFAMapBoundaries

            local isOutside = false
            if playerCoords.x < boundaries.min.x or playerCoords.x > boundaries.max.x or
               playerCoords.y < boundaries.min.y or playerCoords.y > boundaries.max.y or
               playerCoords.z < boundaries.min.z or playerCoords.z > boundaries.max.z then
                isOutside = true
            end

            if isOutside then
                local currentTime = GetGameTimer()
                if (currentTime - lastWarningTime) > warningInterval then
                    ESX.ShowNotification("~r~WARNUNG:~s~ Du verlässt das Kampfgebiet! Kehre sofort um!", "error", 5000)
                    lastWarningTime = currentTime
                end
            end
        end
    end
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DebugPrint("FFA Script Client-Seite gestartet.")
        SetNuiFocus(false, false)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DebugPrint("FFA Script Client-Seite gestoppt.")
        SetNuiFocus(false, false)
        if isInFFA then
            DebugPrint("FFA-Status wird aufgrund des Ressourcenstopps zurückgesetzt.")
        end
        isInFFA = false
        currentFFAMapId = nil
        currentFFAMapBoundaries = nil
    end
end)

AddEventHandler('playerDied', function(killerType, killerEntity, weaponHash)
    if isInFFA then
        local playerId = PlayerId()
        local killerServerId = -1

        if NetworkIsPlayerActive(killerEntity) then
            killerServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(killerEntity))
        elseif IsEntityAPed(killerEntity) and not IsPedAPlayer(killerEntity) then
             DebugPrint("Spieler im FFA wurde von einem NPC getötet.")
        else
             DebugPrint("Spieler im FFA starb durch Umgebungseinflüsse oder Suizid.")
        end

        DebugPrint("Spieler ist im FFA gestorben. Benachrichtige Server. Killer-ID (falls Spieler): " .. killerServerId)
        TriggerServerEvent('ffa:playerDiedInMatch', killerServerId)

        DoScreenFadeOut(500)
        Citizen.CreateThread(function()
            Wait(500)
            NetworkResurrectLocalPlayer(GetEntityCoords(PlayerPedId()), GetEntityHeading(PlayerPedId()), true, false)
            SetEntityHealth(PlayerPedId(), GetPedMaxHealth(PlayerPedId()))
            ClearPedBloodDamage(PlayerPedId())
            ClearPedTasksImmediately(PlayerPedId())
        end)
    end
end)

RegisterNetEvent('ffa:playerRespawned')
AddEventHandler('ffa:playerRespawned', function()
    if isInFFA then
        DebugPrint("Client: Spieler wurde im FFA respawned. Fade In.")
        DoScreenFadeIn(1000)
        ESX.ShowNotification("Du wurdest respawned!", "success", 2500)
    end
end)

RegisterNetEvent('ffa:setClientPedCoords')
AddEventHandler('ffa:setClientPedCoords', function(coords)
    if coords and coords.x and coords.y and coords.z then
        local playerPed = PlayerPedId()
        SetEntityCoordsNoOffset(playerPed, coords.x, coords.y, coords.z, false, false, true)
        if coords.heading then
            SetEntityHeading(playerPed, tonumber(coords.heading))
            DebugPrint("Client: Koordinaten gesetzt auf " .. coords.x .. ", " .. coords.y .. ", " .. coords.z .. " mit Heading " .. coords.heading)
        else
            DebugPrint("Client: Koordinaten gesetzt auf " .. coords.x .. ", " .. coords.y .. ", " .. coords.z .. " (kein Heading übergeben)")
        end
    else
        DebugPrint("Client: Ungültige Koordinaten für ffa:setClientPedCoords erhalten: " .. json.encode(coords))
    end
end)

RegisterNetEvent('ffa:setClientPedHealthArmor')
AddEventHandler('ffa:setClientPedHealthArmor', function(health, armor)
    local playerPed = PlayerPedId()
    SetEntityHealth(playerPed, health)
    SetPedArmour(playerPed, armor)
    DebugPrint("Client: Gesundheit auf " .. health .. " und Rüstung auf " .. armor .. " gesetzt.")
end)

RegisterCommand('quitffa', function(source, args, rawCommand)
    if isInFFA then
        DebugPrint("Client: /quitffa Befehl ausgeführt. Verlasse FFA-Match.")
        ESX.ShowNotification("Du verlässt das FFA-Match...")
        TriggerServerEvent('ffa:leaveLobby')
        if isMenuOpen then
            SendNUIMessage({ action = "closeMenu" })
            SetNuiFocus(false, false)
            isMenuOpen = false
        end
    else
        ESX.ShowNotification("Du bist derzeit in keinem FFA-Match.")
        DebugPrint("Client: /quitffa Befehl ausgeführt, aber Spieler ist nicht im FFA.")
    end
end, false)

DebugPrint("FFA Script Client-Seite geladen.")
