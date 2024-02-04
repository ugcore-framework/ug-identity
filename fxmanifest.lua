fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'ug-identity'
description 'Identity for UgCore by UgDev'
author 'UgDev'
version '3.5'
url 'https://github.com/UgDevOfc/ug-identity'
ui_page 'html/index.html'

shared_scripts {
    '@ug-core/languages.lua',
    'languages/*.lua',
    'config.lua'
}

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/version.lua'
}

files {
	'html/index.html',
	'html/js/*.js',
	'html/css/*.css',
}

dependencies {
    'oxmysql',
    'ug-core',
    'ug-skin'
}