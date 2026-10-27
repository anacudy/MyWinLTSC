7z e wimlib.zip -obin *.exe *.dll
7z e ltsc.iso -ouup install.wim *NetFx3-OnDemand* -r

Copy-Item -Path BatUtil\W10UI\W10UI.ini
Copy-Item -Path BatUtil\W10UI\W10UI.cmd

Remove-Item ltsc.iso
