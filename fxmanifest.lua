fx_version 'cerulean'
game 'gta5'

author 'BL SCRIPTS'
description 'Vehicle Lock System (QB/ESX/Standalone)'
version '1.0.2'

lua54 'yes'

shared_script '@ox_lib/init.lua'

shared_scripts {
    'config/config.lua',
    'locales/en.lua',
    '@bl_lib/lib.lua'
}

client_scripts {
    'client/main.lua',
    'client/target.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

dependencies {
    'bl_lib',
    'InteractSound'
}
