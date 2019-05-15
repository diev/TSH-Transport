# Тестовый конфиг
#-------------------------------------
# Открытые данные

$ConfigUrl  = 'http://172.16.**.***:7777'
$ConfigUser = '0440*****_**'

$ConfigPathIn  = 'C:\TSH\Plat\IN'
$ConfigPathOut = 'C:\TSH\Plat\OUT'

$ConfigBackupIn  = 'C:\TSH\Backup\IN\%Y%m%d'
$ConfigBackupOut = 'C:\TSH\Backup\OUT\%Y%m%d'
$ConfigBackupRep = 'C:\TSH\Backup\REP\%Y%m%d'

#------------------------------------
# Секреты от скрипта

$SecretPass = '12345678****'

#-------------------------------------
# Назначение прав и очистка секретов
$ConfigCredential = New-Object System.Net.NetworkCredential $ConfigUser, $SecretPass
$SecretPass = $null
#eof
