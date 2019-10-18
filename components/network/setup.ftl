[#ftl]

[#macro azure_network_arm_segment occurrence]
  [@debug message="Entering" context=occurrence enabled=false /]

  [#if deploymentSubsetRequired("genplan", false)]
      [@addDefaultGenerationPlan subsets="template" /]
      [#return]
  [/#if]

  [#local core = occurrence.Core]
  [#local solution = occurrence.Configuration.Solution]
  [#local resources = occurrence.State.Resources]

  [#local vnetId = resources["vnet"].Id]
  [#local vnetName = resources["vnet"].Name]
  [#local vnetCIDR = resources["vnet"].Address]

  [#if deploymentSubsetRequired(NETWORK_COMPONENT_TYPE, true)]

    [#-- 
      Resource Order 
        1. Vnet
        2. NetworkSecurityGroup
        3. Subnets for every tier & zone
        . Subcomponents - per subOccurrence
          4. Route Tables
          5. NSG Rules
        6. NetworkWatcher for FlowLogs
    --]

    [#-- 1. Vnet --]
    [@createVNet
      name=vnetName
      location=regionId
      addressSpacePrefixes=[vnetCIDR]
    /]

    [#-- 2. NetworkSecurityGroup + Default Rules --]
    [#local networkSecurityGroupId = resources["networkSecurityGroup"].Id]
    [#local networkSecurityGroupName = resources["networkSecurityGroup"].Name]

    [@createNetworkSecurityGroup
      name=networkSecurityGroupName
      location=regionId
    /]

    [#-- Deny inbound/outbound access by default. 
    To be overridden on applicable tiers by specific rules. --]

    [@createNetworkSecurityGroupSecurityRule
      name=formatName(networkSecurityGroupName, "DenyAllInbound")
      description="Deny All Inbound"
      protocol="*"
      sourcePortRange="*"
      destinationPortRange="*"
      sourceAddressPrefix="0.0.0.0/0"
      destinationAddressPrefix="0.0.0.0/0"
      access="Deny"
      priority="64999"
      direction="Inbound"
    /]

    [@createNetworkSecurityGroupSecurityRule
      name=formatName(networkSecurityGroupName, "DenyAllOutbound")
      description="Deny All Outbound"
      protocol="*"
      sourcePortRange="*"
      destinationPortRange="*"
      sourceAddressPrefix="0.0.0.0/0"
      destinationAddressPrefix="0.0.0.0/0"
      access="Deny"
      priority="64998"
      direction="Outbound"
    /]

    [#-- 3. Subnets for every tier & zone --]
    [#if (resources["subnets"]!{})?has_content]

      [#local subnetResources = resources["subnets"]]
      [#list subnetResources as tierId, zoneSubnets]

        [#local networkTier = getTier(tierId)]
        [#local tierNetwork = getTierNetwork(tierId)]
        
        [#local networkLink = tierNetwork.Link!{}]
        [#local routeTableId = tierNetwork.RouteTable!""]
        [#local networkACLId = tierNetwork.NetworkACL!""]

        [#if !networkLink?has_content || !routeTableId?has_content || !networkACLId?has_content]
          [@fatal
            message="Tier Network configuration incomplete"
            context=
              tierNetwork +
              {
                "Link" : networkLink,
                "RouteTable" : routeTableId,
                "NetworkACL" : networkACLId
              }
          /]
        [/#if]

        [#local routeTable = getLinkTarget(occurrence, networkLink + { "RouteTable" : routeTableId }, false)]
        [#local routeTableZones = routeTable.State.Resources["routeTables"]]

        [#local networkACL = getLinkTarget(occurrence, networkLink + { "NetworkACL" : networkACLId }, false)]
        [#local networkSecurityGroupZones = networkACL.State.Resources["networkSecurityGroups"]]

        [#list zones as zone]

          [#if zoneSubnets[zone.Id]?has_content]

            [#local zoneSubnetResources = zoneSubnets[zone.Id]]
            [#local subnetName = zoneSubnetResources["subnet"].Name]
            [#local subnetAddress = zoneSubnetResources["subnet"].Address]
            [#local routeTableId = (routeTableZones[zone.Id]["routeTable"]).Id]

            [@createSubnet
              name=subnetName
              addressPrefix=subnetAddress
              networkSecurityGroup={ "id" : networkSecurityGroupId }
              routeTable= { "id" : routeTableId }     
            /]

          [/#if]
        [/#list]
      [/#list]
    [/#if]

    [#-- Sub Components --]
    [#list occurrence.Occurrences![] as subOccurrence]

      [#local core = subOccurrence.Core]
      [#local solution = subOccurrence.Configuration.Solution]
      [#local resources = subOccurrence.State.Resources]

      [@debug message="Suboccurrence" context=subOccurrence enabled=false /]

      [#-- 4. RouteTables --]
      [#if core.Type == NETWORK_ROUTE_TABLE_COMPONENT_TYPE]

        [#local zoneRouteTables = resources["routeTables"]]

        [#list zones as zone]
          [#if zoneRouteTables[zone.Id]?has_content]
            [#local zoneRouteTableResources = zoneRouteTables[zone.Id]]
            [#local routeTableName = zoneRouteTableResources["routeTable"].Name]

            [@createRouteTable
              name=routeTableName
              location=zone.AzureId
            /]

          [/#if]
        [/#list]
      [/#if]

      [#-- 5. Network Security Group Rules --]
      [#if core.Type == NETWORK_ACL_COMPONENT_TYPE]
        
        [#local networkSecurityGroupRules = resources["rules"]]

        [#list networkSecurityGroupRules as id, rule]

          [#local ruleId = rule.Id]
          [#local ruleConfig = solution.Rules[id]]
          [#local ruleAction = ruleConfig.Action]

          [#if (ruleConfig.Source.IPAddressGroups)?seq_contains("_localnet")
            && (ruleConfig.Source.IPAddressGroups)?size == 1 ]

            [#-- Port wildcards will be defined within COT by "any". Azure uses "*" --]
            [#local direction = "Outbound" ]
            [#local destinationIPAddresses = getGroupCIDRs(ruleConfig.Destination.IPAddressGroups, true, occurrence)]
            [#local destinationPort = ports[ruleConfig.Destination.Port]]
            [#local sourceIpAddresses = getGroupCIDRs(ruleConfig.Destination.IPAddressGroups, true, occurrence)]
            [#local sourcePort = ports[ruleConfig.Source.Port]]

          [#elseif (ruleConfig.Destination.IPAddressGroups)?seq_contains("_localnet")
            && (ruleConfig.Source.IPAddressGroups)?size == 1 ]

            [#local direction = "Inbound" ]
            [#local destinationIPAddresses = getGroupCIDRs(ruleConfig.Source.IPAddressGroups, true, occurrence)]
            [#local destinationPort = ports[ruleConfig.Destination.Port]]
            [#local sourceIpAddresses = [ "0.0.0.0/0" ]]
            [#local sourcePort = ports[ruleConfig.Destination.Port]]

          [#else]
            [@fatal
                message="Invalid network ACL either source or destination must be configured as _local to define direction"
                context=port
            /]
          [/#if]

          [#-- NSG's are Stateful, so do not require rules for return traffic.
          
          Here we also make use of the ability to pass an array of source/destination
          addresses to the same rule. --]
          [#local ruleOrder = ruleConfig.Priority + ipAddress?index]
          [#local description = rule.Action?cap_first + destinationIPAddresses?cap_first + direction?cap_first]

          [@createNetworkSecurityGroupSecurityRule
            name=formatId(ruleId,direction,ruleOrder)
            description=description
            protocol="*"
            sourcePortRange=(sourcePort?replace("any","*"))
            destinationPortRange=(destinationPort?replace("any","*"))
            sourceAddressPrefixes=sourceIpAddresses
            destinationAddressPrefixes=destinationIPAddresses
            access=ruleAction
            priority=ruleOrder
            direction=direction
          /]
        [/#list]
      [/#if]
    [/#list]

    [#-- TODO(rossmurr4y): Flow Logs object is not currently supported, though exists when created
    via PowerShell. This is being developed by Microsoft and expected Jan 2020 - will need to revisit
    this implimentation at that time to ensure this object remains correct.
    https://feedback.azure.com/forums/217313-networking/suggestions/37713784-arm-template-support-for-nsg-flow-logs
    --]
    [#-- 6. NetworkWatcher : Flow Logs --]
    [#if (resources["flowlogs"]!{})?has_content]
      [#local flowLogResources = resources["flowlogs"]]
      [#local flowLogNSGId = flowLogResources["networkWatcherFlowlog"].Id]

      [#local flowLogStorageId = getReference(
        formatResourceId(
          AZURE_STORAGEACCOUNT_RESOURCE_TYPE,
          core.Id
        )
      )]

      [@createNetworkWatcherFlowLog
        name=flowLogNSGId
        targetResourceId=networkSecurityGroupId
        storageId=flowLogStorageId
        enabled=true
        trafficAnalyticsInterval="0"
        retentionPolicyEnabled=true
        retentionDays="7"
        formatType="JSON"
        formatVersion="0"
        dependsOn=
          [
            flowLogStorageId
          ]
      /]
    [/#if]
  [/#if]
[/#macro]