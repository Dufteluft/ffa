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
    const createLobbyForm = document.getElementById('create-lobby-form');
    const mapSelect = document.getElementById('map-select');
    const weaponSelect = document.getElementById('weapon-select');
    const tabs = document.querySelectorAll('.tab-button');
    const tabContents = document.querySelectorAll('.tab-content');

    let currentMapData = [];
    let currentlyDisplayedLobbyMapId = null;

    function switchTab(tab) {
        tabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');
        const target = document.getElementById(tab.dataset.tab);
        tabContents.forEach(tc => tc.classList.remove('active'));
        if (target) {
            target.classList.add('active');
        }
    }

    tabs.forEach(tab => {
        tab.addEventListener('click', () => switchTab(tab));
    });

    function closeMenu() {
        ffaContainer.style.display = 'none';
        // Reset to default tab
        switchTab(document.querySelector('.tab-button[data-tab="lobbies-list"]'));
        lobbyDetailsView.style.display = 'none';
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


    function displayLobbies(lobbies) {
        mapListContainer.innerHTML = '';

        if (!lobbies || lobbies.length === 0) {
            mapListContainer.innerHTML = '<p>Keine aktiven Lobbies gefunden. Erstelle eine neue!</p>';
            return;
        }

        lobbies.forEach(lobby => {
            const card = document.createElement('div');
            card.classList.add('map-card');
            card.dataset.mapId = lobby.id;

            // Thumbnail logic needs to be adapted. Assuming map data is available.
            const mapInfo = currentMapData.find(m => m.id === lobby.id);
            const thumbnail = document.createElement('img');
            thumbnail.src = mapInfo ? mapInfo.thumbnail : 'https://via.placeholder.com/150/cccccc/000000?Text=No+Image';
            thumbnail.alt = lobby.name;

            const title = document.createElement('h3');
            title.textContent = lobby.name;

            const mapName = document.createElement('p');
            mapName.textContent = `Karte: ${lobby.mapName}`;

            const playersP = document.createElement('p');
            playersP.classList.add('players');
            playersP.textContent = `Spieler: ${lobby.currentPlayers} / ${lobby.maxPlayers}`;

            const joinButton = document.createElement('button');
            joinButton.classList.add('join-btn');
            joinButton.textContent = lobby.hasPassword ? 'Beitreten (PW)' : 'Beitreten';
            joinButton.onclick = () => joinMapLobby(lobby.id);

            card.appendChild(thumbnail);
            card.appendChild(title);
            card.appendChild(mapName);
            card.appendChild(playersP);
            card.appendChild(joinButton);
            mapListContainer.appendChild(card);
        });
    }

    function updateLobbyCardPlayerCount(mapId, currentPlayers) {
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

    createLobbyForm.addEventListener('submit', function(e) {
        e.preventDefault();
        const formData = new FormData(e.target);
        const data = Object.fromEntries(formData.entries());

        // Get all selected weapons
        const selectedWeapons = [];
        for (const option of weaponSelect.options) {
            if (option.selected) {
                selectedWeapons.push(option.value);
            }
        }
        data.weapons = selectedWeapons;

        console.log("Creating lobby with data:", data);
        fetch(`https://${GetParentResourceName()}/createLobby`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        }).catch(err => console.error("Error creating lobby:", err));

        // Optionally, switch back to the lobby list and close the menu or show a confirmation
        closeMenu();
    });

    // Event Listener für Nachrichten von Lua (client.lua)
    window.addEventListener('message', function (event) {
        const item = event.data;
        if (item.action === 'openMenu') {
            ffaContainer.style.display = 'flex';
            currentMapData = item.maps; // Store map data

            // Populate create lobby form selects
            mapSelect.innerHTML = '';
            item.maps.forEach(map => {
                const option = document.createElement('option');
                option.value = map.id;
                option.textContent = map.displayName;
                mapSelect.appendChild(option);
            });

            weaponSelect.innerHTML = '';
            if(item.weapons) {
                item.weapons.forEach(weapon => {
                    const option = document.createElement('option');
                    option.value = weapon.name;
                    option.textContent = weapon.label;
                    weaponSelect.appendChild(option);
                });
            }

            // Initially, we don't have lobby data, so we can show a loading state or nothing.
            // The lobby data will arrive via 'updateLobbyList'.
            mapListContainer.innerHTML = '<p>Lade Lobbies...</p>';
            lobbyDetailsView.style.display = 'none';
            currentlyDisplayedLobbyMapId = null;

        } else if (item.action === 'closeMenu') {
            closeMenu();
        } else if (item.action === 'updateLobbyList') {
            displayLobbies(item.lobbies);
        } else if (item.action === 'updateLobbyView') {
            // This now primarily updates the player count on the lobby card
            updateLobbyCardPlayerCount(item.mapId, item.currentPlayers);

            // And updates the detailed lobby view if it's open
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
            updateLobbyCardPlayerCount(item.mapId, item.currentPlayers);
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
