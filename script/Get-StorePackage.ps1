#requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$Path
)

$ErrorActionPreference = 'Stop'
$wuUrl      = 'https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx'
$securedUrl = "$wuUrl/secured"
$xmlDir     = Join-Path $PSScriptRoot 'xml'
$root       = Join-Path $PWD 'package'
$ariaConf   = Join-Path $PWD 'aria2.conf'
$ariaInput  = Join-Path $root 'aria2-input.txt'

function Get-Template([string]$Name, [hashtable]$Values = @{}) {
    $text = Get-Content (Join-Path $xmlDir "$Name.xml") -Raw
    foreach ($key in $Values.Keys) { $text = $text.Replace("{{$key}}", [string]$Values[$key]) }
    $text
}

function Invoke-Soap([string]$Action, [string]$Url, [string]$Body) {
    $now = [DateTime]::UtcNow
    $envelope = Get-Template 'Envelope' @{
        Action    = $Action
        MessageId = [guid]::NewGuid()
        Url       = $Url
        Created   = $now.ToString('o')
        Expires   = $now.AddMinutes(5).ToString('o')
        Body      = $Body
    }
    $resp = Invoke-WebRequest -Uri $Url -Method Post -Body $envelope `
        -ContentType 'application/soap+xml; charset=utf-8'
    [xml]$resp.Content
}

function Get-Packages([string]$Id, [string]$Cookie) {
    $catalog = Invoke-RestMethod "https://displaycatalog.mp.microsoft.com/v7.0/products/$($Id)?market=US&languages=en-US"
    $categoryId = $catalog.Product.DisplaySkuAvailabilities[0].Sku.Properties.FulfillmentData.WuCategoryId
    if (-not $categoryId) { throw "$Id 不是可通过 WU 下载的 UWP/MSIX 应用（可能是 Win32 应用）。" }

    $syncBody = Get-Template 'SyncUpdates' @{ Cookie = $Cookie; CategoryId = $categoryId }
    $result = (Invoke-Soap 'SyncUpdates' $wuUrl $syncBody).Envelope.Body.SyncUpdatesResponse.SyncUpdatesResult

    $updateInfo = @{}
    foreach ($u in $result.NewUpdates.UpdateInfo) {
        $updateInfo[$u.ID] = ([xml]"<root>$($u.Xml)</root>").root
    }

    foreach ($u in $result.ExtendedUpdateInfo.Updates.Update) {
        $file = ([xml]"<root>$($u.Xml)</root>").root.Files.File |
            Where-Object InstallerSpecificIdentifier | Select-Object -First 1
        $info = $updateInfo[$u.ID]
        if (-not $file -or -not $info -or $file.InstallerSpecificIdentifier -notmatch '_(x64|neutral)_') { continue }
        [pscustomobject]@{
            Name     = $file.InstallerSpecificIdentifier
            FileName = $file.FileName
            UpdateId = $info.UpdateIdentity.UpdateID
            Revision = $info.UpdateIdentity.RevisionNumber
            Type     = if ($info.Properties.IsAppxFramework -eq 'true') { 'dep' } else { 'app' }
        }
    }
}

function Select-Latest($Packages) {
    $Packages |
        Group-Object { ($_.Name -split '_')[0] -replace '(\.\d+)+$' } |
        ForEach-Object { $_.Group | Sort-Object { [version]($_.Name -split '_')[1] } | Select-Object -Last 1 }
}

function Get-DownloadUrl($Package) {
    $body = Get-Template 'GetExtendedUpdateInfo2' @{ UpdateId = $Package.UpdateId; Revision = $Package.Revision }
    $resp = Invoke-Soap 'GetExtendedUpdateInfo2' $securedUrl $body
    $guid = [IO.Path]::GetFileNameWithoutExtension($Package.FileName)
    $resp.Envelope.Body.GetExtendedUpdateInfo2Response.GetExtendedUpdateInfo2Result.FileLocations.FileLocation.Url |
        Where-Object { $_ -match $guid } | Select-Object -First 1
}

$ids = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
Get-Content $Path | ForEach-Object { $_.Trim() } | Where-Object { $_ } | ForEach-Object { [void]$ids.Add($_) }

$cookieResp = Invoke-Soap 'GetCookie' $wuUrl (Get-Template 'GetCookie')
$cookie = $cookieResp.Envelope.Body.GetCookieResponse.GetCookieResult.EncryptedData

$apps = @{}
$deps = @{}
foreach ($id in $ids) {
    foreach ($p in Select-Latest (Get-Packages $id $cookie)) {
        if ($p.Type -eq 'app') { $apps[$p.Name] = $p } else { $deps[$p.Name] = $p }
    }
}
$packages = @($apps.Values) + @(Select-Latest $deps.Values)

New-Item -ItemType Directory -Force -Path $root | Out-Null
$lines = foreach ($p in $packages) {
    Get-DownloadUrl $p
    "  dir=$(Join-Path $root $p.Type)"
    "  out=$($p.Name)$([IO.Path]::GetExtension($p.FileName))"
}
Set-Content -Path $ariaInput -Value $lines

aria2c --conf-path=$ariaConf --input-file=$ariaInput
if ($LASTEXITCODE -ne 0) { throw "aria2c 下载失败，退出码 $LASTEXITCODE" }
