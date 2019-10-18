[#ftl]

[#macro azure_network_arm_state occurrence parent={} baseState={}]
  
  [#local core = occurrence.Core]
  [#local solution = occurrence.Configuration.Solution]

  [#local vnetId = formatVirtualNetworkId(core.Id)]
  [#local vnetName = core.FullName]
  [#local networkSecurityGroupId = formatDependentNetworkSecurityGroupId(vnetId)]
  [#local nsgFlowlogId = formatDependentNetworkWatcherId(networkSecurityGroupId)]

  [#local nsgFlowLogEnabled = environmentObject.Operations.FlowLogs.Enabled!
    segmentObject.Operations.FlowLogs.Enabled!
    solution.Logging.EnableFlowLogs ]

  [#local networkCIDR = (network.CIDR)?has_content?then(
    network.CIDR.Address + "/" + network.CIDR.Mask,
    solution.Address.CIDR )]

  [#local networkAddress = networkCIDR?split("/")[0] ]
  [#local networkMask = (networkCIDR?split("/")[1])?number ]
  [#local baseAddress = networkAddress?split(".") ]

  [#local addressOffset = baseAddress[2]?number*256 + baseAddress[3]?number]
  [#local addressesPerTier = powersOf2[getPowerOf2(powersOf2[32 - networkMask]/(network.Tiers.Order?size))]]
  [#local addressesPerZone = powersOf2[getPowerOf2(addressesPerTier / (network.Zones.Order?size))]]
  [#local subnetMask = 32 - powersOf2?seq_index_of(addressesPerZone)]

  [#-- Define subnets --]
  [#local subnets = {}]
  [#list segmentObject.Network.Tiers.Order as tierId]
    [#local networkTier = getTier(tierId) ]

    [#-- Filter out to only valid tiers --]
    [#if ! (networkTier?has_content && networkTier.Network.Enabled &&
                networkTier.Network.Link.Tier == core.Tier.Id && networkTier.Network.Link.Component == core.Component.Id &&
                (networkTier.Network.Link.Version!core.Version.Id) == core.Version.Id && (networkTier.Network.Link.Instance!core.Instance.Id) == core.Instance.Id)]
        [#continue]
    [/#if]

    [#list zones as zone]
      [#local subnetId = formatDependentSubnetId(core.Id, networkTier.Id, zone.Id)]
      [#local subnetName = formatName(core.FullName, networkTier.Name, zone.Name)]
      [#local subnetAddress = addressOffset + (networkTier.Network.Index * addressesPerTier) + (zone.Index * addressesPerZone)]
      [#local subnetCIDR = baseAddress[0] + "." + baseAddress[1] + "." + (subnetAddress/256)?int + "." + subnetAddress%256 + "/" + subnetMask]
      [#local routeId = formatDependentRouteTableRouteId(subnetId)]

      [#local subnets =  mergeObjects( subnets, {
        networkTier.Id : {
          zone.Id : {
            "subnet" : {
              "Id" : subnetId,
              "Name" : subnetName,
              "Address" : subnetCIDR,
              "Type" : AZURE_SUBNET_RESOURCE_TYPE
            },
            "routeTableRoute" : {
              "Id" : routeId,
              "Type" : AZURE_ROUTE_TABLE_ROUTE_RESOURCE_TYPE
            }
          }
        }
      })]
    [/#list]
  [/#list]

  [#assign componentState=
    {
      "Resources" : {
        "vnet" : {
          "Id" : vnetId,
          "Name" : vnetName,
          "Address" : networkAddress + "/" + networkMask,
          "Type" : AZURE_VIRTUAL_NETWORK_RESOURCE_TYPE
        },
        "subnets" : subnets
      }
      nsgFlowLogEnabled?then(
        {
          "flowlogs" : {
            "networkWatcherFlowlog" : {
              "Id" : nsgFlowlogId,
              "Type" : AZURE_NETWORK_WATCHER_RESOURCE_TYPE
            }
          }
        }
      ),
      "Attributes" : {},
      "Roles" : {
        "Inbound" : {},
        "Outbound" : {}
      }
    }
  ]
[/#macro]

[#macro azure_networkroute_arm_state occurrence parent={} baseState={}]

  [#local core = occurrence.Core]
  [#local solution = occurrence.Configuration.Solution]

  [#local routeTableId = formatDependentRouteTableId(core.Id)]

  [#local routeTables = {}]
  [#list segmentObject.Network.Tiers.Order as tierId]
    
    [#-- Filter out to only valid tiers --]
    [#local networkTier = getTier(tierId) ]
    [#if ! (networkTier?has_content && networkTier.Network.Enabled)]
        [#continue]
    [/#if]

    [#list zones as zone]
      [#local zoneRouteTableId = formatId(routeTableId, zone.Id)]
      [#local zoneRouteTableName = formatName(routeTableId, zone.Id)]

      [#local routeTables = mergeObjects(routeTables, {
        zone.Id : {
          "routeTable" : {
            "Id" : zoneRouteTableId,
            "Name" : zoneRouteTableName,
            "Type" : AZURE_ROUTE_TABLE_RESOURCE_TYPE
          }
        }
      })]
    [/#list]
  [/#list]

  [#assign componentState =
    {
      "Resources" : {
        "routeTables" : routeTables
      },
      "Attributes" : {},
      "Roles" : {
          "Inbound" : {},
          "Outbound" : {}
      }
    }
  ]
[/#macro]

[#-- As a subcomponent, this NetworkACL is using a NetworkSecurityGroup
resource. It remains "networkacl" in name to ensure there is no clash
with any future networkSecurityGroup components. When referring to
the Resource alone, it will remain NetworkSecurityGroup for clarity
as Azure does not have NetworkACLs.--]
[#macro azure_networkacl_arm_state occurence parent={} baseState={}]

  [#local core = occurrence.Core]
  [#local solution = occurrence.Configuration.Solution]

  [#local vnetId = formatVirtualNetworkId(core.Id)]
  [#local networkSecurityGroupId = formatDependentNetworkSecurityGroupId(vnetId)]
  [#local nsgId = formatNetworkSecurityGroupId(core.Id)]
  [#local nsgName = formatName(core.Name)]

  [#list segmentObject.Network.Tiers.Order as tierId]
  
    [#-- Filter out to only valid tiers --]
    [#local networkTier = getTier(tierId) ]
    [#if ! (networkTier?has_content && networkTier.Network.Enabled)]
        [#continue]
    [/#if]

    [#list zones as zone]

      [#local networkSecurityGroupRules = {}]
      [#list solution.Rules as id, rule]
        [#local networkSecurityGroupRules += {
          rule.Id : {
            "Id" : formatDependentSecurityRuleId(networkSecurityGroupId, rule.Id),
            "Type" : AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_SECURITY_RULE_RESOURCE_TYPE
          }
        }]
      [/#list]

    [/#list]
  [/#list]

  [#assign componentState =
    {
      "Resources" : {
        "networkSecurityGroup" : {
          "Id" : nsgId,
          "Name" : nsgName,
          "Type" : AZURE_VIRTUAL_NETWORK_SECURITY_GROUP_RESOURCE_TYPE
        },
        "rules" : networkSecurityGroupRules
      },
      "Attributes" : {},
      "Roles" : {
        "Inbound" : {},
        "Outbound" : {}
      }
    }
  ]
[/#macro]