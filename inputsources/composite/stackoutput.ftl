[#ftl]

[#-- Get stack output --]
[#function azure_input_composite_stackoutput_filter outputFilter]
  [#return 
    {
      "Subscription" : (outputFilter.Account)!accountObject.AzureId,
      "Region" : outputFilter.Region,
      "DeploymentUnit" : outputFilter.DeploymentUnit
    }
  ]
[/#function]

[#macro azure_input_composite_stackoutput_seed id="" deploymentUnit="" level="" region="" account=""]

  [#local stackOutputs = []]

  [#-- ARM Stack Output Processing --]
  [#list commandLineOptions.Composites.StackOutputs as stackOutputFile]

    [#local level = ((stackOutputFile["FileName"])?split('-'))[0]]

    [#list (stackOutputFile["Content"]![]) as rawStackOutput]
      [#if (rawStackOutput["properties"]!{})?has_content]
        [#list rawStackOutput["properties"] as propertyId, propertyValue]
          [#if propertyId == "outputs"]

            [#local stackOutput = {}]

            [#list propertyValue as outputId, outputValue]

              [#switch outputId]
                [#case "deploymentUnit"]
                  [#local stackOutput += { "DeploymentUnit" : outputValue["value"] }]
                  [#break]
                [#case "region"]
                  [#local stackOutput += { "Region" : outputValue["value"] }]
                  [#break]
                [#case "subscription"]
                  [#-- convert Azure languague "subscription to COT language "Account" --]
                  [#local stackOutput += { "Account" : outputValue["value"] }]
                  [#break]
                [#default]
                  [#local stackOutput += { outputId : outputValue["value"] }]
                  [#break]
              [/#switch]

            [/#list]

          [/#if]

          [#if stackOutput?has_content]
            [#local stackOutputs += [mergeObjects( { "Level" : level} , stackOutput)]]
          [/#if]
        [/#list]
      [/#if]
    [/#list]
  [/#list]

  [@addStackOutputs stackOutputs /]

[/#macro]