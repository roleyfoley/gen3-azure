[#ftl]

[@addResourceProfile
    service=AZURE_STORAGE_SERVICE
    resource=AZURE_STORAGEACCOUNT_RESOURCE_TYPE
    profile=
        {
            "apiVersion" : "2019-04-01",
            "type" : "Microsoft.Storage/storageAccounts",
            "conditions" : [ "alphanumeric_only", "name_to_lower" ]
        }
/]

[@addResourceProfile
    service=AZURE_STORAGE_SERVICE
    resource=AZURE_BLOBSERVICE_RESOURCE_TYPE
    profile=
        {
            "apiVersion" : "2019-04-01",
            "type" : "Microsoft.Storage/storageAccounts/blobServices",
            "conditions" : [ "name_to_lower", "parent_to_lower" ]
        }
/]

[@addResourceProfile
    service=AZURE_STORAGE_SERVICE
    resource=AZURE_BLOBSERVICE_CONTAINER_RESOURCE_TYPE
    profile=
        {
            "apiVersion" : "2019-04-01",
            "type" : "Microsoft.Storage/storageAccounts/blobServices/containers",
            "conditions" : [ "name_to_lower", "parent_to_lower" ]
        }
/]

[#assign STORAGE_ACCOUNT_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "UseRef" : true
        },
        NAME_ATTRIBUTE_TYPE : {
            "Property" : "name"
        },
        URL_ATTRIBUTE_TYPE : {
            "Property" : "properties.primaryEndpoints.web"
        },
        REGION_ATTRIBUTE_TYPE : {
            "Property" : "properties.location"
        }
    }
]

[#assign STORAGE_BLOB_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "Property" : "id"
        },
        NAME_ATTRIBUTE_TYPE : {
            "Property" : "name"
        }
    }
]

[#assign STORAGE_BLOB_CONTAINER_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "Property" : "id"
        },
        NAME_ATTRIBUTE_TYPE : {
            "Property" : "name"
        }
    }
]
[#assign storageMappings = 
    {
        AZURE_BLOBSERVICE_CONTAINER_RESOURCE_TYPE : STORAGE_BLOB_CONTAINER_OUTPUT_MAPPINGS,
        AZURE_BLOBSERVICE_RESOURCE_TYPE : STORAGE_BLOB_OUTPUT_MAPPINGS,
        AZURE_STORAGEACCOUNT_RESOURCE_TYPE : STORAGE_ACCOUNT_OUTPUT_MAPPINGS
    }
]

