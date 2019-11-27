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

    [#-- 1. Vnet --]
    [@createVNet
      id=vnetId
      name=vnetName
      location=regionId
      addressSpacePrefixes=[vnetCIDR]
    /]

    [#-- 2. NetworkSecurityGroup --]
    [#local networkSecurityGroupId = resources["networkSecurityGroup"].Id]
    [#local networkSecurityGroupName = resources["networkSecurityGroup"].Name]

    [@createNetworkSecurityGroup
      id=networkSecurityGroupId
      name=networkSecurityGroupName
      location=regionId
    /]

    [#-- 3. Subnets for every tier --]
    [#if (resources["subnets"]!{})?has_content]

      [#local subnetResources = resources["subnets"]]
      [#list subnetResources as tierId,subnets]

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
        
        [#local routeTableLink = getLinkTarget(occurrence, networkLink + { "RouteTable" : routeTableId }, false)]
        [#local networkACLLink = getLinkTarget(occurrence, networkLink + { "NetworkACL" : networkACLId }, false)]
        [#local routeTableResource = routeTableLink.State.Resources["routeTable"]!{}]
  
        [#local subnet = subnets.subnet]
        [#local subnetIndex = subnets?index]
        [#local subnetName = formatAzureResourceName(
          subnet.Name,
          getResourceType(subnet.Id),
          vnetName)]
        
        [#-- Determine dependencies --]
        [#local dependencies = [
            getReference(vnetId, vnetName),
            getReference(networkSecurityGroupId, networkSecurityGroupName)
        ]]

        [#if subnetIndex > 0]
          [#local previousSubnet = resources["subnets"]?values[subnetIndex - 1].subnet]
          [#local dependencies += [
            getReference(
              previousSubnet.Id,
              formatAzureResourceName(
                previousSubnet.Name,
                AZURE_SUBNET_RESOURCE_TYPE,
                vnetName
              )
            )
          ]]
        [/#if]

        [#if routeTableResource?has_content]
          [#local routeTableId = routeTableResource.Id]
          [#local routeTableName = routeTableResource.Name] 
          [#local dependencies += [getReference(routeTableId, routeTableName)]]

          [@createSubnet
            id=subnet.Id
            name=subnetName
            vnetName=vnetName
            addressPrefix=subnet.Address
            networkSecurityGroup={ "id" : getReference(networkSecurityGroupId, networkSecurityGroupName) }
            routeTable= { "id" : getReference(routeTableId, routeTableName) }     
            dependsOn=dependencies
          /]
        [#else]
          [@createSubnet
            id=subnet.Id
            name=subnetName
            vnetName=vnetName
            addressPrefix=subnet.Address
            networkSecurityGroup={ "id" : getReference(networkSecurityGroupId, networkSecurityGroupName) } 
            dependsOn=dependencies
          /]
        [/#if]

        [#local networkACLConfiguration = networkACLLink.Configuration.Solution]

        [#list networkACLConfiguration.Rules as ruleId, ruleConfig]

          [#-- 
            Rules are Subnet-specific.
            Where an IPAddressGroup is found to be _localnet, use the subnet CIDR instead.
          --]
          [#if ruleConfig.Source.IPAddressGroups?seq_contains("_localnet")]
            [#local direction = "Outbound"]
            [#local sourceAddressPrefix = subnet.Address]
          [#else]
            [#local direction = "Inbound"]
            [#local sourceAddressPrefix = getGroupCIDRs(
              ruleConfig.Source.IPAddressGroups,
              true,
              occurrence)[0]]
          [/#if]

          [#if ruleConfig.Destination.IPAddressGroups?seq_contains("_localnet")]
            [#local destinationAddressPrefix = subnet.Address]
          [#else]
            [#local destinationAddressPrefix = getGroupCIDRs(
              ruleConfig.Destination.IPAddressGroups,
              true,
              occurrence)[0]]
          [/#if]

          [@createNetworkSecurityGroupSecurityRule
            id=formatDependentSecurityRuleId(subnet.Id, ruleId)
            name=formatAzureResourceName(
              formatName(tierId,ruleId),
              getResourceType(formatDependentSecurityRuleId(vnetId, formatName(tierId,ruleId))),
              networkSecurityGroupName)
            nsgName=networkSecurityGroupName
            description=description
            destinationPortProfileName=ruleConfig.Destination.Port
            sourceAddressPrefix=sourceAddressPrefix
            destinationAddressPrefix=destinationAddressPrefix
            access=ruleConfig.Action
            priority=(ruleConfig.Priority + tierId?index + ruleId?index)
            direction=direction
            dependsOn=
              [
                getReference(networkSecurityGroupId, networkSecurityGroupName)
              ]
          /]

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
      [#if core.Type == NETWORK_ROUTE_TABLE_COMPONENT_TYPE &&
        core.SubComponent.Name != "default"]

        [#local routeTable = resources["routeTable"]]

        [@createRouteTable
          id=routeTable.Id
          name=routeTable.Name
          location=regionId
        /]

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
      [#local flowLogNSGName = flowLogResources["networkWatcherFlowlog"].Name]

      [#local flowLogStorageId = getReference(
        formatResourceId(
          AZURE_STORAGEACCOUNT_RESOURCE_TYPE,
          core.Id
        )
      )]

      [@createNetworkWatcherFlowLog
        id=flowLogNSGId
        name=flowLogNSGName
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
            getReference(flowLogStorageId)
          ]
      /]
    [/#if]
  [/#if]
[/#macro]