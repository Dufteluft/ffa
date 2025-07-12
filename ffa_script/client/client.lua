ESX = exports["es_extended"]:getSharedObject()
local isMenuOpen = false -- Zustand der UI

Citizen.CreateThread(function()
    -- Mit dem direkten Export-Aufruf ist die while-Schleife nicht mehr unbedingt nötig,
    -- aber eine Prüfung, ob ESX geladen ist, bevor spielerspezifische Dinge passieren, ist gut.
    while not ESX do Citizen.Wait(100) end -- Warte kurz, falls es_extended noch nicht ganz initialisiert ist

    while not ESX.IsPlayerLoaded() do
        Citizen.Wait(100)
    end
    -- Hier könnten Initialisierungen für den Spieler stattfinden, sobald ESX geladen ist
    DebugPrint("ESX Player ist geladen.")
end)

-- Hilfsfunktion für Debug-Nachrichten auf dem Client
local function DebugPrint(msg)
    if Config.Debug then
        print('[FFA_SCRIPT][CLIENT] ' .. msg)
    end
end

-- Befehl zum Öffnen/Schließen der UI
RegisterCommand(Config.CommandName, function(source, args, rawCommand)
    if not ESX or not ESX.IsPlayerLoaded() then
        DebugPrint("ESX ist noch nicht bereit oder Spieler nicht geladen.")
        ESX.ShowNotification("FFA-System ist noch nicht bereit oder Spielerdaten nicht geladen. Bitte warte einen Moment.")
        return
    end

    if not isMenuOpen then
        -- UI öffnen (NUI-Nachricht senden)
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
            action = "openMenu",
            maps = mapsForUI,
            weapons = Config.Weapons -- Sending all possible weapons
        })
        SetNuiFocus(true, true)
        isMenuOpen = true
        DebugPrint("FFA UI geöffnet.")
        ESX.ShowNotification("FFA Menü geöffnet (Befehl: /" .. Config.CommandName .. ")")
    else
        -- UI schließen
        SendNUIMessage({
            action = "closeMenu"
        })
        SetNuiFocus(false, false)
        isMenuOpen = false
        DebugPrint("FFA UI geschlossen.")
        ESX.ShowNotification("FFA Menü geschlossen.")
    end
end, false)

-- NUI Callback für das Schließen des Menüs über ESC oder einen Button in der UI
RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    isMenuOpen = false
    DebugPrint("FFA UI durch NUI Callback geschlossen.")
    cb('ok') -- Bestätigung an NUI senden
end)

-- NUI Callback für das Beitreten zu einer Lobby
RegisterNUICallback('joinLobby', function(data, cb)
    if data and data.mapId then -- Korrektur: && zu and
        DebugPrint("NUI Callback: joinLobby für MapID: " .. data.mapId)
        TriggerServerEvent('ffa:joinLobby', data.mapId)
        cb('ok')
    else
        DebugPrint("NUI Callback: joinLobby ohne mapId aufgerufen.")
        cb('error')
    end
end)

-- NUI Callback für das Verlassen einer Lobby
RegisterNUICallback('leaveLobby', function(data, cb)
    DebugPrint("NUI Callback: leaveLobby")
    TriggerServerEvent('ffa:leaveLobby')
    cb('ok')
end)

-- Event Handler für Lobby-Updates vom Server
RegisterNetEvent('ffa:updateLobbyList')
AddEventHandler('ffa:updateLobbyList', function(lobbies)
    DebugPrint("Client Event: ffa:updateLobbyList erhalten")
    SendNUIMessage({
        action = "updateLobbyList",
        lobbies = lobbies
    })
end)

