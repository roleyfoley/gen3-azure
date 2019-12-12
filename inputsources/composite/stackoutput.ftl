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

[#macro azure_input_composite_stackoutput_seed]

  [#local stackOutputs = []]

  [#-- ARM Stack Output Processing --]
  [#list commandLineOptions.Composites.StackOutputs as stackOutputFile]

    [#local level = ((stackOutputFile["FileName"])?split('-'))[0]]
    [#list (stackOutputFile["Content"]![]) as rawStackOutput]
      [#if (rawStackOutput["properties"]["outputs"]!{})?has_content]

        [#local stackOutput = {
          "Level" : level
        }]

        [#list rawStackOutput["properties"]["outputs"] as outputId, outputValue]   
          [#local stackOutput += {
            outputId : outputValue.value
          }]
        [/#list]

        [#local stackOutputs += [ stackOutput ]]

      [/#if]
    [/#list]
  [/#list]

  [@addStackOutputs stackOutputs /]

[/#macro]