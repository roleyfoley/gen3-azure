[#ftl]
[#-- 
  Currently, all the typical Gateway resources have been created within the
  Network component due to Azure specific requirements. The Gateway will
  be utilised in a greater capacity when it comes to implimenting 
  privateEndpoint resources. Leaving large portions of the macro
  intact so as to outline the future structure.
--]
[#macro azure_gateway_arm_segment occurrence]

  [#if deploymentSubsetRequired("genplan", false)]
    [@addDefaultGenerationPlan subsets="template" /]
    [#return]
  [/#if]

  [#local gwCore = occurrence.Core]
  [#local gwSolution = occurrence.Configuration.Solution]
  [#local gwResources = occurrence.State.Resources]

  [#local occurrenceNetwork = getOccurrenceNetwork(occurrence) ]
  [#local networkLink = occurrenceNetwork.Link!{} ]

  [#if !networkLink?has_content]
    [@fatal
      message="Tier Network configuration incomplete"
      context=
        {
          "networkTier" : occurrenceNetwork,
          "Link" : networkLink
        }
    /]
  [/#if]

  [#local networkLinkTarget = getLinkTarget(occurrence, networkLink, false) ]
  [#if ! networkLinkTarget?has_content ]
    [@fatal message="Network could not be found" context=networkLink /]
  [/#if]
  [#local networkResources = networkLinkTarget.State.Resources]

  [#local sourceIPAddressGroups = gwSolution.SourceIPAddressGroups]
  [#local sourceCidrs = getGroupCIDRs(sourceIPAddressGroups, true, occurrence)]

  [#-- Private DNS Zone Creation --]
  [#--

    [#if deploymentSubsetRequired(NETWORK_GATEWAY_COMPONENT_TYPE, true)]

    [#local dnsZoneId = gwResources["dnsZone"].Id]
    [#local dnsZoneName = gwResources["dnsZone"].Name]
    [#local dnsZoneLinkId = gwResources["vnetLink"].Id]
    [#local dnsZoneLinkName = formatAzureResourceName(gwResources["vnetLink"].Name, getResourceType(dnsZoneLinkId), dnsZoneName)]

    [@createPrivateDnsZone 
      id=dnsZoneId
      name=dnsZoneName
    /]

    [@createPrivateDnsZoneVnetLink 
      id=dnsZoneLinkId
      name=dnsZoneLinkName
      vnetId=getReference(networkResources["vnet"].Id, networkResources["vnet"].Name)
      autoRegistrationEnabled=true
    /]

  [/#if]
  --]

  [#--
    Currently there are no "destination" requirements for an Azure Gateway component
    (they are created as a part of the Subnet resource in the Network component).
    The below structure is left available to ensure simple implimentation of Private
    Links at a later time.
  --]
  [#list occurrence.Occurrences![] as subOccurrence]

    [@debug message="Suboccurrence" context=subOccurrence enabled=false /]

    [#local core = subOccurrence.Core]
    [#local solution = subOccurrence.Configuration.Solution]
    [#local resources = subOccurrence.State.Resources]

    [#switch gwSolution.Engine]
      [#case "vpcendpoint"]
        [#local networkEndpoints = getNetworkEndpoints(solution.NetworkEndpointGroups, "a", region)]
        [#list networkEndpoints as id, networkEndpoint]
          [#if networkEndpoint.Type == "PrivateLink"]
            [#-- TODO(rossmurr4y): impliment Azure Private Links --]
          [/#if]
        [/#list]
        [#break]
      [#default]
        [@fatal
          message="Unsupported Gateway Engine."
          context=gwSolution.Engine
        /]
    [/#switch]

  [/#list]
[/#macro]