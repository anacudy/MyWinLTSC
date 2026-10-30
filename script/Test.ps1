Install-Module MSCatalogLTS -Scope CurrentUser -Force

$updates = Get-MSCatalogUpdate -Search '3.5 -4.8.1 22H2 1903 Updates x64' -AllPages
$latest = $updates | Sort-Object -Descending LastUpdated | Select-Object -First 1

$latest | Format-List Title, LastUpdated, Size
Save-MSCatalogUpdate -Update $latest -Destination uup
