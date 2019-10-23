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

[#-- Formats a given resourceId into an azure resourceId lookup function.
The scope of the lookup is dependant on the attributes provided. For the
Id of a resource within the same template, only the resourceId is necessary.
 --]
[#function formatAzureResourceIdReference
    resourceId
    resourceType=""
    subscriptionId=""
    resourceGroupName=""
    resourceNames...]
    
    [#if ! resourceType?has_content]
        [#local resourceType = getResourceType(resourceId)]
    [/#if]

    [#local args = []]
    [#list [subscriptionId, resourceGroupName, resourceType, resourceId, resourceNames] as arg]

        [#if arg?has_content]
            [#local args += [arg]]
        [/#if]

        [#return
            "[resourceId(" + args?join(", ") + ")]"
        ]
    [/#list]
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

[#-- Formats a given resourceId into a Azure ARM lookup function for the current state of
a resource, be it previously deployed or within current template. This differs from
the previous function as the ARM function will return a full object, from which attributes
can be referenced via dot notation. --]
[#function formatAzureResourceReference
    resourceId
    resourceType=""
    serviceType=""
    parentNames=[]
    attributes... 
    ]

    [#if ! resourceType?has_content]
        [#local resourceType = getResourceType(resourceId)]
    [/#if]

    [#if serviceType?has_content]
        [#local resourceProfile = getAzureResourceProfile(resourceType, serviceType)]
    [#else]
        [#local resourceProfile = getAzureResourceProfile(resourceType)]
    [/#if]

    [#-- Type/ApiVersion are Mandatory for all Azure Resources, so validate they exist. --]
    [#if ! (resourceProfile["type"]?has_content || resourceProfile["apiVersion"]?has_content || resourceProfile["conditions"]?has_content)]
        [@fatal
            message="Azure Resource Profile is incomplete. Requires 'type', 'apiVersion' and 'conditions' attributes for all resources."
            context=resourceProfile
        /]
    [/#if]

    [#local apiVersion = resourceProfile.apiVersion]
    [#local typeFull = resourceProfile.type]
    [#local conditions = resourceProfile.conditions]

    [#-- Resource Profile Conditions handling --]
    [#if conditions?size gt 0]
        [#list conditions as condition]
            [#switch condition]
                [#case "name_to_lower"]
                    [#local resourceId = resourceId?lower_case]
                    [#break]
                [#case "parent_to_lower"]
                    [#local parentNamesLower = []]
                    [#list parentNames as parent]
                        [#local parentNamesLower += [parent?lower_case] ]
                    [/#list]
                    [#local parentNames = parentNamesLower]
                    [#break]
                [#default]
                    [@fatal
                        message="Azure Resource Profile Condition does not exist."
                        context=condition
                    /]
                    [#break]
            [/#switch]
        [/#list]
    [/#if]

    [#local azureResourceIdentifier = formatAzureResourceIdReference(resourceId, resourceType)]
    [#local segmentedName = formatAzureResourceName(resourceId, parentNames)]

    [#if attributes?has_content && isPartOfCurrentDeploymentUnit(resourceId)]
        [#-- Listed in current deployment /w attr, use shorthand reference() call --]
        [#-- Example: "[reference(resourceId, 'Full').properties.attribute]"  --]
        [#return
            "[reference('" + segmentedName + "', 'Full')." + attributes?join(".") + "]"
        ]
    [#elseif attributes?has_content]
        [#-- In another deployment unit /w attr, use long form reference() call --]
        [#-- Example: "[reference(typeFull/resourceId, "2019-09-09", 'Full').properties.attribute]"  --]
        [#return
            "[reference(resourceId('" + azureResourceIdentifier + "'), " + apiVersion + ", 'Full')." + attributes?join(".") + "]"
        ]
    [#elseif isPartOfCurrentDeploymentUnit(resourceId)!false]
        [#-- Listed in current deployment w/o attr, use shorthand reference() call --]
        [#-- Example: "[reference(resourceId, 'Full')]"  --]
        [#return 
            "[reference(concat('" + typeFull + "/', '" + segmentedName + "'), '" + apiVersion + "', 'Full')]"
        ]
    [#else]
        [#-- In another deployment unit w/o attr, use long form reference() call --]
        [#-- Example: "[reference(resourceId(resourceType, resourceName), '2018-07-01', 'Full)]" --]
        [#return
            "[reference(resourceId('" + azureResourceIdentifier +  + "'), " + apiVersion + ", 'Full')]"
        ]
    [/#if]
[/#function]

[#function getAzureResourceProfile resourceType serviceType=""]

    [#local profileObj = {}]

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

[#function getReference resourceId attributeType="" inRegion=""]
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
                    formatAzureResourceReference(resourceId, resourceType, "", [], "")
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
            formatAzureResourceReference(resourceId, "", "", [], "")
        ]
    [/#if]
    [#return
        getExistingReference(
            resourceId,
            attributeType,
            inRegion)
    ]
[/#function]

[#-------------------------------------------------------
-- Internal support functions for resource processing --
---------------------------------------------------------]

[#macro internalMergeResourceProfiles service resource profile]
    [#if profile?has_content ]
        [#assign azureResourceProfiles = 
            mergeObjects(
                azureResourceProfiles,
                { service : { resource : getCompositeObject(
                    azureResourceProfilesConfiguration.Attributes,
                    profile
                )}} 
            )
        ]
    [/#if]
[/#macro]