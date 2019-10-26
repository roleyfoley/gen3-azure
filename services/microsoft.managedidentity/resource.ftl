[#ftl]

[@addResourceProfile
    service=AZURE_IAM_SERVICE
    resource=AZURE_USER_ASSIGNED_IDENTITY_RESOURCE_TYPE
    profile=
        {
            "apiVersion" : "2018-11-30",
            "type" : "Microsoft.ManagedIdentity/userAssignedIdentities"
        }
/]

[#assign IDENTITY_OUTPUT_MAPPINGS =
    {
        REFERENCE_ATTRIBUTE_TYPE : {
            "Attribute" : "id"
        }
    }
]

[@addOutputMapping 
    provider=AZURE_PROVIDER
    resourceType=AZURE_IAM_IDENTITY_RESOURCE_TYPE
    mappings=IDENTITY_OUTPUT_MAPPINGS
/]

[#macro createUserAssignedIdentity
    id
    name
    location=""
    dependsOn=[]
    tags={}]

    [@armResource
        id=id
        name=name
        profile=AZURE_USER_ASSIGNED_IDENTITY_RESOURCE_TYPE
        location=location
        dependsOn=dependsOn
        properties={}
        tags=tags
        outputs=IDENTITY_OUTPUT_MAPPINGS
    /]
[#/macro]
