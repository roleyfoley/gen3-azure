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
    [Parameter(Mandatory = $True)]
    [string]
    $subscriptionId,

    [Parameter(Mandatory = $True)]
    [string]
    $resourceGroupName,

    [string]
    $resourceGroupLocation,

    [Parameter(Mandatory = $True)]
    [string]
    $deploymentName,

    [string[]]
    $resourceProviders = @(
        'microsoft.network',
        'microsoft.compute',
        'microsoft.devtestlab',
        'microsoft.storage',
        'microsoft.authorization',
        'Microsoft.managedidentity'
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

    if ($reg.RegistrationState -ne "Registered") {
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
    "network"         = "$PSScriptRoot\network";
    "storage"         = "$PSScriptRoot\storage";
    "virtualmachines" = "$PSScriptRoot\virtualmachines";
    "iam"             = "$PSScriptRoot\iam";
    "rbac"            = "$PSScriptRoot\rbac";
}

# sign in if necessary
$currentAzContext = Get-AzContext
if ([string]::IsNullOrEmpty($currentAzContext).Account) {
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
if ($resourceProviders.length) {
    Write-Output "Starting Resource Provider check..."
    foreach ($resourceProvider in $resourceProviders) {
        RegisterRP -ResourceProviderNamespace $resourceProvider
    }
}

#Create or check for existing resource groups (one per component)
foreach ($component in $components.Keys) {
    $resourceGroup = Get-AzResourceGroup -Name "$resourceGroupName-$component" -ErrorAction SilentlyContinue
    if (!$resourceGroup) {
        Write-Output "Resource group '$resourceGroupName-$component' does not exist. Creating..."
        if (!$resourceGroupLocation) {
            Write-Output "To create a new resource group, please enter a location."
            $resourceGroupLocation = Read-Host "resourceGroupLocation";
        }
        Write-Output "Creating resource group '$resourceGroupName-$component' in location '$resourceGroupLocation'";
        New-AzResourceGroup -Name "$resourceGroupName-$component" -Location $resourceGroupLocation
    }
    else {
        Write-Output "Using existing resource group '$resourceGroupName-$component'";
    }
}

# 
Write-Output "Starting deployment of IAM component..."
$outputsIAM = (
    New-AzResourceGroupDeployment `
        -name $deploymentName `
        -ResourceGroupName "$resourceGroupName-iam" `
        -TemplateFile "$($components.iam)\template.json" `
        -TemplateParameterFile "$($components.iam)\testparameters.json").Outputs

do {
    Start-Sleep -Seconds 5
} while (!$(Get-AzResource -ResourceGroupName "$resourceGroupName-iam" -Name "identity-*"))

Write-Output "Starting deployment of RBAC component..."  
New-AzDeployment `
    -Name $deploymentName `
    -Location $resourceGroupLocation `
    -TemplateFile "$($components.rbac)\template.json" `
    -TemplateParameterFile "$($components.rbac)\testparameters.json" `
    -principalId $outputsIAM["principalId"].Value

# Perform deployment and store the outputs
Write-Output "Starting deployment of network component..."
$outputsNetwork = (
    New-AzResourceGroupDeployment `
        -ResourceGroupName "$resourceGroupName-network" `
        -Name $deploymentName `
        -TemplateFile "$($components.network)\template.json" `
        -TemplateParameterFile "$($components.network)\testparameters.json").outputs

# Format the output for the next template.
$parameterObject = @{ }
$outputsNetwork.Keys | ForEach-Object {
    $parameterObject += @{$_ = $($outputsNetwork[$_].Value) }
}

# Example using parameter object from outputs of first template.
Write-Output "Starting deployment of storage component...";
$outputsStorage = (
    New-AzResourceGroupDeployment `
        -ResourceGroupName "$resourceGroupName-storage" `
        -Name $deploymentName `
        -TemplateFile "$($components.storage)\template.json" `
        -TemplateParameterObject $parameterObject).Outputs

# Example of overloading the parameter file with extra parameter.
Write-Output "Starting deployment of virtualmachine component...";
New-AzResourceGroupDeployment `
    -ResourceGroupName "$resourceGroupName-virtualmachines" `
    -Name $deploymentName `
    -TemplateFile "$($components.virtualmachines)\template.json" `
    -TemplateParameterFile "$($components.virtualmachines)\testparameters.json" `
    -subnetId $outputsNetwork["subnetId"].Value `
    -storageAccountName $outputsStorage["storageAccountName"].Value `
    -vmIdentityName $outputsIAM["identityName"].Value `
    -vmIdentityResourceGroup $outputsIAM["identityResourceGroup"].Value

Write-Output "Script successful."