choco install wimlib -y --no-progress
Copy-Item -Path C:\ProgramData\chocolatey\lib\wimlib\tools\wimlib -Destination bin

Copy-Item -Path BatUtil\W10UI\W10UI.cmd

7z e ltsc.iso install.wim *NetFx3-OnDemand* -r
New-Item -Name sxs -ItemType Directory
Move-Item -Path *NetFx3-OnDemand* -Destination sxs
Remove-Item ltsc.iso
