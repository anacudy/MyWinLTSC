param(
  [ValidateSet("2021", "2024")]
  [string]$Version,
  [string]$UUID
)

$argument = @(
  "--quiet=true",
  "--conf-path=aria2.conf",
  "--out=url.txt",
  "https://uupdump.net/get.php?id=$UUID&pack=0&edition=updateOnly&aria2=2"
)
aria2c $argument

Get-Content $version.txt | Add-Content url.txt

$argument = @(
  "--quiet=true",
  "--conf-path=aria2.conf",
  "--input-file=url.txt"
)
aria2c $argument
