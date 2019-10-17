[#ftl]

[#-- Azure Resource Profiles --]
[#assign azureResourceProfiles = {}]

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
            [#local args += arg]
        [/#if]

        [#return
            "[resourceId(" + args?join(", ") + ")]"
        ]
    [/#list]
[/#function]

[#-- Formats a given resourceId into a Azure ARM lookup function for the current state of
a resource, be it previously deployed or within current template. This differs from
the previous function as the ARM function will return a full object, from which attributes
can be referenced via dot notation. --]
[#function formatAzureResourceReference(
    resourceId
    resourceType=""
    serviceType=""
    attributes...)]

    [#if ! resourceType?has_content]
        [#local resourceType = getResourceType(resourceId)]
    [/#if]

    [#if serviceType?has_content]
        [#local resourceProfile = getAzureResourceProfile(resourceType, serviceType)]
    [#else]
        [#local resourceProfile = getAzureResourceProfile(resourceType)]
    [/#if]

    [#local apiVersion = resourceProfile.apiVersion]
    [#local typeFull = resourceProfile.type]

    [#if attributes?has_content]
        [#-- Example: "[reference(typeFull/resourceId, "2019-09-09", 'Full').properties.attribute]"  --]
        [#return
            "[reference(" + typeFull + "/" + resourceId + ", " + apiVersion + ", 'Full')." + attributes?join(".") + "]"
        ]
    [#/else]
        [#-- Example: "[reference(typeFull/resourceId, "2019-09-09", 'Full')]"  --]
        [#return
             "[reference(" + typeFull + "/" + resourceId + ", " + apiVersion + ", 'Full')]"
        ]
    [/#if]
[/#function]

[#function getAzureResourceProfile(resourceType, serviceType="")]

    [@debug message="azureResourceProfiles" context=azureResourceProfiles enabled=false /]
    
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
            [#list resources as resource]
                [#if resource == resourceType]
                    [#local profileObj = azureResourceProfiles[service][resource]]
                [/#if]
            [/#list]
        [/#list]
    [/#if]

    [#if profile?has_content]
        [#return profileObj]
    [#else]
        [#return
            {
                "Mapping" : "COTFatal: ResourceProfile not found.",
                "ResourceId" : resourceId,
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
                    formatAzureResourceReference(
                        resourceId,
                        resourceType         
                    )
                ]
            [/#if]
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
            formatAzureResourceReference(
                resourceId=resourceId           
            )
        ]
    [/#if]
    [#return
        getExistingReference(
            resourceId,
            attributeType,
            inRegion)
    ]
[/#function]