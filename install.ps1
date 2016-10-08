Import-Module WebAdministration

$dbprefix = "sitecoresandbox81"
$domain = $dbprefix
$deployFiles = $true
$DebugPreference = "Continue"

$fileDestPath = "C:\inetpub\wwwroot\" + $domain
$coreSrcPath = "C:\var\Software\Sitecore\8.1\Sitecore 8.1 rev. 160519"
$dbDestPath = "C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\"
$licensePath = "C:\var\Software\Sitecore\license.xml"

Function DropDatabases() {
    Invoke-Sqlcmd -Query "IF EXISTS(SELECT * FROM sys.databases WHERE name='$dbprefix-core') DROP DATABASE [$dbprefix-core]"
    Invoke-Sqlcmd -Query "IF EXISTS(SELECT * FROM sys.databases WHERE name='$dbprefix-web') DROP DATABASE [$dbprefix-web]"
    Invoke-Sqlcmd -Query "IF EXISTS(SELECT * FROM sys.databases WHERE name='$dbprefix-wip') DROP DATABASE [$dbprefix-wip]"
    Invoke-Sqlcmd -Query "IF EXISTS(SELECT * FROM sys.databases WHERE name='$dbprefix-master') DROP DATABASE [$dbprefix-master]"
    Invoke-Sqlcmd -Query "IF EXISTS(SELECT * FROM sys.databases WHERE name='$dbprefix-sessions') DROP DATABASE [$dbprefix-sessions]"
    Invoke-Sqlcmd -Query "IF EXISTS(SELECT * FROM sys.databases WHERE name='$dbprefix-analytics') DROP DATABASE [$dbprefix-analytics]"
}

Function CopyDatabaseFiles() {
    Copy-Item -Force "$coreSrcPath\Databases\Sitecore.Core.ldf" "$dbDestPath$dbprefix-core.ldf"
    Copy-Item -Force "$coreSrcPath\Databases\Sitecore.Core.mdf" "$dbDestPath$dbprefix-core.mdf"
    Copy-Item -Force "$coreSrcPath\Databases\Sitecore.Web.ldf" "$dbDestPath$dbprefix-web.ldf"
    Copy-Item -Force "$coreSrcPath\Databases\Sitecore.Web.mdf" "$dbDestPath$dbprefix-web.mdf"
    Copy-Item -Force "$coreSrcPath\Databases\Sitecore.Web.ldf" "$dbDestPath$dbprefix-wip.ldf"
    Copy-Item -Force "$coreSrcPath\Databases\Sitecore.Web.mdf" "$dbDestPath$dbprefix-wip.mdf"
    Copy-Item -Force "$coreSrcPath\Databases\Sitecore.Master.ldf" "$dbDestPath$dbprefix-master.ldf"
    Copy-Item -Force "$coreSrcPath\Databases\Sitecore.Master.mdf" "$dbDestPath$dbprefix-master.mdf"
    Copy-Item -Force "$coreSrcPath\Databases\Sitecore.Sessions.ldf" "$dbDestPath$dbprefix-sessions.ldf"
    Copy-Item -Force "$coreSrcPath\Databases\Sitecore.Sessions.mdf" "$dbDestPath$dbprefix-sessions.mdf"
    Copy-Item -Force "$coreSrcPath\Databases\Sitecore.Analytics.ldf" "$dbDestPath$dbprefix-analytics.ldf"
    Copy-Item -Force "$coreSrcPath\Databases\Sitecore.Analytics.mdf" "$dbDestPath$dbprefix-analytics.mdf"
}

Function AttachDatabases() {
    Invoke-Sqlcmd -Query "CREATE DATABASE [$dbprefix-core] ON (FILENAME = '$dbDestPath$dbprefix-core.mdf'), (FILENAME = '$dbDestPath$dbprefix-core.ldf') FOR ATTACH"
    Invoke-Sqlcmd -Query "CREATE DATABASE [$dbprefix-web] ON (FILENAME = '$dbDestPath$dbprefix-web.mdf'), (FILENAME = '$dbDestPath$dbprefix-web.ldf') FOR ATTACH"
    Invoke-Sqlcmd -Query "CREATE DATABASE [$dbprefix-wip] ON (FILENAME = '$dbDestPath$dbprefix-wip.mdf'), (FILENAME = '$dbDestPath$dbprefix-wip.ldf') FOR ATTACH"
    Invoke-Sqlcmd -Query "CREATE DATABASE [$dbprefix-master] ON (FILENAME = '$dbDestPath$dbprefix-master.mdf'), (FILENAME = '$dbDestPath$dbprefix-master.ldf') FOR ATTACH"
    Invoke-Sqlcmd -Query "CREATE DATABASE [$dbprefix-sessions] ON (FILENAME = '$dbDestPath$dbprefix-sessions.mdf'), (FILENAME = '$dbDestPath$dbprefix-sessions.ldf') FOR ATTACH"
    Invoke-Sqlcmd -Query "CREATE DATABASE [$dbprefix-analytics] ON (FILENAME = '$dbDestPath$dbprefix-analytics.mdf'), (FILENAME = '$dbDestPath$dbprefix-analytics.ldf') FOR ATTACH"
}

