fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Knuckls'
description 'Allows players to grow weed plants in their house to harvest for items to sell'
version '1.2.0'

shared_scripts {
    'config.lua',
    '@kg-core/shared/locale.lua',
    'locales/en.lua',
    'locales/*.lua'
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
