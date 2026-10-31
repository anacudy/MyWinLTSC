$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$productKey = @{
  "2021" = "QPM6N-7J2WJ-P88HH-P3YRH-YY74H"
  "2024" = "KBN8V-HFGQ4-MGXVD-347P6-PDQGT"
}[$ENV:LTSC_VERSION]

New-Item -ItemType "Directory" -Path "install"

Mount-WindowsImage -Optimize -CheckIntegrity -Path "install" -ImagePath "install.wim"

Set-WindowsEdition -Edition "IoTEnterpriseS" -Path "install"

Set-WindowsProductKey -ProductKey "$productKey" -Path "install"

(Get-ChildItem -Path "package\dep" -File).ForEach({
    $PSItem.FullName
    Add-AppxProvisionedPackage -SkipLicense -PackagePath $PSItem.FullName -Path "install"
  })

(Get-ChildItem -Path "package\app" -File).ForEach({
    $PSItem.FullName
    Add-AppxProvisionedPackage -SkipLicense -PackagePath $PSItem.FullName -Path "install"
  })

@(
  "Microsoft-Hyper-V-All",
  "VirtualMachinePlatform",
  "Containers-DisposableClientVM",
  "HypervisorPlatform"
).ForEach({
    Enable-WindowsOptionalFeature -All -FeatureName $PSItem -Path "install"
  })

Repair-WindowsImage -StartComponentCleanup -ResetBase -Path "install"

Dismount-WindowsImage -Save -CheckIntegrity -Path "install"

bin\wimlib-imagex export --solid "install.wim" all "install.esd"

7z a -mx=0 "install.7z" "install.esd" -v2000m

7z a -mx=9 "W10UI_Debug.log.7z" "W10UI_Debug.log"

7z a -mx=9 "dism.log.7z" "C:\Windows\Logs\DISM\dism.log"
