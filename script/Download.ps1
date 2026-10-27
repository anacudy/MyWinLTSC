param(
  [ValidateSet("2021", "2024")]
  [string]$Version,
  [string]$UUID
)

$arguments = @(
  "--quiet=true",
  "--conf-path=aria2.conf",
  "--out=uup.txt",
  "https://uupdump.net/get.php?id=$UUID&pack=0&edition=updateOnly&aria2=2"
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
