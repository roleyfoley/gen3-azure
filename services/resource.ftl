[#ftl]

[#-- Azure Resource Profiles --]
[#assign azureResourceProfiles = {}]
[#assign azureResourceProfilesConfiguration = 
    {
        "Properties" : [
            {
                "Type" : "",
                "Value" : "Attributes of a Resource Profile."
            }
        ],
        "Attributes" : [
            {
                "Names" : "type",
                "Type" : STRING_TYPE,
                "Mandatory" : true
            },
            {
                "Names" : "apiVersion",
                "Type" : STRING_TYPE,
                "Mandatory" : true
            },
            {
                "Names" : "conditions",
                "Type" : ARRAY_OF_STRING_TYPE,
                "Default" : []
            }
        ]
    }
]

[#macro addResourceProfile service resource profile]
    [@internalMergeResourceProfiles
        service=service
        resource=resource
        profile=profile
    /]
[/#macro]

[#-- Formats a given resourceId into a Azure ARM lookup function for the current state of
a resource, be it previously deployed or within current template. This differs from
the previous function as the ARM function will return a full object, from which attributes
can be referenced via dot notation. --]
[#function getReference
    resourceId
    resourceName
    outputType=REFERENCE_ATTRIBUTE_TYPE
    subscriptionId=""
    resourceGroupName=""
    attributes...]

    [#local resourceType = getResourceType(resourceId)]
    [#local resourceProfile = getAzureResourceProfile(resourceType)]
    [#local apiVersion = resourceProfile.apiVersion]
    [#local typeFull = resourceProfile.type]
    [#local conditions = resourceProfile.conditions]
    [#local nameSegments = getAzureResourceNameSegments(resourceName)]


    [#if isPartOfCurrentDeploymentUnit(resourceId)]
        [#if outputType = REFERENCE_ATTRIBUTE_TYPE]

            [#-- return a reference to the resourceId --]
            [#local args = []]
            [#list [subscriptionId, resourceGroupName, resourceProfile.type] as arg]
                [#if arg?has_content]
                    [#local args += [arg]]
                [/#if]
            [/#list]

            [#list nameSegments as segment]
                [#local args += [segment]]
            [/#list]

            [#return "[resourceId('" + concatenate(args, "', '") + "')]" ]
        [#else]
            [#if attributes?size = 1 && attributes?last = "name" ]
                [#-- "name" isn't a referencable attribute - but we already have access to it. --]
                [#return resourceName]
            [#else]
                [#-- return a reference to the specific resources attributes. --]
                [#-- Example: "[reference(resourceId(resourceType, resourceName), '0000-00-00', 'Full').properties.attribute]" --]
                [#return
                    "[reference(resourceId('" + typeFull + "', '" + concatenate(nameSegments, "', '") + "'), '" + apiVersion + "', 'Full')." + (attributes?has_content)?then(attributes?join("."), "") + "]"
                ]
            [/#if]
        [/#if]
    [#else]
        [#return getExistingReference(
            resourceId,
            attributeType,
            "",
            "",
            (subscriptionId?has_content)?then(
                subscriptionId,
                ""
            )
        )]
    [/#if]
[/#function]

[#-- 
    Azure has strict rules around resource name "segments" (parts seperated by a '/'). 
    The rules that must be adhered to are:
        - A root level resource must have one less segment in the name than the 
            resource type (typically just the 1 segment).
        - Child resources must have the same number of segments as the child type.
            (this is typically 1 for the child, and 1 per parent resource.)
--]
[#function formatAzureResourceName name profile primaryParent=""]
    
    [#local conditions = getAzureResourceProfile(profile).conditions]
    [#local conditions += ["segment_out_names"]]
    [#list conditions as condition]
        [#switch condition]
            [#case "alphanumeric_only"]
                [#local name = name?split("-")?join("")]
                [#break]
            [#case "name_to_lower"]
                [#local name = name?lower_case]
                [#break]
            [#case "parent_to_lower"]
                [#local primaryParent = primaryParent?lower_case ]
                [#break]
            [#case "segment_out_names"]
                [#-- This will always happen last --]
                [#local name = formatRelativePath( (primaryParent!""), name) ]
                [#break]
            [#default]
                [@fatal
                    message="Error formatting Resource Id Reference: Azure Resource Profile Condition does not exist."
                    context=condition
                /]
                [#break]
        [/#switch]
    [/#list]

    [#return name]

[/#function]

[#function getAzureResourceNameSegments resourceName]
    [#return resourceName?split("/")]
[/#function]

[#function getAzureResourceProfile resourceType serviceType=""]

    [#-- Service has been provided, so lookup can be specific --]
    [#if serviceType?has_content]
        [#list azureResourceProfiles[serviceType] as resource, attr]
            [#if resource == resourceType]
                [#local profileObj = azureResourceProfiles[serviceType][resource]]
            [/#if]
        [/#list]
    [#else]
        [#-- Service has not been specific, check all Services for the resourceType --]
        [#list azureResourceProfiles as service, resources]
            [#list resources as resource, attr]
                [#if resource = resourceType]
                    [#local profileObj = attr]
                [/#if]
            [/#list]
        [/#list]
    [/#if]

    [#if profileObj?has_content]
        [#return profileObj]
    [#else]
        [#return
            {
                "Mapping" : "COTFatal: ResourceProfile not found.",
                "ServiceType" : serviceType,
                "ResourceType" : resourceType
            }
        ]
    [/#if]
[/#function]

[#-- Get stack output --]
[#function getExistingReference resourceId attributeType="" inRegion="" inDeploymentUnit="" inAccount=(accountObject.AZUREId)!""]
    [#return getStackOutput(AZURE_PROVIDER, formatAttributeId(resourceId, attributeType), inDeploymentUnit, inRegion, inAccount) ]
[/#function]

[#-- Due to azure resource names having multiple segments, Azure requires
its own function to return the first split of the last segment --]
[#function getAzureResourceType resourceId]
    [#return resourceId?split("/")?last?split("X")[0]]
[/#function]

[#-------------------------------------------------------
-- Internal support functions for resource processing --
---------------------------------------------------------]

[#macro internalMergeResourceProfiles service resource profile]
    [#if profile?has_content ]
        [#assign azureResourceProfiles = 
            mergeObjects(
                azureResourceProfiles,
                { 
                    service : {
                        resource : getCompositeObject(
                            azureResourceProfilesConfiguration.Attributes,
                            profile
                        )
                    }
                } 
            )
        ]
    [/#if]
[/#macro]