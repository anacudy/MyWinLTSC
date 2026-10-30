$productKey = @{
  "2021" = "QPM6N-7J2WJ-P88HH-P3YRH-YY74H"
  "2024" = "KBN8V-HFGQ4-MGXVD-347P6-PDQGT"
}[$ENV:LTSC_VERSION]

New-Item -ItemType Directory -Path "install"

DISM /Mount-Image /Optimize /CheckIntegrity /ImageFile:"install.wim" /MountDir:"install"

DISM /Set-Edition:"IoTEnterpriseS" /Image:"install"

DISM /Set-ProductKey:"$productKey" /Image:"install"

DISM /Unmount-Image /Commit /CheckIntegrity /MountDir:"install"

bin\wimlib-imagex export --solid "install.wim" all "install.esd"

7z a -mx=0 "install.7z" "install.esd" -v2000m

7z a -mx=9 "dism.7z" "$($ENV:WINDIR)\Logs\Dism"

Get-ChildItem -Path "."
