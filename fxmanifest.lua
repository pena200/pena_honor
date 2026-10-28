fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'pena_honor'
author 'Pena'
description 'Persistent honor system with a neon bar and badge. Works with ESX, QBCore, Qbox or standalone.'
version '1.0.0'
license 'MIT'


shared_scripts {
    'config.lua',
    'shared.lua',
}


server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge.lua',
    'server/main.lua',
    'server/api.lua',
    'server/consequences.lua',
}


client_scripts {
    'client/main.lua',
    'client/consequences.lua',
}


ui_page 'web/index.html'


files {
    'web/index.html',
    'web/style.css',
    'web/script.js',
}


dependencies {
    'oxmysql',
}