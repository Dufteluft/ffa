document.addEventListener('DOMContentLoaded', function () {
    const ffaContainer = document.getElementById('ffa-container');
    const closeButton = document.getElementById('closeButton');
    const mapListContainer = document.getElementById('map-list-container');
    const lobbyDetailsView = document.getElementById('lobby-details');
    const lobbyMapName = document.getElementById('lobby-map-name');
    const lobbyCurrentPlayers = document.getElementById('lobby-current-players');
    const lobbyMaxPlayers = document.getElementById('lobby-max-players');
    const playerListDiv = document.getElementById('player-list');
    const leaveLobbyButton = document.getElementById('leaveLobbyButton');

    let currentMapData = []; // Um die Map-Daten lokal zu speichern
    let currentlyDisplayedLobbyMapId = null; // Welche Lobby wird gerade angezeigt?

    // Funktion zum Schließen des Menüs und Senden der NUI-Nachricht an Lua
    function closeMenu() {
        ffaContainer.style.display = 'none';
        mapListContainer.style.display = 'grid'; // Map-Liste wieder anzeigen, falls Lobby offen war
        lobbyDetailsView.style.display = 'none'; // Lobby-Ansicht ausblenden
        currentlyDisplayedLobbyMapId = null;
        fetch(`https://${GetParentResourceName()}/closeMenu`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({}),
        }).catch(err => console.error("Error closing menu:", err));
    }

    function joinMapLobby(mapId) {
        console.log("Versuche Lobby beizutreten für Map:", mapId);
        fetch(`https://${GetParentResourceName()}/joinLobby`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ mapId: mapId }),
        }).then(response => response.text()).then(data => {
            console.log('joinLobby response:', data);
            // UI-Wechsel passiert jetzt durch 'updateLobbyView' oder eine dedizierte Bestätigung
        }).catch(err => console.error("Error joining lobby:", err));

        // Optimistisch die Lobby-Ansicht vorbereiten oder auf Bestätigung warten
        const selectedMap = currentMapData.find(m => m.id === mapId);
        if (selectedMap) {
            mapListContainer.style.display = 'none';
            lobbyDetailsView.style.display = 'block';
            currentlyDisplayedLobbyMapId = mapId;
            lobbyMapName.textContent = selectedMap.displayName;
            // Spielerzahlen werden durch updateLobbyView aktualisiert
            lobbyMaxPlayers.textContent = selectedMap.maxPlayers;
            playerListDiv.innerHTML = '<p>Lobby wird beigetreten...</p>';
        }
    }

    function leaveLobby() {
        console.log("Verlasse Lobby");
        fetch(`https://${GetParentResourceName()}/leaveLobby`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({}),
        }).catch(err => console.error("Error leaving lobby:", err));

        mapListContainer.style.display = 'grid';
        lobbyDetailsView.style.display = 'none';
        currentlyDisplayedLobbyMapId = null;
    }


    function displayMaps(maps) {
        currentMapData = maps;
        mapListContainer.innerHTML = '';

        if (!maps || maps.length === 0) {
            mapListContainer.innerHTML = '<p>Keine FFA-Maps verfügbar.</p>';
            return;
        }

        maps.forEach(map => {
            const card = document.createElement('div');
            card.classList.add('map-card');
            card.dataset.mapId = map.id; // Um die Karte später zu finden und zu aktualisieren

            const thumbnail = document.createElement('img');
            thumbnail.src = map.thumbnail || 'https://via.placeholder.com/150/cccccc/000000?Text=No+Image';
            thumbnail.alt = map.displayName;

            const title = document.createElement('h3');
            title.textContent = map.displayName;

            const description = document.createElement('p');
            description.textContent = map.description;

            const playersP = document.createElement('p');
            playersP.classList.add('players');
            playersP.textContent = `Spieler: ${map.currentPlayers || 0} / ${map.maxPlayers || 'N/A'}`;

            const joinButton = document.createElement('button');
            joinButton.classList.add('join-btn');
            joinButton.textContent = 'Lobby beitreten';
            joinButton.onclick = () => joinMapLobby(map.id);

            card.appendChild(thumbnail);
            card.appendChild(title);
            card.appendChild(description);
            card.appendChild(playersP); // Geändertes Element
            card.appendChild(joinButton);
            mapListContainer.appendChild(card);
        });
    }

    function updateMapCardPlayerCount(mapId, currentPlayers) {
        const mapCard = mapListContainer.querySelector(`.map-card[data-map-id="${mapId}"]`);
        if (mapCard) {
            const playersElement = mapCard.querySelector('.players');
            const mapData = currentMapData.find(m => m.id === mapId);
            if (playersElement && mapData) {
                playersElement.textContent = `Spieler: ${currentPlayers} / ${mapData.maxPlayers || 'N/A'}`;
            }
        }
    }

    // Event Listener für den Schließen-Button
    if (closeButton) {
        closeButton.addEventListener('click', closeMenu);
    }

    // Event Listener für den "Lobby verlassen" Button
    if (leaveLobbyButton) {
        leaveLobbyButton.addEventListener('click', leaveLobby);
    }

    // Event Listener für Nachrichten von Lua (client.lua)
    window.addEventListener('message', function (event) {
        const item = event.data;
        if (item.action === 'openMenu') {
            ffaContainer.style.display = 'flex';
            if (item.maps) {
                displayMaps(item.maps);
            }
            mapListContainer.style.display = 'grid';
            lobbyDetailsView.style.display = 'none';
            currentlyDisplayedLobbyMapId = null;
        } else if (item.action === 'closeMenu') {
            closeMenu();
        } else if (item.action === 'updateLobbyView') {
            // Aktualisiert die Spielerzahl auf der Map-Karte
            updateMapCardPlayerCount(item.mapId, item.currentPlayers);

            // Aktualisiert die detaillierte Lobby-Ansicht, WENN sie für diese Map offen ist
            if (currentlyDisplayedLobbyMapId === item.mapId && lobbyDetailsView.style.display === 'block') {
                const map = currentMapData.find(m => m.id === item.mapId);
                if (map) { // Stellen sicher, dass die Map-Daten noch vorhanden sind
                    lobbyMapName.textContent = map.displayName; // Bleibt gleich, aber zur Sicherheit
                    lobbyCurrentPlayers.textContent = item.currentPlayers;
                    lobbyMaxPlayers.textContent = map.maxPlayers; // Bleibt gleich
                    playerListDiv.innerHTML = ''; // Leeren
                    if (item.players && item.players.length > 0) {
                        item.players.forEach(playerName => {
                            const p = document.createElement('p');
                            p.textContent = playerName;
                            playerListDiv.appendChild(p);
                        });
                    } else {
                        playerListDiv.innerHTML = '<p>Keine Spieler in der Lobby.</p>';
                    }
                }
            }
        } else if (item.action === 'updateMapPlayerCounts') {
            // Wird verwendet, um nur die Spielerzahlen auf den Map-Karten zu aktualisieren
            // (nützlich, wenn der Spieler nicht in dieser Lobby-Ansicht ist)
            updateMapCardPlayerCount(item.mapId, item.currentPlayers);
        }
    });

    // Schließen des Menüs mit der ESC-Taste
    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' || event.keyCode === 27) {
            if (ffaContainer.style.display !== 'none') {
                closeMenu();
            }
        }
    });

    console.log("FFA UI Script geladen und initialisiert.");
});
