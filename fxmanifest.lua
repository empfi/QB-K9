fx_version 'cerulean'
game 'gta5'

author 'empfi'
description 'QB-Core Police K9 Script with key-based interactions'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/sh_util.lua'
}

client_scripts {
    'client/main.lua',
    'client/dog_menu.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'qb-core',
    'qb-menu'
}