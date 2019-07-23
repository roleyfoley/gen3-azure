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

 .PARAMETER templateFilePath
    Optional, path to the template file. Defaults to template.json.

 .PARAMETER parametersFilePath
    Optional, path to the parameters file. Defaults to parameters.json. If file is not found, will prompt for parameter values based on template.
#>

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
 $deploymentName
)

<#
.SYNOPSIS
    Registers RPs
#>
Function RegisterRP {
    Param(
        [string]$ResourceProviderNamespace
    )

    Write-Host "Registering resource provider '$ResourceProviderNamespace'";
    Register-AzResourceProvider -ProviderNamespace $ResourceProviderNamespace;
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

# sign in
Write-Host "Logging in...";
Login-AzAccount;

# select subscription
Write-Host "Selecting subscription '$subscriptionId'";
Select-AzSubscription -SubscriptionID $subscriptionId;

# Register RPs
$resourceProviders = @("microsoft.network","microsoft.compute","microsoft.devtestlab","microsoft.storage");
if($resourceProviders.length) {
    Write-Host "Registering resource providers"
    foreach($resourceProvider in $resourceProviders) {
        RegisterRP($resourceProvider);
    }
}

#Create or check for existing resource group
$resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if(!$resourceGroup)
{
    Write-Host "Resource group '$resourceGroupName' does not exist. To create a new resource group, please enter a location.";
    if(!$resourceGroupLocation) {
        $resourceGroupLocation = Read-Host "resourceGroupLocation";
    }
    Write-Host "Creating resource group '$resourceGroupName' in location '$resourceGroupLocation'";
    New-AzResourceGroup -Name $resourceGroupName -Location $resourceGroupLocation
}
else{
    Write-Host "Using existing resource group '$resourceGroupName'";
}

# Perform deployment and store the outputs
Write-Host "Starting deployment of network component...";
$outputs = (New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentName -TemplateFile "$($components.network)\template.json" -TemplateParameterFile "$($components.network)\testparameters.json").outputs

# Format the output for the next template.
$parameterObject = @{}
$outputs.Keys | ForEach-Object {
    $parameterObject += @{$_ = $($outputs[$_].Value)}
}

# Example using parameter object from outputs of first template.
Write-Host "Starting deployment of storage component...";
<<<<<<< HEAD
$outputs = (New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentName -TemplateFile "$($components.storage)\template.json" -TemplateParameterObject $parameterObject).Outputs

# Example of overloading the parameter file with extra parameter.
Write-Host "Starting deployment of virtualmachine component...";
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentName -TemplateFile "$($components.virtualmachines)\template.json" -TemplateParameterFile "$($components.virtualmachines)\testparameters.json" -subnetId $parameterObject["subnetId"] -storageAccountName $outputs["storageAccountName"].Value
=======
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentName -TemplateFile "$($components.storage)\template.json" -TemplateParameterObject $parameterObject

# Example of overloading the parameter file with extra parameter.
Write-Host "Starting deployment of virtualmachine component...";
New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -Name $deploymentName -TemplateFile "$($components.virtualmachines)\template.json" -TemplateParameterFile "$($components.virtualmachines)\testparameters.json" -subnetId $outputs.subnetId.Value
>>>>>>> b3b487264bcdd93b5a12a78ff76ee28b3d6836fa
