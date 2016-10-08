SET dbPrefix=hexagonmi
SET domain=hexagonmi

SET fileDestPath=C:\inetpub\wwwroot\%domain%
SET coreSrcPath=C:\Users\celston\Software\Sitecore\7.5\Sitecore 7.5 rev. 141003\
SET dbDestPath=C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\DATA\
SET licensePath=C:\Users\celston\Desktop\Sitecore\license.xml

:: drop the appPool and site if they already exists

C:\Windows\System32\inetsrv\appcmd.exe delete apppool %domain%
C:\Windows\System32\inetsrv\appcmd.exe delete site %domain%

:: drop all databases if they already exist

sqlcmd -Q "IF EXISTS(SELECT * FROM sys.databases WHERE name='%dbPrefix%-core') DROP DATABASE [%dbPrefix%-core]"
sqlcmd -Q "IF EXISTS(SELECT * FROM sys.databases WHERE name='%dbPrefix%-web') DROP DATABASE [%dbPrefix%-web]"
sqlcmd -Q "IF EXISTS(SELECT * FROM sys.databases WHERE name='%dbPrefix%-master') DROP DATABASE [%dbPrefix%-master]"
sqlcmd -Q "IF EXISTS(SELECT * FROM sys.databases WHERE name='%dbPrefix%-analytics') DROP DATABASE [%dbPrefix%-analytics]"

:: copy database files to destination

COPY "%coreSrcPath%Databases\Sitecore.Analytics.ldf" "%dbDestPath%%dbPrefix%-analytics.ldf"
COPY "%coreSrcPath%Databases\Sitecore.Analytics.mdf" "%dbDestPath%%dbPrefix%-analytics.mdf"
COPY "%coreSrcPath%Databases\Sitecore.Core.ldf" "%dbDestPath%%dbPrefix%-core.ldf"
COPY "%coreSrcPath%Databases\Sitecore.Core.mdf" "%dbDestPath%%dbPrefix%-core.mdf"
COPY "%coreSrcPath%Databases\Sitecore.Master.ldf" "%dbDestPath%%dbPrefix%-master.ldf"
COPY "%coreSrcPath%Databases\Sitecore.Master.mdf" "%dbDestPath%%dbPrefix%-master.mdf"
COPY "%coreSrcPath%Databases\Sitecore.Sessions.ldf" "%dbDestPath%%dbPrefix%-sessions.ldf"
COPY "%coreSrcPath%Databases\Sitecore.Sessions.mdf" "%dbDestPath%%dbPrefix%-sessions.mdf"
COPY "%coreSrcPath%Databases\Sitecore.Web.ldf" "%dbDestPath%%dbPrefix%-web.ldf"
COPY "%coreSrcPath%Databases\Sitecore.Web.mdf" "%dbDestPath%%dbPrefix%-web.mdf"

:: attach databases

sqlcmd -Q "CREATE DATABASE [%dbPrefix%-core] ON (FILENAME = '%dbDestPath%%dbPrefix%-core.mdf'), (FILENAME = '%dbDestPath%%dbPrefix%-core.ldf') FOR ATTACH"
sqlcmd -Q "CREATE DATABASE [%dbPrefix%-web] ON (FILENAME = '%dbDestPath%%dbPrefix%-web.mdf'), (FILENAME = '%dbDestPath%%dbPrefix%-web.ldf') FOR ATTACH"
sqlcmd -Q "CREATE DATABASE [%dbPrefix%-master] ON (FILENAME = '%dbDestPath%%dbPrefix%-master.mdf'), (FILENAME = '%dbDestPath%%dbPrefix%-master.ldf') FOR ATTACH"
sqlcmd -Q "CREATE DATABASE [%dbPrefix%-analytics] ON (FILENAME = '%dbDestPath%%dbPrefix%-analytics.mdf'), (FILENAME = '%dbDestPath%%dbPrefix%-analytics.ldf') FOR ATTACH"

:: copy the web docs

:: robocopy "%coreSrcPath%Website" "%fileDestPath%\Website" /E /COPYALL
:: robocopy "%coreSrcPath%Data" "%fileDestPath%\Data" /E /COPYALL
:: COPY %licensePath% %fileDestPath%\Data\license.xml

:: create the apppool and site and bind them together

C:\Windows\System32\inetsrv\appcmd.exe add apppool /name:%domain%
C:\Windows\System32\inetsrv\appcmd.exe set apppool /apppool.name:%domain% /managedRuntimeVersion:v4.0
C:\Windows\System32\inetsrv\appcmd.exe add site /name:%domain% /physicalPath:%fileDestPath%\Website /bindings:http/*:80:%domain%
C:\Windows\System32\inetsrv\appcmd.exe set app "%domain%/" /applicationPool:%domain%

:: attempt to give the apppool full writes on the website and data directories

ICACLS %fileDestPath% /grant "IIS AppPool\%domain%":(OI)(CI)F
ICACLS C:\Windows\Temp /grant "IIS AppPool\%domain%":(OI)(CI)F
