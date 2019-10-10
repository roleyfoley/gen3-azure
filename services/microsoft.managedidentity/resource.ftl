[#ftl]

[#assign azureResourceProfiles +=
    {
        AZURE_IAM_SERVICE : {
            AZURE_USER_ASSIGNED_IDENTITY_RESOURCE_TYPE : {
                "apiVersion" : "2018-11-30",
                "type" : "Microsoft.ManagedIdentity/userAssignedIdentities"
            }
        }
    }
]

[#assign IDENTITY_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "Attribute" : "id"
        }
    }
]

[#assign outputMappings +=
    {
        AZURE_IAM_IDENTITY_RESOURCE_TYPE : IDENTITY_OUTPUT_MAPPINGS
    }
]

[#macro createUserAssignedIdentity
    name
    location=""
    dependsOn=[]
    tags={}]

    [@armResource
        name=name
        profile=AZURE_USER_ASSIGNED_IDENTITY_RESOURCE_TYPE
        location=location
        dependsOn=dependsOn
        properties={}
        tags=tags
        outputs=IDENTITY_OUTPUT_MAPPINGS
    /]
[#/macro]
