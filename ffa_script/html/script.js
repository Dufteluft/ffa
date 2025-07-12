document.addEventListener('DOMContentLoaded', function () {
    const sessionGrid = document.querySelector('.session-grid');
    const playerList = document.querySelector('.player-list');

    // Mock Data
    const mockSessions = [
        { id: "session_001", name: "Patrick House", currentPlayers: 12, maxPlayers: 32, image: "https://i.imgur.com/M6Jt8o4.jpeg", isActive: true },
        { id: "session_002", name: "Sandy Shores", currentPlayers: 28, maxPlayers: 32, image: "https://i.imgur.com/M6Jt8o4.jpeg", isActive: true },
        { id: "session_003", name: "Los Santos Port", currentPlayers: 5, maxPlayers: 32, image: "https://i.imgur.com/M6Jt8o4.jpeg", isActive: false },
        { id: "session_004", name: "Observatory", currentPlayers: 18, maxPlayers: 32, image: "https://i.imgur.com/M6Jt8o4.jpeg", isActive: true },
        { id: "session_005", name: "Paleto Bay", currentPlayers: 32, maxPlayers: 32, image: "https://i.imgur.com/M6Jt8o4.jpeg", isActive: true },
        { id: "session_006", name: "Zancudo River", currentPlayers: 10, maxPlayers: 32, image: "https://i.imgur.com/M6Jt8o4.jpeg", isActive: false },
    ];

    const mockPlayers = [
        { id: "player_001", name: "Romario Richardson", rank: 1, level: 1337 },
        { id: "player_002", name: "Jane Doe", rank: 2, level: 1200 },
        { id: "player_003", name: "John Smith", rank: 3, level: 1150 },
        { id: "player_004", name: "Agent 47", rank: 4, level: 1000 },
        { id: "player_005", name: "Lara Croft", rank: 5, level: 950 },
        { id: "player_006", name: "Master Chief", rank: 6, level: 900 },
        { id: "player_007", name: "Kratos", rank: 7, level: 850 },
        { id: "player_008", name: "Geralt of Rivia", rank: 8, level: 800 },
        { id: "player_009", name: "Aloy", rank: 9, level: 750 },
    ];

    function createSessionCard(session) {
        const card = document.createElement('div');
        card.className = `session-card ${session.isActive ? 'active' : ''}`;
        card.innerHTML = `
            <img src="${session.image}" alt="${session.name}" class="session-image">
            <div class="player-count">${session.currentPlayers}/${session.maxPlayers}</div>
            <div class="session-card-info">
                <p class="session-name">${session.name}</p>
            </div>
            <div class="play-button">
                <i class="fas fa-play"></i>
            </div>
        `;
        return card;
    }

    function createPlayerEntry(player) {
        const entry = document.createElement('div');
        entry.className = 'player-entry';

        let rankIcon;
        if (player.rank === 1) rankIcon = 'fas fa-trophy gold';
        else if (player.rank === 2) rankIcon = 'fas fa-trophy silver';
        else if (player.rank === 3) rankIcon = 'fas fa-trophy bronze';
        else rankIcon = 'fas fa-medal';

        entry.innerHTML = `
            <i class="${rankIcon} rank-icon"></i>
            <div class="player-info">
                <strong>${player.name}</strong>
                <p>#${player.rank} Place</p>
            </div>
            <div class="level-badge">${player.level}</div>
        `;
        return entry;
    }

    function populateUI() {
        // Populate sessions
        sessionGrid.innerHTML = '';
        mockSessions.forEach(session => {
            sessionGrid.appendChild(createSessionCard(session));
        });

        // Populate leaderboard
        playerList.innerHTML = '';
        mockPlayers.forEach(player => {
            playerList.appendChild(createPlayerEntry(player));
        });
    }

    // Initial population
    populateUI();

    // NUI Message Listener (to be adapted from old script)
    window.addEventListener('message', function (event) {
        const item = event.data;
        // Logic to open/close menu and update data will go here
        // For now, we just log the action
        console.log("Received action:", item.action);
    });

    // Example of how to close the menu (can be triggered by Lua)
    // document.querySelector('.overlay-container').style.display = 'none';
});
