fx_version 'cerulean'
game 'gta5'

author 'Jules KI-Assistent'
description 'FFA Script mit ESX Integration'
version '1.0.0'

shared_scripts {
    'shared/config.lua',
    'shared/lobby_config.lua'
}

client_scripts {
    '@es_extended/locale.lua',
    'client/lobby_client.lua'
}

server_scripts {
    '@es_extended/locale.lua',
    'server/lobby_server.lua'
}

ui_page 'html/lobby.html'

files {
    'html/lobby.html',
    'html/lobby.css',
    'html/lobby.js'
}

dependency 'es_extended' -- Wichtige Abhängigkeit von ESX