RegisterNetEvent('ffa:updateLobbyView')
AddEventHandler('ffa:updateLobbyView', function(mapId, playersTable, playerCount)
    DebugPrint("Client Event: ffa:updateLobbyView für MapID: " .. mapId .. " Spieleranzahl: " .. playerCount)

    -- Aktualisiere die Map-Liste in der UI (Spieleranzahl)
    SendNUIMessage({
        action = "updateMapPlayerCounts",
        mapId = mapId,
        currentPlayers = playerCount
    })

    -- Wenn die Lobby-Ansicht für diese Map gerade offen ist, aktualisiere sie detaillierter
    -- Dies erfordert, dass die UI weiß, welche Lobby sie anzeigt, oder wir senden alle Spielerdetails
    local playerNames = {}
    if playersTable then
        for sourceId, xPlayer in pairs(playersTable) do
            if xPlayer and xPlayer.name then -- Sicherstellen, dass xPlayer und xPlayer.name existieren
                 table.insert(playerNames, xPlayer.name)
            else
                -- Fallback, falls Spielerdaten nicht vollständig sind (sollte serverseitig nicht passieren)
                table.insert(playerNames, "Spieler ID: " .. sourceId)
            end
        end
    end

    SendNUIMessage({
        action = "updateLobbyView",
        mapId = mapId,
        currentPlayers = playerCount,
        players = playerNames -- Sende eine Liste von Spielernamen
    })
end)

-- FFA Status und Bubble-System
local isInFFA = false
local currentFFAMapId = nil
local currentFFAMapBoundaries = nil
local lastWarningTime = 0
local warningInterval = 5000 -- Millisekunden zwischen Warnungen
local boundaryCheckInterval = 1000 -- Intervall für die Überprüfung der Grenzen

-- Event, das vom Server gesendet wird, wenn der Spieler einem FFA-Match beitritt
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

-- Event, das vom Server gesendet wird, wenn der Spieler ein FFA-Match verlässt (oder es endet)
RegisterNetEvent('ffa:playerLeftMatch')
AddEventHandler('ffa:playerLeftMatch', function()
    DebugPrint("Event: playerLeftMatch. FFA-Status zurückgesetzt.")
    if isInFFA then -- Nur eine Nachricht anzeigen, wenn man wirklich in einem FFA war
        ESX.ShowNotification("Du hast das FFA-Match verlassen.")
    end
    isInFFA = false
    currentFFAMapId = nil
    currentFFAMapBoundaries = nil
end)

-- Thread zur Überprüfung der Map-Grenzen
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
                    -- Optional: Visuellen Effekt hinzufügen (z.B. Bildschirmrand abdunkeln)
                    -- Optional: Soundeffekt
                    lastWarningTime = currentTime
                end
                -- Hier könnte man nach einer gewissen Zeit außerhalb den Spieler zurückteleportieren
                -- Fürs Erste nur eine Warnung.
                -- Beispiel für Zurückteleportieren (brutal, benötigt einen gültigen Spawn innerhalb der Zone):
                -- SetEntityCoords(playerPed, boundaries.min.x + 5.0, boundaries.min.y + 5.0, boundaries.min.z + 1.0, false, false, false, true)
                -- ESX.ShowNotification("Du wurdest ins Kampfgebiet zurückgebracht.", "info", 3000)
            end
        end
    end
end)


AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DebugPrint("FFA Script Client-Seite gestartet.")
        -- Sicherstellen, dass die UI beim Start nicht fokussiert ist
        SetNuiFocus(false, false)

        -- Beim Start alle aktuellen Lobby-Daten abrufen, falls das Menü direkt geöffnet wird
        -- oder um die Spielerzahlen in der Map-Liste aktuell zu halten.
        -- Dies könnte man auch serverseitig beim Öffnen des Menüs anfordern.
        -- Vorerst lassen wir das so, dass Updates nur bei Änderungen gepusht werden.
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DebugPrint("FFA Script Client-Seite gestoppt.")
        -- Sicherstellen, dass der NUI-Fokus beim Stoppen des Skripts freigegeben wird
        SetNuiFocus(false, false)
        -- FFA-Status zurücksetzen, falls das Skript gestoppt wird, während man im FFA ist
        if isInFFA then
            DebugPrint("FFA-Status wird aufgrund des Ressourcenstopps zurückgesetzt.")
        end
        isInFFA = false
        currentFFAMapId = nil
        currentFFAMapBoundaries = nil
    end
end)

