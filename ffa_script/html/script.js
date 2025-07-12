document.addEventListener('DOMContentLoaded', function () {
    const ffaContainer = document.getElementById('ffa-container');
    const closeButton = document.getElementById('closeButton');
    const lobbyListContainer = document.getElementById('lobby-list-container');
    const leaderboardList = document.getElementById('leaderboard-list');
    const kdRatio = document.getElementById('kd-ratio');
    const kills = document.getElementById('kills');
    const deaths = document.getElementById('deaths');

    // Tab-Buttons und -Inhalte
    const tabButtons = document.querySelectorAll('.tab-button');
    const tabContents = document.querySelectorAll('.tab-content');

    // Funktion zum Schließen des Menüs
    function closeMenu() {
        ffaContainer.style.display = 'none';
        fetch(`https://${GetParentResourceName()}/closeMenu`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({}),
        }).catch(err => console.error("Error closing menu:", err));
    }

    // Funktion zum Anzeigen von Lobbys
    function displayLobbies(lobbies) {
        lobbyListContainer.innerHTML = '';
        if (!lobbies || lobbies.length === 0) {
            lobbyListContainer.innerHTML = '<p>Keine Lobbys verfügbar.</p>';
            return;
        }

        lobbies.forEach(lobby => {
            const lobbyItem = document.createElement('div');
            lobbyItem.classList.add('lobby-item');
            lobbyItem.innerHTML = `
                <div class="lobby-name">${lobby.name}</div>
                <div class="lobby-players">${lobby.players} / ${lobby.maxPlayers}</div>
                <button class="join-lobby-btn" data-lobby-id="${lobby.id}">Beitreten</button>
            `;
            lobbyListContainer.appendChild(lobbyItem);
        });
    }

    // Funktion zum Anzeigen der Rangliste
    function displayLeaderboard(leaderboard) {
        leaderboardList.innerHTML = '';
        if (!leaderboard || leaderboard.length === 0) {
            return;
        }

        leaderboard.forEach(player => {
            const li = document.createElement('li');
            li.textContent = `${player.name} - K/D: ${player.kd}`;
            leaderboardList.appendChild(li);
        });
    }

    // Event Listener für Tab-Buttons
    tabButtons.forEach(button => {
        button.addEventListener('click', () => {
            tabButtons.forEach(btn => btn.classList.remove('active'));
            button.classList.add('active');

            const tab = button.getAttribute('data-tab');
            tabContents.forEach(content => {
                content.classList.remove('active');
                if (content.id === tab) {
                    content.classList.add('active');
                }
            });
        });
    });

    // Event Listener für den Schließen-Button
    if (closeButton) {
        closeButton.addEventListener('click', closeMenu);
    }

    // Funktion zum Befüllen der Auswahlfelder für die Lobby-Erstellung
    function populateCreateLobbyOptions() {
        const mapSelect = document.getElementById('lobby-map');
        const weaponsSelect = document.getElementById('lobby-weapons');

        mapSelect.innerHTML = '';
        weaponsSelect.innerHTML = '';

        // Dummy-Daten - diese sollten von der Lua-Seite kommen
        const maps = ['Standard Map 1', 'Standard Map 2', 'Standard Map 3', 'Custom Map A'];
        const weapons = ['Pistol', 'SMG', 'Assault Rifle', 'Sniper Rifle', 'Shotgun'];

        maps.forEach(map => {
            const option = document.createElement('option');
            option.value = map;
            option.textContent = map;
            mapSelect.appendChild(option);
        });

        weapons.forEach(weapon => {
            const option = document.createElement('option');
            option.value = weapon;
            option.textContent = weapon;
            weaponsSelect.appendChild(option);
        });
    }

    // Event Listener für den "Lobby erstellen"-Button
    const createLobbyBtn = document.getElementById('create-lobby-btn');
    if (createLobbyBtn) {
        createLobbyBtn.addEventListener('click', () => {
            const lobbyName = document.getElementById('lobby-name').value;
            const lobbyPassword = document.getElementById('lobby-password').value;
            const lobbyMap = document.getElementById('lobby-map').value;
            const selectedWeapons = [...document.getElementById('lobby-weapons').options]
                                      .filter(option => option.selected)
                                      .map(option => option.value);

            if (!lobbyName) {
                alert("Bitte einen Lobby-Namen eingeben.");
                return;
            }

            const lobbyData = {
                name: lobbyName,
                password: lobbyPassword,
                map: lobbyMap,
                weapons: selectedWeapons,
            };

            console.log("Erstelle Lobby mit folgenden Daten:", lobbyData);
            // Sende die Daten an die Lua-Seite
            fetch(`https://${GetParentResourceName()}/createLobby`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(lobbyData),
            }).catch(err => console.error("Error creating lobby:", err));

            // Optional: Nach dem Erstellen zur Lobby-Liste wechseln
            // Dies kann auch serverseitig gesteuert werden, indem eine neue Lobby-Liste gesendet wird
            tabButtons.forEach(btn => btn.classList.remove('active'));
            document.querySelector('.tab-button[data-tab="lobby-list"]').classList.add('active');
            tabContents.forEach(content => content.classList.remove('active'));
            document.getElementById('lobby-list').classList.add('active');
        });
    }

    // Event Listener für Nachrichten von Lua (client.lua)
    window.addEventListener('message', function (event) {
        const item = event.data;
        if (item.action === 'openMenu') {
            ffaContainer.style.display = 'flex';
            // Dummy-Daten für die UI
            const dummyLobbies = [
                { id: 1, name: 'Standard Map 1', players: 5, maxPlayers: 10 },
                { id: 2, name: 'Standard Map 2', players: 8, maxPlayers: 10 },
                { id: 3, name: 'Standard Map 3', players: 2, maxPlayers: 10 },
                { id: 4, name: 'Custom Lobby 1', players: 1, maxPlayers: 8 },
            ];
            const dummyLeaderboard = [
                { name: 'Player1', kd: 2.5 },
                { name: 'Player2', kd: 2.1 },
                { name: 'Player3', kd: 1.8 },
            ];
            displayLobbies(dummyLobbies);
            displayLeaderboard(dummyLeaderboard);
            kdRatio.textContent = '1.5';
            kills.textContent = '150';
            deaths.textContent = '100';

            // Befülle die "Lobby erstellen"-Optionen
            populateCreateLobbyOptions();
        } else if (item.action === 'closeMenu') {
            closeMenu();
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
