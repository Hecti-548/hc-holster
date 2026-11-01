fx_version 'cerulean'

game 'gta5'

lua54 'yes'

author 'hc'
description 'hc-holster: visible weapon props on your character with selectable holster positions'
version '1.0.0'

dependencies {
    'ox_lib',
    'ox_inventory',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'props.lua',
}