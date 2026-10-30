$ini = 'W10UI.ini'
$lines = Get-Content $ini
$lines[1] = "Target        =$PWD\uup\install.wim"
$lines[2] = "Repo          =$PWD\uup"
$lines[6] = "Net35Source   =$PWD\uup"
$lines[7] = "Cleanup       =1"
$lines[8] = "ResetBase     =1"
$lines[15] = "UseWimlib     =1"
$lines | Set-Content $ini
