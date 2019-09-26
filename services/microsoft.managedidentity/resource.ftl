[#ftl]

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
        type="Microsoft.ManagedIdentity/userAssignedIdentities"
        apiVersion="2018-11-30"
        location=location
        dependsOn=dependsOn
        properties={}
        tags=tags
        outputs=IDENTITY_OUTPUT_MAPPINGS
    /]
[#/macro]
