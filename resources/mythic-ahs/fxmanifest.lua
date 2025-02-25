fx_version 'cerulean'
game 'gta5'
lua54 'yes'
client_script "@mythic-base/components/cl_error.lua"
client_script "@mythic-pwnzor/client/check.lua"

server_scripts {
    'server/server.lua',
}

client_scripts {
    'client/client.lua',
}

shared_scripts {
    'shared/*.lua',
}

