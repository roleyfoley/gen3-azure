[#ftl]

[#macro azure_input_mock_stackoutput id="" deploymentUnit="" level="" region="" account=""]

  [#switch id?split("X")?last ]
    [#case NAME_ATTRIBUTE_TYPE]
      [#local value = "mockResourceName"]
      [#break]
    [#case URL_ATTRIBUTE_TYPE ]
      [#local value = "https://mock.local/" + id ]
      [#break]
    [#case IP_ADDRESS_ATTRIBUTE_TYPE ]
      [#local value = "123.123.123.123" ]
      [#break]
    [#case REGION_ATTRIBUTE_TYPE ]
      [#local value = "apmock1" ]
      [#break]
    [#default]
      [#--The default value will be an azure resource Id --]
      [#local value = "/subscriptions/12345678-abcd-efgh-ijkl-123456789012/resourceGroups/mockRG/providers/Microsoft.Mock/mockR/mock-resource-name"]
    [/#switch]

    [@addStackOutputs 
      [
        {
          "Subscription" : account,
          "Region" : region,
          "DeploymentUnit" : deploymentUnit,
          "ResourceGroup" : resourceGroup,
          id : value
        }
      ]
    /]

[/#macro]