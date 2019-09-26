[#ftl]

[#-- Get stack output --]
[#function getStackOutputObject id deploymentUnit="" region="" account=(accountObject.AZUREId)!""]
    [#list stackOutputsList as stackOutputs]
        [#local outputId = stackOutputs[id]?has_content?then(
                id,
                formatId(id, stackOutputs.Region?replace("-", "X"))
            )
        ]

        [#if
            ((!account?has_content)||(account == stackOutputs.Account)) &&
            ((!region?has_content)||(region == stackOutputs.Region)) &&
            ((!deploymentUnit?has_content)||(deploymentUnit == stackOutputs.DeploymentUnit)) &&
            (stackOutputs[outputId]?has_content)
        ]
            [#return
                {
                    "Account" : stackOutputs.Account,
                    "Region" : stackOutputs.Region,
                    "Level" : stackOutputs.Level,
                    "DeploymentUnit" : stackOutputs.DeploymentUnit,
                    "Id" : id,
                    "Value" : stackOutputs[outputId]
                }
            ]
        [/#if]
    [/#list]
    [#return {}]
[/#function]

[#function getStackOutput id deploymentUnit="" region="" account=(accountObject.AZUREId)!""]
    [#local result =
        getStackOutputObject(
            id,
            deploymentUnit,
            region,
            account
        )
    ]
    [#return
        result?has_content?then(
            result.Value,
            ""
        )
    ]
[/#function]

[#function getExistingReference resourceId attributeType="" inRegion="" inDeploymentUnit="" inAccount=(accountObject.AZUREId)!""]
    [#return getStackOutput(formatAttributeId(resourceId, attributeType), inDeploymentUnit, inRegion, inAccount) ]
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
            [#local resourceType = getResourceType(resourceId) ]
            [#if outputMappings[resourceType]?? ]
                [#local mapping = outputMappings[getResourceType(resourceId)][attributeType] ]
                [#if (mapping.Attribute)?has_content]
                    [#return
                        {
                            "Fn::GetAtt" : [resourceId, mapping.Attribute]
                        }
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
            {
                "Ref" : resourceId
            }
        ]
    [/#if]
    [#return
        getExistingReference(
            resourceId,
            attributeType,
            inRegion)
    ]
[/#function]