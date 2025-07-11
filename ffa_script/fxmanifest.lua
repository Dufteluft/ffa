fx_version 'cerulean'
game 'gta5'

author 'Jules KI-Assistent'
description 'FFA Script mit ESX Integration'
version '1.0.0'

shared_script 'shared/config.lua'

client_scripts {
    '@es_extended/locale.lua', -- Falls ESX Sprachdateien verwendet
    'client/client.lua'
}

server_scripts {
    '@es_extended/locale.lua', -- Falls ESX Sprachdateien verwendet
    'server/server.lua'
}

ui_page 'html/ui.html' -- Wird später für die UI verwendet

files {
    'html/ui.html',
    'html/style.css',
    'html/script.js'
}

dependency 'es_extended' -- Wichtige Abhängigkeit von ESX
