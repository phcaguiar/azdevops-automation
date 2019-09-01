param(
    [Parameter(Mandatory=$true)]$VstsInstanceName,
    [Parameter(Mandatory=$true)]$VstsPersonalAccessToken,
    [Parameter(Mandatory=$true)]$ProjectName,
    [Parameter(Mandatory=$true)]$BuildDefinitionName,
    [Parameter(Mandatory=$false)]$badgeEnabled,
    [Parameter(Mandatory=$false)]$buildNumberFormat,
    [Parameter(Mandatory=$true)]$agentqueuename,
    [Parameter(Mandatory=$true)]$repositoryname,
    $ApiVersion = "5.1"
)

function Get-DefaultHeaders ($VstsPersonalAccessToken) {
    
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "",$VstsPersonalAccessToken)))
    $basicAuthToken = "Basic $base64AuthInfo"
    return @{ Accept = "application/json"; Authorization = $basicAuthToken}
}

function Test-BuildDefinition($VstsBaseUrl,$ProjectName,$BuildDefinitionName,$ApiVersion,$VstsPersonalAccessToken){
    
    $httpHeaders = Get-DefaultHeaders $VstsPersonalAccessToken
    try {
        
        $response = Invoke-RestMethod "$VstsBaseUrl/$($ProjectName)/_apis/build/definitions?name=$($BuildDefinitionName)&api-version=$ApiVersion" -Headers $httpHeaders -UseBasicParsing
        # Debug log
        Write-Verbose "Build Definition check response: `n $($response | ConvertTo-Json -Compress)"

        return $true
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq "NotFound") {
            # Debug log
            Write-Verbose "Build Definition check response: `n $_"

            return $false
        }else{
            Write-Error "Unexpected API response: $_"
        }
    }
}

# Stop script at any error/exception.
$ErrorActionPreference = "Stop"

# Mount API base url
$VstsBaseUrl = "https://$VstsInstanceName.visualstudio.com/DefaultCollection"

# Abort execution if build definition already exists.
if (Test-BuildDefinition $VstsBaseUrl $ProjectName $BuildDefinitionName -ApiVersion "1.0"  $VstsPersonalAccessToken) {
    if($SkipIfBuildDefinitionAlreadyExists){
        Write-Verbose "Build Definition $BuildDefinitionName already exists, skipping creation."
        exit
    }
    Write-Error "Build Definition $BuildDefinitionName already exists."
}

# Request payload to create an build definition.
$requestObject = @{
    name = $BuildDefinitionName
    project = $ProjectName
    badgeEnabled = $badgeEnabled
    buildNumberFormat = $buildNumberFormat
    queue = @{
        name = $agentqueuename
    }
    repository = @{
        name = $repositoryname
    }
}
$jsonRequest = $requestObject | ConvertTo-Json -Compress

# Debug log
Write-Verbose "Request payload: `n $jsonRequest"

# Send HTTP POST request to create the build definition.
$httpHeaders = Get-DefaultHeaders $VstsPersonalAccessToken
$requestUrl = "$VstsBaseUrl/$ProjectName/_apis/build/definitions?name=$BuildDefinitionName&api-version=$ApiVersion"
Invoke-RestMethod $requestUrl  -Method Post -Body $jsonRequest -UseBasicParsing -Headers $httpHeaders -ContentType "application/json"
