document.addEventListener('DOMContentLoaded', function () {
    const mainContainer = document.getElementById('main-container');
    const ffaContainer = document.getElementById('ffa-container');
    const closeButton = document.getElementById('closeButton');
    const mapListContainer = document.getElementById('map-list-container');
    const lobbyDetailsView = document.getElementById('lobby-details');
    const lobbyMapName = document.getElementById('lobby-map-name');
    const lobbyCurrentPlayers = document.getElementById('lobby-current-players');
    const lobbyMaxPlayers = document.getElementById('lobby-max-players');
    const playerListDiv = document.getElementById('player-list');
    const leaveLobbyButton = document.getElementById('leaveLobbyButton');
    const leaderboardList = document.getElementById('leaderboard-list');
    const killsStat = document.getElementById('kills-stat');
    const deathsStat = document.getElementById('deaths-stat');
    const kdStat = document.getElementById('kd-stat');

    let currentMapData = [];
    let currentlyDisplayedLobbyMapId = null;

    function closeMenu() {
        mainContainer.style.display = 'none';
        mapListContainer.style.display = 'grid';
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
        }).catch(err => console.error("Error joining lobby:", err));

        const selectedMap = currentMapData.find(m => m.id === mapId);
        if (selectedMap) {
            mapListContainer.style.display = 'none';
            lobbyDetailsView.style.display = 'block';
            currentlyDisplayedLobbyMapId = mapId;
            lobbyMapName.textContent = selectedMap.displayName;
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
            // Add placeholders
            for (let i = 0; i < 3; i++) {
                const placeholder = document.createElement('div');
                placeholder.classList.add('map-card', 'placeholder');
                mapListContainer.appendChild(placeholder);
            }
            return;
        }

        maps.forEach(map => {
            const card = document.createElement('div');
            card.classList.add('map-card');
            card.dataset.mapId = map.id;

            const thumbnail = document.createElement('img');
            thumbnail.src = map.thumbnail || 'https://via.placeholder.com/150/cccccc/000000?Text=No+Image';
            thumbnail.alt = map.displayName;

            const title = document.createElement('h3');
            title.textContent = map.displayName;

            const playersP = document.createElement('p');
            playersP.classList.add('players');
            playersP.textContent = `Spieler: ${map.currentPlayers || 0} / ${map.maxPlayers || 'N/A'}`;

            const joinButton = document.createElement('button');
            joinButton.classList.add('join-btn');
            joinButton.textContent = 'Beitreten';
            joinButton.onclick = () => joinMapLobby(map.id);

            card.appendChild(thumbnail);
            card.appendChild(title);
            card.appendChild(playersP);
            card.appendChild(joinButton);
            mapListContainer.appendChild(card);
        });

        // Add placeholders to fill the row
        const placeholdersNeeded = 3 - (maps.length % 3);
        if (placeholdersNeeded < 3) {
            for (let i = 0; i < placeholdersNeeded; i++) {
                const placeholder = document.createElement('div');
                placeholder.classList.add('map-card', 'placeholder');
                mapListContainer.appendChild(placeholder);
            }
        }
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

    function updateLeaderboard(leaderboardData) {
        leaderboardList.innerHTML = '';
        if (leaderboardData && leaderboardData.length > 0) {
            leaderboardData.forEach((player, index) => {
                const entry = document.createElement('div');
                entry.classList.add('leaderboard-entry');

                const rank = document.createElement('span');
                rank.classList.add('rank');
                rank.textContent = `#${index + 1}`;

                const name = document.createElement('span');
                name.textContent = player.name;

                const kills = document.createElement('span');
                kills.textContent = `${player.kills} Kills`;

                entry.appendChild(rank);
                entry.appendChild(name);
                entry.appendChild(kills);
                leaderboardList.appendChild(entry);
            });
        } else {
            leaderboardList.innerHTML = '<p>Keine Leaderboard-Daten verfügbar.</p>';
        }
    }

    function updateStats(stats) {
        killsStat.textContent = stats.kills || 0;
        deathsStat.textContent = stats.deaths || 0;
        kdStat.textContent = (stats.deaths > 0 ? (stats.kills / stats.deaths).toFixed(2) : stats.kills.toFixed(2));
    }

    if (closeButton) {
        closeButton.addEventListener('click', closeMenu);
    }

    if (leaveLobbyButton) {
        leaveLobbyButton.addEventListener('click', leaveLobby);
    }

    window.addEventListener('message', function (event) {
        const item = event.data;
        if (item.action === 'openMenu') {
            mainContainer.style.display = 'flex';
            if (item.maps) {
                displayMaps(item.maps);
            }
            if (item.leaderboard) {
                updateLeaderboard(item.leaderboard);
            }
            if (item.stats) {
                updateStats(item.stats);
            }
            mapListContainer.style.display = 'grid';
            lobbyDetailsView.style.display = 'none';
            currentlyDisplayedLobbyMapId = null;
        } else if (item.action === 'closeMenu') {
            closeMenu();
        } else if (item.action === 'updateLobbyView') {
            updateMapCardPlayerCount(item.mapId, item.currentPlayers);
            if (currentlyDisplayedLobbyMapId === item.mapId && lobbyDetailsView.style.display === 'block') {
                const map = currentMapData.find(m => m.id === item.mapId);
                if (map) {
                    lobbyMapName.textContent = map.displayName;
                    lobbyCurrentPlayers.textContent = item.currentPlayers;
                    lobbyMaxPlayers.textContent = map.maxPlayers;
                    playerListDiv.innerHTML = '';
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
            updateMapCardPlayerCount(item.mapId, item.currentPlayers);
        } else if (item.action === 'updateStats') {
            updateStats(item.stats);
        } else if (item.action === 'updateLeaderboard') {
            updateLeaderboard(item.leaderboard);
        }
    });

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' || event.keyCode === 27) {
            if (mainContainer.style.display !== 'none') {
                closeMenu();
            }
        }
    });

    console.log("FFA UI Script geladen und initialisiert.");
});
