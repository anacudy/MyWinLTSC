$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

7z e wimlib.zip -obin *.exe *.dll
7z e PSFExtractor.zip -obin
7z e ltsc.iso -r -osources install.wim
7z e ltsc.iso -r -osources\sxs *netfx3*.cab

Remove-Item -Path ltsc.iso

Copy-Item -Path BatUtil\W10UI\W10UI.ini
Copy-Item -Path BatUtil\W10UI\W10UI.cmd

$ini = 'W10UI.ini'
$lines = Get-Content -Path $ini
$lines[1] = "Target        =$PWD\sources\install.wim"
$lines[2] = "Repo          =$PWD\uup"
$lines[7] = "Cleanup       =1"
$lines[8] = "ResetBase     =1"
$lines[15] = "UseWimlib     =1"
$lines | Set-Content -Path $ini
Get-Content -Path $ini

$cmd = 'W10UI.cmd'
$lines = Get-Content -Path $cmd
$lines[5] = 'set _Debug=1'
$lines | Set-Content -Path $cmd

Get-ChildItem
Get-ChildItem sources
Get-ChildItem uup
Get-ChildItem bin

.\W10UI.cmd
