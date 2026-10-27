param(
  [ValidateSet("2021", "2024")]
  [string]$Version
)

$keyword = @{
  "2021" = "21H2 19044 amd64"
  "2024" = "24H2 26100 amd64"
}[$Version]

$url = "https://api.uupdump.net/listid.php?search=$keyword&sortByDate=1"
$builds = (Invoke-RestMethod $url).response.builds.PSObject.Properties.Value
$latest = $builds | Where-Object title -notmatch 'Cumulative' | Select-Object -First 1
$latest.title
$latest.uuid

Add-Content -Path $env:GITHUB_OUTPUT -Value "uuid=$($latest.uuid)" -Encoding ascii
