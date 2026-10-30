#requires -Version 7.0
<#
.SYNOPSIS
    通过微软官方 Store 接口，按 ProductId 下载 x64 Retail 应用包及其依赖。
    SOAP 请求模板放在同目录的 xml\ 文件夹里。
.EXAMPLE
    ./Get-StorePackage.ps1 -ProductId 9wzdncrfjbmp
#>
param(
    [Parameter(Mandatory)][string]$ProductId,
    [string]$OutDir = (Join-Path $PWD $ProductId)
)

$ErrorActionPreference = 'Stop'
$wuUrl     = 'https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx'
$securedUrl = "$wuUrl/secured"
$xmlDir    = Join-Path $PSScriptRoot 'xml'

# 读取 xml\<Name>.xml，把 {{Key}} 替换成对应的值
function Get-Template([string]$Name, [hashtable]$Values = @{}) {
    $text = Get-Content (Join-Path $xmlDir "$Name.xml") -Raw
    foreach ($key in $Values.Keys) { $text = $text.Replace("{{$key}}", [string]$Values[$key]) }
    $text
}

# 把请求体包进 SOAP 信封并发送，返回响应 XML
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

# 1. ProductId -> WuCategoryId
$catalog = Invoke-RestMethod "https://displaycatalog.mp.microsoft.com/v7.0/products/$($ProductId)?market=US&languages=en-US"
$categoryId = $catalog.Product.DisplaySkuAvailabilities[0].Sku.Properties.FulfillmentData.WuCategoryId
if (-not $categoryId) { throw "$ProductId 不是可通过 WU 下载的 UWP/MSIX 应用（可能是 Win32 应用）。" }
Write-Host "WuCategoryId: $categoryId"

# 2. GetCookie
$cookieResp = Invoke-Soap 'GetCookie' $wuUrl (Get-Template 'GetCookie')
$cookie = $cookieResp.Envelope.Body.GetCookieResponse.GetCookieResult.EncryptedData

# 3. SyncUpdates：列出该应用及其依赖
$syncBody = Get-Template 'SyncUpdates' @{ Cookie = $cookie; CategoryId = $categoryId }
$result = (Invoke-Soap 'SyncUpdates' $wuUrl $syncBody).Envelope.Body.SyncUpdatesResponse.SyncUpdatesResult

# NewUpdates 里有 UpdateID / RevisionNumber，按内部 ID 建索引
$identity = @{}
foreach ($u in $result.NewUpdates.UpdateInfo) {
    $identity[$u.ID] = ([xml]"<root>$($u.Xml)</root>").root.UpdateIdentity
}

# ExtendedUpdateInfo 里有包名和文件名，两者按 ID 对应
$packages = foreach ($u in $result.ExtendedUpdateInfo.Updates.Update) {
    $file = ([xml]"<root>$($u.Xml)</root>").root.Files.File |
        Where-Object InstallerSpecificIdentifier | Select-Object -First 1
    if (-not $file -or -not $identity[$u.ID]) { continue }
    [pscustomobject]@{
        Name     = $file.InstallerSpecificIdentifier
        FileName = $file.FileName
        UpdateId = $identity[$u.ID].UpdateID
        Revision = $identity[$u.ID].RevisionNumber
    }
}

# 只要 x64 / neutral，每个包保留最新版本
$packages = $packages |
    Where-Object { $_.Name -match '_(x64|neutral)_' } |
    Group-Object { ($_.Name -split '_')[0] } |
    ForEach-Object { $_.Group | Sort-Object { [version]($_.Name -split '_')[1] } | Select-Object -Last 1 }

$packages | Format-Table Name, FileName -AutoSize

# 4. GetExtendedUpdateInfo2：取下载地址并下载
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
foreach ($p in $packages) {
    $body = Get-Template 'GetExtendedUpdateInfo2' @{ UpdateId = $p.UpdateId; Revision = $p.Revision }
    $resp = Invoke-Soap 'GetExtendedUpdateInfo2' $securedUrl $body
    $guid = [IO.Path]::GetFileNameWithoutExtension($p.FileName)
    $url  = $resp.Envelope.Body.GetExtendedUpdateInfo2Response.GetExtendedUpdateInfo2Result.FileLocations.FileLocation.Url |
        Where-Object { $_ -match $guid }   # 返回多个地址，取与该文件对应的那个

    $dest = Join-Path $OutDir ($p.Name + [IO.Path]::GetExtension($p.FileName))
    Write-Host "下载: $(Split-Path $dest -Leaf)"
    Invoke-WebRequest -Uri $url -OutFile $dest
}
Write-Host "完成，保存在 $OutDir"
