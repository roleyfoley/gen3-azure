<#
    .SYNOPSIS
        Deploys a template to Azure

    .DESCRIPTION
        Deploys an Azure Resource Manager template

    .PARAMETER subscriptionId
        The subscription id where the template will be deployed.

    .PARAMETER resourceGroupName
        The resource group where the template will be deployed. Can be the name of an existing or a new resource group.

    .PARAMETER resourceGroupLocation
        Optional, a resource group location. If specified, will try to create a new resource group in this location. If not specified, assumes resource group is existing.

    .PARAMETER deploymentName
        The deployment name.

    .PARAMETER resourceProviders
        The Resource Provider namespaces that will be utilised during resource deployment.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$True)]
    [string]
    $subscriptionId,

    [Parameter(Mandatory=$True)]
    [string]
    $resourceGroupName,

    [string]
    $resourceGroupLocation,

    [Parameter(Mandatory=$True)]
    [string]
    $deploymentName,

    [string[]]
    $resourceProviders = @(
        'microsoft.network',
        'microsoft.compute',
        'microsoft.devtestlab',
        'microsoft.storage'
    )
)

<#
.SYNOPSIS
    Registers Resource Providers if required.
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    $reg = Get-AzResourceProvider -ListAvailable | Where-Object { 
        $_.ProviderNamespace -eq $ResourceProviderNamespace 
    }

    if($reg.RegistrationState -ne "Registered"){
        Write-Output "Registering resource provider '$ResourceProviderNamespace'"
        Register-AzResourceProvider -ProviderNamespace $ResourceProviderNamespace
    }
    else {
        Write-Output "Resource provider '$resourceProviderNamespace' is already registered."
    }
}

#******************************************************************************
# Script body
# Execution begins here
#******************************************************************************
$ErrorActionPreference = "Stop"

$components = @{
    "network" = "$PSScriptRoot\network";
    "storage" = "$PSScriptRoot\storage";
    "virtualmachines" = "$PSScriptRoot\virtualmachines"
}

# sign in if necessary
$currentAzContext = Get-AzContext
if ([string]::IsNullOrEmpty($currentAzContext).Account){
    Write-Output "No existing Azure context found. Requires login...";
    Login-AzAccount
} 
else {
    Write-Output "Currently logged in as: $($currentAzContext.Account)"
    Write-Output "Subscription:           $($currentAzContext.SubscriptionName)"
    Write-Output "Environment:            $($currentAzContext.Environment)"
}



# select subscription
Write-Output "Selecting subscription '$subscriptionId'";
Select-AzSubscription -SubscriptionID $subscriptionId;

# Register RPs
if($resourceProviders.length) {
    Write-Output "Starting Resource Provider check..."
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP -ResourceProviderNamespace $resourceProvider
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Output "Resource group '$resourceGroupName' does not exist. Creating..."
    if(!$resourceGroupLocation) {
        Write-Output "To create a new resource group, please enter a location."
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Output "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Output "Using existing resource group '$resourceGroupName'";
}

# Perform deployment and store the outputs
Write-Output "Starting deployment of network component..."
$outputs = (
    New-AzResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -Name $deploymentName `
        -TemplateFile "$($components.network)\template.json" `
        -TemplateParameterFile "$($components.network)\testparameters.json").outputs

# Format the output for the next template.
$parameterObject = @{}
$outputs.Keys | ForEach-Object {
    $parameterObject += @{$_ = $($outputs[$_].Value)}
}

# Example using parameter object from outputs of first template.
Write-Output "Starting deployment of storage component...";
$outputs = (
    New-AzResourceGroupDeployment `
        -ResourceGroupName $resourceGroupName `
        -Name $deploymentName `
        -TemplateFile "$($components.storage)\template.json" `
        -TemplateParameterObject $parameterObject).Outputs

# Example of overloading the parameter file with extra parameter.
Write-Output "Starting deployment of virtualmachine component...";
New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -Name $deploymentName `
    -TemplateFile "$($components.virtualmachines)\template.json" `
    -TemplateParameterFile "$($components.virtualmachines)\testparameters.json" `
    -subnetId $parameterObject["subnetId"] `
    -storageAccountName $outputs["storageAccountName"].Value

Write-Output "Script successful."