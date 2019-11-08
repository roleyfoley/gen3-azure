[#ftl]
[@addResourceGroupInformation
    type=BASELINE_COMPONENT_TYPE
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
                    }
                ]
            }
        ]
    provider=AZURE_PROVIDER
    resourceGroup=DEFAULT_RESOURCE_GROUP
    services=
        [
            AZURE_BASELINE_PSEUDO_SERVICE,
            AZURE_KEYVAULT_SERVICE,
            AZURE_STORAGE_SERVICE
        ]
/]