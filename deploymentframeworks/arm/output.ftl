[#function getArmTemplateDefaultOutputs]
    [#return
        {
            REFERENCE_ATTRIBUTE_TYPE : {
                "Attribute" : "id"
            }
        }
    ]
[/#function]

[#function getArmTemplateCoreOutputs deploymentUnit=deploymentUnit]
    [#return {
        "Subscription": { "type": "string", "value": "[subscription().id]"},
        "ResourceGroup: { "type": "string", "value": "[resourceGroup().id]"},
        "Region": { "type": "string", "value": "[resourceGroup().location]"},
        "DeploymentUnit": {
            "type": "string",
            "value": 
                deploymentUnit +
                (
                    (!(ignoreDeploymentUnitSubsetInOutputs!false)) &&
                    (deploymentUnitSubset?has_content)
                )?then(
                    "-" + deploymentUnitSubset?lower_case,
                    ""
                )
        }
    }]
[/#function]

[#macro armOutput name type value condition=""]
    [@mergeWithJsonOutput
        name="outputs"
        content=
            {
                name : { 
                    "type" : type,
                    "value" : value 
                } + 
                attributeIfContent("condition", condition)
            }
    ]
[/#macro]

[#macro armResource
    name
    profile
    location=""
    dependsOn=[]
    properties={}
    tags={}
    comments=""
    copy={}
    sku={}
    kind=""
    plan={}
    resources=[]
    parentNames=[]
    outputs={}]

    [#-- TODO(rossmurr4y): impliment localDependencies as the AWS provider does. --]
    [#-- The AWS Provider checks that the dependencies exist with the getReference
        function first, assembles a new array from those that do, and impliments only those. 
        The getReference function calls on the getExistingReference function, which has
        some AWS-specific components to it. This will need to be implimented in:
        gen3-azure/azure/services/resource.ftl before it can be utilised. --]
    [#-- 
        [#local localDependencies = [] ]
        [#list asArray(dependencies) as resourceId]
            [#if getReference(resourceId)?is_hash]
                [#local localDependencies += [resourceId] ]
            [/#if]
        [/#list]
    --]

    [#local resourceProfile = getAzureResourceProfile(profile)]
    [#if ! (resourceProfile?contains("type") || resourceProfile?contains("apiVersion"))]
        [@fatal
            message="Azure Resource Profile is incomplete. Requires 'type' and 'apiVersion' attributes for all resources."
            context=core
        /]
    [/#if]

    [@addToJsonOutput 
        name="resources"
        content=
            {
                "name": name,
                "type": resourceProfile.Type,
                "apiVersion": resourceProfile.apiVersion
                "properties": properties
            } +
            attributeIfContent("location", location) +
            attributeIfContent("dependsOn", dependsOn) +
            attributeIfContent("tags", tags) +
            attributeIfContent("comments", comments) +
            attributeIfContent("copy", copy) +
            attributeIfContent("sku", sku) +
            attributeIfContent("kind", kind) +
            attributeIfContent("plan", plan) +
            attributeIfContent("resources", resources)
    /]

    [#list outputs as outputType,outputValue]
        [#if outputValue.UseRef!false]

            [#-- format the ARM function: resourceId() --]
            [#local reference= 
                formatAzureResourceIdReference(
                    resourceId=name
                    resourceType=type
                )
            ]

            [@armOutput
                name=name
                type="string"
                value=reference
            /]
        [#else]

            [#-- format the ARM function: reference() --] 
            [#local reference= 
                formatAzureResourceReference(
                    resourceId=name
                    resourceType=type
                    attributes=outputValue.Property
                )
            ]
       
            [@armOutput
                name=name,
                type="string",
                value=reference   
            /]

        [/#if]
    [/#list]
[/#macro]

[#macro arm_output_resource level="" include=""]

    [#-- Resources --]
    [#if include?has_content]
        [#include include?ensure_starts_with("/")]
    [#else]
        [@processComponents level /]
    [/#if]

    [#if getOutput("resources")?has_content || logMessages?has_content]
        [@toJSON
            {
                "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
                "contentVersion": "1.0.0.0",
                "parameters": {},
                "variables": {},
                "resources": getOutput("resources"),
                "outputs":
                    getOutput("outputs") +
                    getArmTemplateCoreOutputs()
            } +
            attributeIfContent("COTMessages", logMessages)
        /]
    [#if]
[/#macro]


[#-- Initialise the possible outputs to make sure they are available to all steps --]
[@initialiseJsonOutput name="resources" /]
[@initialiseJsonOutput name="outputs" /]

[#assign AZURE_OUTPUT_RESOURCE_TYPE = "resource" ]

[@addGenPlanStepOutputMapping 
    provider=AZURE_PROVIDER
    subsets=[
        "template"
    ]
    outputType=AZURE_OUTPUT_RESOURCE_TYPE
    outputFormat=""
/]