-- Event Handler für Tod des Spielers
AddEventHandler('playerDied', function(killerType, killerEntity, weaponHash)
    if isInFFA then
        local playerId = PlayerId()
        local killerServerId = -1 -- Standardwert, falls kein Spielerkiller

        if NetworkIsPlayerActive(killerEntity) then -- Überprüfen, ob der Killer ein anderer Spieler ist
            killerServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(killerEntity))
        elseif IsEntityAPed(killerEntity) and not IsPedAPlayer(killerEntity) then
             -- Optional: Behandle den Tod durch einen NPC (falls relevant für FFA)
             DebugPrint("Spieler im FFA wurde von einem NPC getötet.")
        else
             -- Optional: Behandle andere Todesursachen (Sturz, Explosion etc.)
             DebugPrint("Spieler im FFA starb durch Umgebungseinflüsse oder Suizid.")
        end

        DebugPrint("Spieler ist im FFA gestorben. Benachrichtige Server. Killer-ID (falls Spieler): " .. killerServerId)
        TriggerServerEvent('ffa:playerDiedInMatch', killerServerId)

        -- Standard ESX Tod/Respawn verhindern für FFA Spieler
        -- Dies kann knifflig sein und hängt von der ESX Version und anderen Skripten ab.
        -- Eine gängige Methode ist, das Event zu canceln, das esx_ambulancejob auslöst,
        -- oder eine Variable zu setzen, die esx_ambulancejob prüft.
        -- Fürs Erste versuchen wir, den Todesscreen zu überbrücken, indem wir den Spieler clientseitig "unsichtbar" machen
        -- bis der Server den Respawn managed.
        -- ESX.TriggerServerCallback('esx_ambulancejob:removeDeathStatus', {}, function() end) -- Versuch, den Tod-Status zu entfernen

        -- Alternativ: Kurzes Ausblenden und Einfrieren bis zum serverseitigen Respawn-Trigger
        DoScreenFadeOut(500)
        Citizen.CreateThread(function()
            Wait(500)
            NetworkResurrectLocalPlayer(GetEntityCoords(PlayerPedId()), GetEntityHeading(PlayerPedId()), true, false)
            SetEntityHealth(PlayerPedId(), GetPedMaxHealth(PlayerPedId()))
            ClearPedBloodDamage(PlayerPedId())
            ClearPedTasksImmediately(PlayerPedId())
            -- RemoveAllPedWeapons(PlayerPedId(), true) -- Waffen werden serverseitig neu gegeben

            -- Warten auf serverseitigen Respawn-Befehl, um Screen wieder einzublenden
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

-- Client-Event zum Setzen der Koordinaten
RegisterNetEvent('ffa:setClientPedCoords')
AddEventHandler('ffa:setClientPedCoords', function(coords)
    if coords and coords.x and coords.y and coords.z then
        local playerPed = PlayerPedId()
        -- SetEntityCoordsNoOffset anstelle von SetEntityCoords, um sicherzustellen, dass der Spieler nicht im Boden spawnt,
        -- besonders wenn die Z-Koordinate präzise ist. true für keepOffset, false für NoOffset.
        -- Für den Rückteleport ist NoOffset oft besser, um genau an der Stelle zu landen.
        -- Für den Spawn in die Arena könnte man argumentieren, dass ein Offset (wenn Z nicht perfekt ist) hilfreich wäre.
        -- Wir verwenden hier NoOffset für Präzision.
        SetEntityCoordsNoOffset(playerPed, coords.x, coords.y, coords.z, false, false, true) -- x, y, z, xAxis, yAxis, zAxis (keepOffset = false, noGroundFix = false, clearArea = true)

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

-- Client-Event zum Setzen von Gesundheit und Rüstung
RegisterNetEvent('ffa:setClientPedHealthArmor')
AddEventHandler('ffa:setClientPedHealthArmor', function(health, armor)
    local playerPed = PlayerPedId()
    SetEntityHealth(playerPed, health)
    SetPedArmour(playerPed, armor)
    DebugPrint("Client: Gesundheit auf " .. health .. " und Rüstung auf " .. armor .. " gesetzt.")
end)

-- Befehl zum Verlassen des aktuellen FFA-Matches
RegisterCommand('quitffa', function(source, args, rawCommand)
    if isInFFA then
        DebugPrint("Client: /quitffa Befehl ausgeführt. Verlasse FFA-Match.")
        ESX.ShowNotification("Du verlässt das FFA-Match...")
        TriggerServerEvent('ffa:leaveLobby') -- Das serverseitige Event kümmert sich um das Aufräumen

        -- UI schließen, falls offen und der Spieler im FFA war
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
