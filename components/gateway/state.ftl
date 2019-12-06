[#ftl]

[#macro azure_gateway_arm_state occurrence parent={} baseState={}]

  [#local core = occurrence.Core]
  [#local solution = occurrence.Configuration.Solution]
  [#local engine = solution.Engine ]
 
  [#if engine == "vpcendpoint"]
    [#-- 
      A private DNS Zone is required so we can force routing to the endpoint to remain within the
      VNet. If we don't then default routing may send traffic via the Internet.
    --]

    [#assign componentState =
      {
        "Resources" : {
          "dnsZone" : {
            "Id" : formatDependentResourceId(AZURE_PRIVATE_DNS_ZONE_RESOURCE_TYPE, core.Id),
            "Name" : AZURE_PRIVATE_DNS_ZONE_RESOURCE_TYPE,
            "Type" : AZURE_PRIVATE_DNS_ZONE_RESOURCE_TYPE
          },
          "vnetLink" : {
            "Id" : formatDependentResourceId(AZURE_PRIVATE_DNS_ZONE_VNET_LINK_RESOURCE_TYPE, core.Id),
            "Name" : formatName(AZURE_PRIVATE_DNS_ZONE_VNET_LINK_RESOURCE_TYPE, core.Id),
            "Type" : AZURE_PRIVATE_DNS_ZONE_VNET_LINK_RESOURCE_TYPE
          }
        },
        "Attributes" : {},
        "Roles" : {
          "Inbound" : {},
          "Outbound" : {}
        }
      }
    ]
      
  [#else]
    [@fatal
      message="Unknown Engine Type"
      context=occurrence.Configuration.Solution
    /]
  [/#if]

[/#macro]

[#macro azure_gatewaydestination_arm_state occurrence parent={} baseState={}]
  [#local core = occurrence.Core]
  [#local solution = occurrence.Configuration.Solution]

  [#local parentCore = parent.Core]
  [#local parentSolution = parent.Configuration.Solution]
  [#local engine = parentSolution.Engine]

  [#local resources = {}]

  [#if engine == "vpcendpoint"]

    [#local networkEndpoints = getNetworkEndpoints(solution.NetworkEndpointGroups, "a", region)]
      
    [#list networkEndpoints as id, networkEndpoint]

      [#switch networkEndpoint.Type]
        [#case "Interface"]
          [#break]
        [#case "PrivateLink"]
          [#-- TODO(rossmurr4y): impliment Azure Private Links --]
          [#break]
      [/#switch] 

    [/#list]

    [#assign componentState =
      {
        "Resources" : resources,
        "Attributes" : {
          "Engine" : parentSolution.Engine
        },
        "Roles" : {
          "Inbound" : {},
          "Outbound" : {}
        }
      }
    ]

  [#else]
    [@fatal
        message="Unknown Engine Type"
        context=occurrence.Configuration.Solution
    /]
  [/#if]

[/#macro]
