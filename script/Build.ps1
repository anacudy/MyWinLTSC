$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

7z -y -bso0 e -r ltsc.iso install.wim
7z -y -bso0 e -r ltsc.iso -osxs *netfx3*.cab
7z -y -bso0 e wimlib.zip -obin *.exe *.dll

Remove-Item -Path "ltsc.iso"

Copy-Item -Path "BatUtil\W10UI\W10UI.ini"
Copy-Item -Path "BatUtil\W10UI\W10UI.cmd"

$ini = "W10UI.ini"
$lines = Get-Content -Path $ini
$lines[1] = "Target        =$PWD\install.wim"
$lines[2] = "Repo          =$PWD\uup"
$lines[7] = "Cleanup       =1"
$lines[8] = "ResetBase     =1"
$lines[15] = "UseWimlib     =1"
$lines | Set-Content -Path $ini

$cmd = "W10UI.cmd"
$lines = Get-Content -Path $cmd
$lines[5] = "set _Debug=1"
$lines | Set-Content -Path $cmd

Write-Output "::group::Files"
Get-ChildItem -Path "."
Get-ChildItem -Path "sources"
Get-ChildItem -Path "sources\sxs"
Get-ChildItem -Path "uup"
Get-ChildItem -Path "bin"
Write-Output "::endgroup::"

Write-Output "::group::W10UI.ini"
Get-Content -Path "W10UI.ini"
Write-Output "::endgroup::"

.\W10UI.cmd
