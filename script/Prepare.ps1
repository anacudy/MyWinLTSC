7z e wimlib.zip -obin *.exe *.dll

7z e ltsc.iso install.wim *NetFx3-OnDemand* -r
New-Item -Name sxs -ItemType Directory
Move-Item -Path *NetFx3-OnDemand* -Destination sxs
Remove-Item ltsc.iso

Move-Item -Path BatUtil\W10UI\W10UI.cmd
