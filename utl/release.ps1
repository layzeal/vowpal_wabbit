param([string]$githubToken, [string]$repo = "eisber")

$version = ([xml](Get-Content -Path cs\version.props)).Project.PropertyGroup.VowpalWabbitAssemblyVersion

# package multiple VM sizes
Copy-Item .\cs\azure_service\OnlineTrainerContent\* .\vowpalwabbit\x64\ReleaseRole

# https://azure.microsoft.com/en-us/documentation/articles/cloud-services-sizes-specs/
$vmsizes = "ExtraSmall", "Standard_D1_v2", "Standard_D2_v2", "Standard_D3_v2", "Standard_D4_v2", "Standard_D5_v2"
$csdef = [xml](Get-Content .\cs\azure_service\ServiceDefinition.csdef)

foreach ($vmsize in $vmsizes) {
    $csdef.ServiceDefinition.WorkerRole.vmsize = $vmsize
    Set-Content -Value $csdef.OuterXml .\vowpalwabbit\x64\ReleaseRole\ServiceDefinition.csdef

    ."C:\Program Files\Microsoft SDKs\Azure\.NET SDK\v2.9\bin\cspack.exe" "vowpalwabbit\x64\ReleaseRole\ServiceDefinition.csdef" "/role:OnlineTrainer;vowpalwabbit\x64\ReleaseRole" "/rolePropertiesFile:OnlineTrainer;cs\azure_service\RoleProperties.txt" "/out:vowpalwabbit\x64\VowpalWabbit.Azure.$version.$vmsize.cspkg"
}

$body = @{ tag_name = "v$version"; name = "v$version"; body = "v$version"; draft = $false; prerelease = $false }
$release = Invoke-RestMethod -Headers @{ Authorization = "token $githubToken" }  https://api.github.com/repos/$repo/vowpal_wabbit/releases -Method Post -Body (ConvertTo-Json $body)

Write-Host $release

function PrintException 
{
   [Exception]$e = $_;
   for ($i=1;($i -le 10) -and ($e -ne $null);$i++) {
        Write-Host $e.Message $e.StackTrace
        $e = $e.InnerException
   }
}

try {
    foreach ($vmsize in $vmsizes) {
        Write-Host "Publishing cloud service for VM size $vmsize..."
        $url = ($release.upload_url.Replace("{?name,label}", "?name=VowpalWabbit.Azure.$version.$vmsize.cspkg"))
        $asset = Invoke-RestMethod -Headers @{ Authorization = "token $githubToken" } -Method Post -ContentType "application/zip" -InFile vowpalwabbit\x64\VowpalWabbit.Azure.$version.$vmsize.cspkg $url
    }
}
catch { PrintException }

try {
    Write-Host "Publishing desktop installer..."
    $url = ($release.upload_url.Replace("{?name,label}", "?name=VowpalWabbit-$version.msi"))
    $asset = Invoke-RestMethod -Headers @{ Authorization = "token $githubToken" } -Method Post -ContentType "application/zip" -InFile vowpalwabbit\x64\Release\VowpalWabbit.msi $url
}
catch { PrintException }