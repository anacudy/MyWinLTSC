param(
  [ValidateSet("2021", "2024")]
  [string]$Version
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true

$keyword = @{
  "2021" = "21H2 19044 amd64"
  "2024" = "24H2 26100 amd64"
}[$Version]

$url = "https://api.uupdump.net/listid.php?search=$keyword&sortByDate=1"
$builds = (Invoke-RestMethod $url).response.builds.PSObject.Properties.Value
$latest = $builds | Where-Object title -notmatch 'Cumulative' | Select-Object -First 1

Write-Output '::group::UUP Dump API'
Write-Output "Title: $($latest.title)"
Write-Output "Build: $($latest.build)"
Write-Output "Arch:  $($latest.arch)"
Write-Output "Time:  $(Get-Date -UnixTimeSeconds -AsUTC -UnixTimeSeconds $latest.created)"
Write-Output "UUID:  $($latest.uuid)"
Write-Output '::endgroup::'

$arguments = @(
  "--quiet=true",
  "--conf-path=aria2.conf",
  "--out=uup.txt",
  "https://uupdump.net/get.php?id=$($latest.uuid)&pack=0&edition=updateOnly&aria2=2"
)
aria2c $arguments

$arguments = @(
  "--quiet=true",
  "--conf-path=aria2.conf",
  "--input-file=uup.txt"
  "--dir=uup"
)
aria2c $arguments

$arguments = @(
  "--quiet=true",
  "--conf-path=aria2.conf",
  "--input-file=$Version.txt"
)
aria2c $arguments

$arguments = @(
  "--quiet=true",
  "--conf-path=aria2.conf",
  "--input-file=wimlib.txt"
)
aria2c $arguments

Install-Module MSCatalogLTS -Scope CurrentUser -Force
$updates = Get-MSCatalogUpdate -Search '3.5 -4.8.1 22H2 1903 Updates x64' -AllPages
$latest = $updates | Sort-Object -Descending LastUpdated | Select-Object -First 1
Save-MSCatalogUpdate -Update $latest -Destination uup

gh release download --repo Secant1006/PSFExtractor --pattern *x64* --output PSFExtractor.zip
