#requires -Version 7.0
<#
.SYNOPSIS
    通过微软官方 Store 接口，按 ProductId 下载应用包（不依赖 rg-adguard）。
.EXAMPLE
    ./Get-StorePackage.ps1 -ProductId 9wzdncrfjbmp
    ./Get-StorePackage.ps1 -ProductId 9wzdncrfjbmp -Arch arm64 -ListOnly
#>
param(
    [Parameter(Mandatory)][string]$ProductId,
    [ValidateSet('x64', 'x86', 'arm64', 'arm')][string]$Arch = 'x64',
    [ValidateSet('Retail', 'RP', 'WIS', 'WIF')][string]$Ring = 'Retail',
    [string]$OutDir = (Join-Path $PWD $ProductId),
    [switch]$ListOnly,
    [switch]$SkipCertificateCheck   # Linux 上缺少微软 Update 根证书时使用
)

$ErrorActionPreference = 'Stop'
$wuUrl = 'https://fe3.delivery.mp.microsoft.com/ClientWebService/client.asmx'

# 发送 SOAP 请求，返回 XML
function Invoke-Soap([string]$Url, [string]$Body) {
    $resp = Invoke-WebRequest -Uri $Url -Method Post -Body $Body `
        -ContentType 'application/soap+xml; charset=utf-8' -SkipCertificateCheck:$SkipCertificateCheck
    [xml]$resp.Content
}

# SOAP 信封（Header 里带一个空的设备票据，匿名访问公开应用即可）
function New-SoapEnvelope([string]$Action, [string]$Url, [string]$BodyXml) {
    $now = [DateTime]::UtcNow
    @"
<s:Envelope xmlns:a="http://www.w3.org/2005/08/addressing" xmlns:s="http://www.w3.org/2003/05/soap-envelope">
  <s:Header>
    <a:Action s:mustUnderstand="1">http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService/$Action</a:Action>
    <a:MessageID>urn:uuid:$([guid]::NewGuid())</a:MessageID>
    <a:To s:mustUnderstand="1">$Url</a:To>
    <o:Security s:mustUnderstand="1" xmlns:o="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
      <Timestamp xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
        <Created>$($now.ToString('o'))</Created>
        <Expires>$($now.AddMinutes(5).ToString('o'))</Expires>
      </Timestamp>
      <wuws:WindowsUpdateTicketsToken wsu:id="ClientMSA" xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" xmlns:wuws="http://schemas.microsoft.com/msus/2014/10/WindowsUpdateAuthorization">
        <TicketType Name="AAD" Version="1.0" Policy="MBI"></TicketType>
      </wuws:WindowsUpdateTicketsToken>
    </o:Security>
  </s:Header>
  <s:Body>$BodyXml</s:Body>
</s:Envelope>
"@
}

# 1. ProductId -> WuCategoryId
$catalog = Invoke-RestMethod "https://displaycatalog.mp.microsoft.com/v7.0/products/$($ProductId)?market=US&languages=en-US"
$fulfillment = $catalog.Product.DisplaySkuAvailabilities[0].Sku.Properties.FulfillmentData
if (-not $fulfillment) { throw "$ProductId 不是可通过 WU 下载的 UWP/MSIX 应用（可能是 Win32 应用）。" }
$categoryId = $fulfillment.WuCategoryId
Write-Host "WuCategoryId: $categoryId"

# 2. GetCookie：拿到会话 cookie
$cookieBody = '<GetCookie xmlns="http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService"><oldCookie></oldCookie><lastChange>2015-10-21T17:01:07.1472913Z</lastChange><currentTime>2015-10-21T17:01:07.1472913Z</currentTime><protocolVersion>1.40</protocolVersion></GetCookie>'
$cookieResp = Invoke-Soap $wuUrl (New-SoapEnvelope 'GetCookie' $wuUrl $cookieBody)
$cookie = $cookieResp.Envelope.Body.GetCookieResponse.GetCookieResult.EncryptedData

# 3. SyncUpdates：列出该应用及其依赖的所有包
$syncBody = @"
<SyncUpdates xmlns="http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService">
  <cookie><Expiration>2100-01-01T00:00:00Z</Expiration><EncryptedData>$cookie</EncryptedData></cookie>
  <parameters>
    <ExpressQuery>false</ExpressQuery>
    <InstalledNonLeafUpdateIDs>
      $((1,2,3,11,19,544,549,2359974,2359977,5169044,8788830,23110993,23110994,54341900,54343656,59830006,59830007,59830008,60484010,62450018,62450019,62450020,66027979,66053150,97657898,98822896,98959022,98959023,98959024,98959025,98959026,104433538,104900364,105489019,117765322,129905029,130040031,132387090,132393049,133399034,138537048,140377312,143747671,158941041,158941042,158941043,158941044,159123858,159130928,164836897,164847386,164848327,164852241,164852246,164852252,164852253) | ForEach-Object { "<int>$_</int>" })
    </InstalledNonLeafUpdateIDs>
    <SkipSoftwareSync>false</SkipSoftwareSync>
    <NeedTwoGroupOutOfScopeUpdates>true</NeedTwoGroupOutOfScopeUpdates>
    <FilterAppCategoryIds><CategoryIdentifier><Id>$categoryId</Id></CategoryIdentifier></FilterAppCategoryIds>
    <TreatAppCategoryIdsAsInstalled>true</TreatAppCategoryIdsAsInstalled>
    <AlsoPerformRegularSync>false</AlsoPerformRegularSync>
    <ComputerSpec/>
    <ExtendedUpdateInfoParameters>
      <XmlUpdateFragmentTypes><XmlUpdateFragmentType>Extended</XmlUpdateFragmentType></XmlUpdateFragmentTypes>
      <Locales><string>en-US</string></Locales>
    </ExtendedUpdateInfoParameters>
    <ProductsParameters>
      <SyncCurrentVersionOnly>false</SyncCurrentVersionOnly>
      <DeviceAttributes>BranchReadinessLevel=CB;CurrentBranch=rs_prerelease;OEMModel=Virtual Machine;FlightRing=$Ring;AttrDataVer=21;SystemManufacturer=Microsoft Corporation;InstallLanguage=en-US;OSUILocale=en-US;InstallationType=Client;FlightingBranchName=external;OSSkuId=48;App=WU;ProcessorManufacturer=GenuineIntel;OEMName_Uncleaned=Microsoft Corporation;AppVer=1.0;OSArchitecture=AMD64;IsFlightingEnabled=1;TelemetryLevel=1;DefaultUserRegion=244;WuClientVer=1.0;OSVersion=10.0.22621.1;DeviceFamily=Windows.Desktop</DeviceAttributes>
      <CallerAttributes>Interactive=1;IsSeeker=0;</CallerAttributes>
      <Products/>
    </ProductsParameters>
  </parameters>
</SyncUpdates>
"@
$sync = Invoke-Soap $wuUrl (New-SoapEnvelope 'SyncUpdates' $wuUrl $syncBody)
$result = $sync.Envelope.Body.SyncUpdatesResponse.SyncUpdatesResult

# NewUpdates 里有 UpdateID / RevisionNumber，按内部 ID 建索引
$identity = @{}
foreach ($u in $result.NewUpdates.UpdateInfo) {
    $identity[$u.ID] = ([xml]"<root>$($u.Xml)</root>").root.UpdateIdentity
}

# ExtendedUpdateInfo 里有文件名，两者按 ID 对应起来
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

# 每个包只保留匹配架构的最新版本
$packages = $packages |
    Where-Object { $_.Name -match "_($Arch|neutral)_" } |
    Group-Object { ($_.Name -split '_')[0] + '_' + ($_.Name -split '_')[2] } |
    ForEach-Object { $_.Group | Sort-Object { [version]($_.Name -split '_')[1] } | Select-Object -Last 1 }

$packages | Format-Table Name, FileName -AutoSize
if ($ListOnly) { return }

# 4. GetExtendedUpdateInfo2：拿到每个包的下载地址并下载
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
foreach ($p in $packages) {
    $body = @"
<GetExtendedUpdateInfo2 xmlns="http://www.microsoft.com/SoftwareDistribution/Server/ClientWebService">
  <updateIDs><UpdateIdentity><UpdateID>$($p.UpdateId)</UpdateID><RevisionNumber>$($p.Revision)</RevisionNumber></UpdateIdentity></updateIDs>
  <infoTypes><XmlUpdateFragmentType>FileUrl</XmlUpdateFragmentType><XmlUpdateFragmentType>FileDecryption</XmlUpdateFragmentType></infoTypes>
  <deviceAttributes>FlightRing=$Ring;</deviceAttributes>
</GetExtendedUpdateInfo2>
"@
    $secured = "$wuUrl/secured"
    $resp = Invoke-Soap $secured (New-SoapEnvelope 'GetExtendedUpdateInfo2' $secured $body)
    $url = $resp.Envelope.Body.GetExtendedUpdateInfo2Response.GetExtendedUpdateInfo2Result.FileLocations.FileLocation.Url |
        Where-Object { $_ -match [IO.Path]::GetFileNameWithoutExtension($p.FileName) }   # 返回多个地址，取与该文件对应的那个

    $ext = [IO.Path]::GetExtension($p.FileName)
    $dest = Join-Path $OutDir ($p.Name + $ext)
    Write-Host "下载: $($p.Name)$ext"
    Invoke-WebRequest -Uri $url -OutFile $dest
}
Write-Host "完成，保存在 $OutDir"
