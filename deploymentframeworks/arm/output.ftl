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
    type
    apiVersion
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

    [@addToJsonOutput 
        name="resources"
        content=
            {
                "name": name,
                "type": type,
                "apiVersion": apiVersion
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
        [#-- the resourceId Azure template function requires a varying number of arguments 
        based on how many "segments" there are in the resource type namespace. --]
            [#local resourceIdParameters=[]]
            [#list ([type] + parentNames + [name]) as resourceIdParameter]
                [#local resourceIdParameters+=["'" + resourceIdParameter + "'"]]
            [/#list]

            [@armOutput
                name=name
                type="string"
                value="[resourceId(" + resourceIdParameters?join(", ") + ")]"
            /]
        [#else]
       
            [@armOutput
                name=name,
                type="string",
                value="[reference(name, apiVersion, 'Full')" + outputValue.Property?ensure_starts_with(".") + "]",
                (outputValue.condition)?has_content?then(condition=outputValue.condition,condition="")          
            /]

        [/#if]
    [/#list]
[/#macro]

[#macro arm_output_resource level="" include=""]

    [#-- Initialise outputs --]
    [@initialiseJsonOutput "resources" /]
    [@initialiseJsonOutput "outputs" /]

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