Function CopyWebsiteFiles() {
    Invoke-Expression "robocopy '$coreSrcPath\Website' $fileDestPath\Website /MIR"
    Invoke-Expression "robocopy '$coreSrcPath\Data' $fileDestPath\Data /MIR"
    Copy-Item $licensePath "$fileDestPath\Data\"
}

Function RemoveWebItems() {
    Remove-WebAppPool $domain
    Remove-Website $domain
}

Function CreateWebItems() {
    New-WebAppPool $domain
    Set-ItemProperty "IIS:\AppPools\$domain" managedRuntimeVersion v4.0
    New-Website $domain -PhysicalPath "$fileDestPath\Website" -Port 80 -HostHeader $domain
    New-WebBinding -Name $domain -IPAddress "*" -Port 80 -HostHeader "wip-$domain"
    Set-ItemProperty "IIS:\Sites\$domain" applicationPool $domain
    Start-Website -Name $domain
}

Function SetPermissions() {
    &ICACLS $fileDestPath /grant "IIS AppPool\$domain`:(OI)(CI)F"
    &ICACLS C:\Windows\Temp /grant "IIS AppPool\$domain`:(OI)(CI)F"
}

Function UpdateHostFile() {
    Add-Content C:\Windows\System32\drivers\etc\hosts "127.0.0.1 $domain wip-$domain"
}

Function UpdateConfigs() {
    $configFile = "$fileDestPath\Website\App_Config\Sitecore.config"
    (gc $configFile).Replace('"/data"', "`"$fileDestPath\Data`"") | sc $configFile

    $configFile = "$fileDestPath\Website\App_Config\ConnectionStrings.config"
    (gc $configFile).Replace('user id=user;password=password;Data Source=(server);Database=Sitecore_', "Data Source=celstonw73;Trusted_Connection=Yes;Database=$dbprefix-") | sc $configFile
    (gc $configFile).Replace('mongodb://localhost/', "mongodb`://localhost/$dbprefix-") | sc $configFile
}

Function CreateSqlLogin() {
    Invoke-Sqlcmd -Query "CREATE LOGIN [IIS APPPOOL\$dbprefix] FROM WINDOWS"
    Invoke-Sqlcmd -Query "CREATE USER [IIS APPPOOL\$dbprefix]"
    Invoke-Sqlcmd -Query "USE [$dbprefix-web]`nGO`nEXEC sp_addrolemember 'db_owner', [IIS APPPOOL\$domain]"
    Invoke-Sqlcmd -Query "USE [$dbprefix-wip]`nGO`nEXEC sp_addrolemember 'db_owner', [IIS APPPOOL\$domain]"
    Invoke-Sqlcmd -Query "USE [$dbprefix-master]`nGO`nEXEC sp_addrolemember 'db_owner', [IIS APPPOOL\$domain]"
    Invoke-Sqlcmd -Query "USE [$dbprefix-core]`nGO`nEXEC sp_addrolemember 'db_owner', [IIS APPPOOL\$domain]"
    Invoke-Sqlcmd -Query "USE [$dbprefix-sessions]`nGO`nEXEC sp_addrolemember 'db_owner', [IIS APPPOOL\$domain]"
    Invoke-Sqlcmd -Query "USE [$dbprefix-analytics]`nGO`nEXEC sp_addrolemember 'db_owner', [IIS APPPOOL\$domain]"
}

RemoveWebItems
DropDatabases
CopyDatabaseFiles
AttachDatabases
CopyWebsiteFiles
CreateWebItems
SetPermissions
CreateSqlLogin
UpdateHostFile
UpdateConfigs