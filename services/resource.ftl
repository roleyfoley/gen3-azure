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

[#function processResourceNameConditions name profile parents...]

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
                [#local parentNamesLower = []]
                [#list asFlattenedArray(parents) as parent]
                    [#local parentNamesLower += [parent?lower_case] ]
                [/#list]
                [#local parents = parentNamesLower]
                [#break]
            [#case "segment_out_names"]
                [#-- This will always happen last --]
                [#local fullName = formatAzureResourceName(name, parents)]
                [#break]
            [#default]
                [@fatal
                    message="Error formatting Resource Id Reference: Azure Resource Profile Condition does not exist."
                    context=condition
                /]
                [#break]
        [/#switch]
    [/#list]

    [#return 
        {
            "name" : name,
            "fullName" : fullName,
            "parents" : parents
        }
    ]

[/#function]

[#-- Formats a given resourceId into an azure resourceId lookup function.
The scope of the lookup is dependant on the attributes provided. For the
Id of a resource within the same template, only the resourceId is necessary.
 --]
[#function formatAzureResourceIdReference
    resourceId
    resourceName
    subscriptionId=""
    resourceGroupName=""
    parentNames=[]]
    
    [#local resourceType = getResourceType(resourceId)]
    [#local resourceProfile = getAzureResourceProfile(resourceType)]

    [#local args = []]
    [#list [subscriptionId, resourceGroupName, resourceProfile.type] as arg]
        [#if arg?has_content]
            [#local args += [arg]]
        [/#if]
    [/#list]

    [#list parentNames as parent]
        [#local args += [parent]]
    [/#list]

    [#-- Ensure the post-processing resource name is included in argsnames --]
    [#local args += [resourceName]]

    [#return
        "[resourceId('" + concatenate(args, "', '") + "')]"
    ]

[/#function]

[#-- 
    Azure has strict rules around resource name "segments" (parts seperated by a '/'). 
    The rules that must be adhered to are:
        - A root level resource must have one less segment in the name than the 
            resource type (typically just the 1 segment).
        - Child resources must have the same number of segments as the child type.
            (this is typically 1 for the child, and 1 per parent resource.)
--]
[#function formatAzureResourceName name parentNames=[]]

    [#if parentNames?has_content]
        [#return formatRelativePath( (parentNames![]), name) ]
    [#else]
        [#return name]
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
[#function formatAzureResourceName name parentNames=[]]
    [#return formatRelativePath( (parentNames![]), name) ]
[/#function]

[#-- Formats a given resourceId into a Azure ARM lookup function for the current state of
a resource, be it previously deployed or within current template. This differs from
the previous function as the ARM function will return a full object, from which attributes
can be referenced via dot notation. --]
[#function formatAzureResourceReference
    resourceId
    resourceName
    serviceType=""
    parentNames=[]
    attributes... 
    ]

    [#local resourceType = getResourceType(resourceId)]
    [#local resourceProfile = getAzureResourceProfile(resourceType)]
    [#local apiVersion = resourceProfile.apiVersion]
    [#local typeFull = resourceProfile.type]
    [#local conditions = resourceProfile.conditions]

    [#-- Example: "[reference(resourceId(resourceType, resourceName), '0000-00-00', 'Full').properties.attribute]" --]
    [#return
        "[reference(resourceId('" + typeFull + "', '" + concatenate(parentNames, "', '") + resourceName + "'), '" + apiVersion + "', 'Full')." + (attributes?has_content)?then(attributes?join("."), "") + "]"
    ]
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

[#function getReference resourceId resourceName attributeType="" inRegion=""]
    [#if !(resourceId?has_content)]
        [#return ""]
    [/#if]
    [#if resourceId?is_hash]
        [#return
            {
                "Ref" : value.Ref
            }
        ]
    [/#if]
    [#if ((!(inRegion?has_content)) || (inRegion == region)) &&
        isPartOfCurrentDeploymentUnit(resourceId)]
        [#if attributeType?has_content]
            [#local resourceType = getResourceType(resourceId)]
            [#local mapping = getOutputMappings(AZURE_PROVIDER, resourceType, attributeType)]
            [#if (mapping.Attribute)?has_content]
                [#return
                    formatAzureResourceReference(resourceId, resourceName, resourceType, "", [], "")
                ]
            [#else]
                [#return
                    {
                        "Mapping" : "COTFatal: Unknown Resource Type",
                        "ResourceId" : resourceId,
                        "ResourceType" : resourceType
                    }
                ]
            [/#if]
        [/#if]
        [#return
            formatAzureResourceReference(resourceId, resourceName, "", "", [], "")
        ]
    [/#if]
    [#return
        getExistingReference(
            resourceId,
            attributeType,
            inRegion)
    ]
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