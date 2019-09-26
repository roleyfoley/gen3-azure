[#ftl]
[@addResourceGroupInformation
    type=S3_COMPONENT_TYPE
    attributes=
        [
            {
                "Names" : "Lifecycle",
                "Children" : [
                    {
                        "Names" : "BlobRetentionDays",
                        "Type" : NUMBER_TYPE,
                        "Default" : ""
                    },
                    {
                        "Names" : "BlobAutoSnapshots",
                        "Type" : BOOLEAN_TYPE,
                        "Default" : false
                    }
                ]
            },
            {
                "Names" : "Certificate",
                "Children" : certificateChildConfiguration                
            },
            {
                "Names" : "Access",
                "Children" : [
                    {
                        "Names" : "DirectoryService",
                        "Description" : "The directory service that is used for authentication. 'None' or 'AADDS'.",
                        "Type" : STRING_TYPE,
                        "Default" : ""
                    },
                    {
                        "Names" : "PublicAccess",
                        "Type" : STRING_TYPE,
                        "Values" : [ "Container", "Blob", "None" ],
                        "Default" : "None"
                    }
                ]
            },
            {
                "Names" : "CORSBehaviours",
                "Children" : [
                    {
                        "Names" : "AllowedOrigins",
                        "Type" : ARRAY_OF_STRING_TYPE,
                        "Default" : [ "" ]
                    },
                    {
                        "Names" : "AllowedMethods",
                        "Type" : ARRAY_OF_STRING_TYPE,
                        "Default" : [ "" ]
                    },
                    {
                        "Names" : "MaxAge",
                        "Type" : NUMBER_TYPE,
                        "Description" : "The max age, in seconds.",
                        "Default" : ""
                    },
                    {
                        "Names" : "ExposedHeaders",
                        "Type" : ARRAY_OF_STRING_TYPE,
                        "Default" : [ "" ]
                    },
                    {
                        "Names" : "AllowedHeaders",
                        "Type" : ARRAY_OF_STRING_TYPE,
                        "Default" : [ "" ]
                    }
                ]
            }
        ]
    provider=AZURE_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AZURE_STORAGE_SERVICE
        ]
/]