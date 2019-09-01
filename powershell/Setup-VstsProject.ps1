param(
    [Parameter(Mandatory = $true)]$VstsInstanceName,
    [Parameter(Mandatory = $true)]$VstsPersonalAccessToken,
    [Parameter(Mandatory = $true)]$InJsonFile,
    [switch]$SkipIfProjectAlreadyExists
)

function Test-Script ($scriptName) {
    $scriptPath = Join-Path $PSScriptRoot $scriptName
    if (-not (Test-Path $scriptPath)) {
        Write-Error "Script not found: $scriptName. Expected to be in the same directory of this script."
    }
}

# Stop script at any error/exception.
$ErrorActionPreference = "Stop"

# Validate and parse input file
if (-not (Test-Path $InJsonFile)) {
    Write-Error "Input json file not found: $InJsonFile"
}
$parameters = Get-Content $InJsonFile -Encoding UTF8 | ConvertFrom-Json

# Create build definition.
$parameters.buildDefinition | ForEach-Object {$i = 1}{
    $BuildDefinitionName = $_.name
    
    Write-Output "Creating build definition $($BuildDefinitionName) ($i/$($parameters.buildDefinition.Length))"
    $i++

    Test-Script "New-VstsBuildDefinition.ps1"

    $scriptArgs = @{
        VstsInstanceName           = $VstsInstanceName
        VstsPersonalAccessToken    = $VstsPersonalAccessToken
        ProjectName                = $_.project
        BuildDefinitionName        = $_.name
        badgeEnabled               = $_.badgeEnabled
        buildNumberFormat          = $_.buildNumberFormat
        agentqueuename             = $_.queue
        repositoryname             = $_.repository
    }

    $newBuildDefinition = iex "$PSScriptRoot\New-VstsBuildDefinition.ps1 @scriptArgs"

    # Skip changes if build definition already exists.
    if ($newBuildDefinition) {
        Write-Verbose "New build definition $BuildDefinitionName created."
        Write-Output $newProject
        # Wait API ensure build definition exists. (sending an endpoint creation request after build definition creation throws api error saying build definition doesnt exits.)
        Start-Sleep -Seconds 2
    }
    elseif ($SkipIfProjectAlreadyExists) {
        Write-Output "Build definition $BuildDefinitionName already exists, skipping changes."
        return
    }

    Write-Output "Build definition already exists. Updating Build definition $BuildDefinitionName..."

}
