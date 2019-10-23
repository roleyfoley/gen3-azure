[#ftl]

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
        "ResourceGroup": { "type": "string", "value": "[resourceGroup().id]"},
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
    /]
[/#macro]

[#macro armResource
    name
    profile
    identity={}
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
    
    [#--
        Note - "Identity" is a unique attribute and is not available to resources
        that can be assigned a Managed Identity
    --]

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
    [#if ! (resourceProfile["type"]?has_content || resourceProfile["apiVersion"]?has_content || resourceProfile["conditions"]?has_content)]
        [@fatal
            message="Azure Resource Profile is incomplete. Requires 'type' and 'apiVersion' attributes for all resources."
            context=resourceProfile
        /]
    [/#if]
    
    [#local segmentedName = formatAzureResourceName(name, parentNames)]

    [#-- Resource Profile Conditions Processing --]
    [#local resourceContent = 
        {
            "name": segmentedName,
            "type": resourceProfile.type,
            "apiVersion": resourceProfile.apiVersion,
            "properties": properties
        } +
        attributeIfContent("identity", identity) +
        attributeIfContent("location", location) +
        attributeIfContent("dependsOn", dependsOn) +
        attributeIfContent("tags", tags) +
        attributeIfContent("comments", comments) +
        attributeIfContent("copy", copy) +
        attributeIfContent("sku", sku) +
        attributeIfContent("kind", kind) +
        attributeIfContent("plan", plan) +
        attributeIfContent("resources", resources)
    ]

    [#list resourceProfile.conditions as condition]
        [#switch condition]
            [#case "name_to_lower"]
                [#local resourceContent = mergeObjects(
                    resourceContent,
                    { "name" : segmentedName?lower_case }
                )]
                [#break]
            [#case "parent_to_lower"]
                [#break]
            [#default]
                [@fatal
                    message="Azure Resource Profile Condition does not exist."
                    context=condition
                /]
                [#break]
        [/#switch]
    [/#list]

    [@addToJsonOutput 
        name="resources"
        content=[resourceContent]
    /]

    [#list outputs as outputType,outputValue]
        [#if outputType == REFERENCE_ATTRIBUTE_TYPE]

            [#-- format the ARM function: resourceId() --]
            [#local reference=formatAzureResourceIdReference(segmentedName, type)]

            [@armOutput
                name=name
                type="string"
                value=reference
            /]
            
        [#else]
            [#if outputValue.Property?has_content!false]

                [#-- format the ARM function: reference() --] 
                [#local reference=formatAzureResourceReference(
                    segmentedName,
                    type,
                    "",
                    parentNames,
                    outputValue.Property!""
                )]
        
                [@armOutput
                    name=formatAttributeId(name, outputType)
                    type="string"
                    type=((value.Property)!false)?then(
                        "string",
                        "object"
                    )
                    value=reference
                /] 
            [/#if]
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

    [#if getOutputContent("resources")?has_content || logMessages?has_content]
        [@toJSON
            {
                '$schema': "https://schema.management.azure.com/schemas/2015-01-01/deploymentTemplate.json#",
                "contentVersion": "1.0.0.0",
                "parameters": {},
                "variables": {},
                "resources": getOutputContent("resources"),
                "outputs":
                    getOutputContent("outputs") +
                    getArmTemplateCoreOutputs()
            }
        /]
    [/#if]
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