[#list storageMappings as type, mappings]
    [@addOutputMapping 
        provider=AZURE_PROVIDER
        resourceType=type
        mappings=mappings
    /]
[/#list]

[#function getStorageSku tier replication reasonCodes...]
    [#return
        {
            "name" : [tier, replication]?join("_")
        } +
        attributeIfContent("restrictions", reasonCodes)
    ]
[/#function]

[#function getStorageCustomDomain name useSubDomainName=true]
    [#return
        {
            "name": name,
            "useSubDomainName": useSubDomainName
        }
    ]
[/#function]

[#function getStorageNetworkAcls 
    defaultAction 
    ipRules=[]
    virtualNetworkRules=[]
    bypass=""]

    [#return
        {
            "defaultAction": defaultAction
        } +
        attributeIfContent("ipRules", ipRules) +
        attributeIfContent("virtualNetworkRules", virtualNetworkRules) +
        attributeIfContent("bypass", bypass)
    ]
[/#function]

[#function getStorageNetworkAclsVirtualNetworkRules id action="" state=""]
   [#return
        {
            "id" : id
        } +
        attributeIfContent("action", action) +
        attributeIfContent("state", state)
    ]
[/#function]

[#function getStorageNetworkAclsIpRules value action=""]
    [#return
        {
            "value" : value
        } + 
        attributeIfContent("action", action)
    ]
[/#function]

[#function getStorageAzureFilesIdentityBasedAuthentication service]
    [#return { "directoryServiceOptions" : service } ]
[/#function]

[#-- all attributes are mandatory on CorsRules object --]
[#function getStorageBlobServiceCorsRules
    allowedOrigins
    allowedMethods
    maxAgeInSeconds
    exposedHeaders
    allowedHeaders
    ]

    [#return
        {
            "allowedOrigins": allowedOrigins,
            "allowedMethods": allowedMethods,
            "maxAgeInSeconds": maxAgeInSeconds,
            "exposedHeaders": exposedHeaders,
            "allowedHeaders": allowedHeaders
        }
    ]
[/#function]

[#function getStorageBlobServiceDeleteRetentionPolicy days]
    [#return { "enabled": true, "days": days }]
[/#function]

[#macro createStorageAccount
    id
    name
    sku
    location
    kind
    tags={}
    customDomain={}
    networkAcls={}
    accessTier=""
    azureFilesIdentityBasedAuthentication={}
    supportHttpsTrafficOnly=true
    isHnsEnabled=false
    dependsOn=[]]

    [@armResource
        id=id
        name=name
        profile=AZURE_STORAGEACCOUNT_RESOURCE_TYPE
        kind=kind
        location=location
        tags=tags
        identity={ "type" : "SystemAssigned" }
        sku=sku
        outputs=STORAGE_ACCOUNT_OUTPUT_MAPPINGS
        properties=
            {
                "supportsHttpsTrafficOnly" : supportHttpsTrafficOnly
            } +
            attributeIfContent("customDomain", customDomain) +
            attributeIfContent("networkAcls", networkAcls) +
            attributeIfContent("accessTier", accessTier) +
            attributeIfContent("azureFilesIdentityBasedAuthentication", azureFilesIdentityBasedAuthentication) +
            attributeIfTrue("isHnsEnabled", isHnsEnabled, true)
        dependsOn=dependsOn
    /]
[/#macro]

[#macro createBlobService
    id
    name
    accountName
    CORSBehaviours=[]
    deleteRetentionPolicy={}
    automaticSnapshotPolicyEnabled=false
    resources=[]
    dependsOn=[]]

    [#assign CORSRules = []]
    [#list CORSBehaviours as behaviour]
        [#assign CORSBehaviour = CORSProfiles[behaviour]]
        [#if CORSBehaviour?has_content]
            [#assign CORSRules += [
                {
                    "allowedHeaders": CORSBehaviour.AllowedHeaders,
                    "allowedMethods": CORSBehaviour.AllowedMethods,
                    "allowedOrigins": CORSBehaviour.AllowedOrigins,
                    "exposedHeaders": CORSBehaviour.ExposedHeaders,
                    "maxAgeInSeconds": (CORSBehaviour.MaxAge)?c
                }
            ]
            
            ]
        [/#if]
    [/#list]

    [@armResource
        id=id
        name=name
        parentNames=[accountName]
        profile=AZURE_BLOBSERVICE_RESOURCE_TYPE
        dependsOn=dependsOn
        resources=resources
        outputs=STORAGE_BLOB_OUTPUT_MAPPINGS
        properties=
            {
                "defaultServiceVersion": "2019-04-01"
            } + 
            attributeIfContent("CORSRules", CORSRules) +
            attributeIfContent("deleteRetentionPolicy", deleteRetentionPolicy) + 
            attributeIfTrue("automaticSnapshotPolicyEnabled", automaticSnapshotPolicyEnabled, automaticSnapshotPolicyEnabled)
    /]
[/#macro]

[#macro createBlobServiceContainer
    id
    name
    accountName
    blobName
    publicAccess=""
    metadata={}
    resources=[]
    dependsOn=[]]

    [@armResource
        id=id
        name=name
        parentNames=[accountName, blobName]
        profile=AZURE_BLOBSERVICE_CONTAINER_RESOURCE_TYPE
        resources=resources
        dependsOn=dependsOn
        outputs=STORAGE_BLOB_CONTAINER_OUTPUT_MAPPINGS
        properties=
            {} +
            attributeIfContent("publicAccess", publicAccess) +
            attributeIfContent("metadata", metadata)
    /]
[/#macro]