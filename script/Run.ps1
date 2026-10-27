$cmd = 'W10UI.cmd'
$lines = Get-Content $cmd
$lines[5] = 'set _Debug=1'
$lines | Set-Content $cmd
./W10UI.cmd
