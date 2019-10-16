[#ftl]

[#macro azure_s3_arm_solution occurrence]
    [@debug message="Entering" context=occurrence enabled=false /]

    [#if deploymentSubsetRequired("genplan", false)]
        [@addDefaultGenerationPlan subsets="template" /]
        [#return]
    [/#if]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]
    [#local links = getLinkTargets(occurrence )]

    [#local accountId = resources["storageAccount"].Id]
    [#local blobId = resources["blobService"].Id]
    [#local containerId = resources["container"].Id]

    [#local storageProfile = getStorage(occurrence, "storageAccount")]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "CDNOriginKey" ])]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]

   [#local dependencies = [] ]

    [#-- Add NetworkACL Configuration --]
    [#local virtualNetworkRulesConfiguration = []]
    [#local storageCIDRs = getGroupCIDRs(solution.IPAddressGroups)]

    [#list solution.IPAddressGroups as subnet]
      [#local virtualNetworkRulesConfiguration += getStorageNetworkAclsVirtualNetworkRules(
            id=(getExistingReference(formatResourceId(AZURE_NETWORK_RESOURCE_TYPE, subnet)).id)
            action="Allow"
        )]
    [/#list]

    [#local ipRulesConfiguration = []]
    [#list storageCIDRs as cidr]
        [#local ipRulesConfiguration += getStorageNetworkAclsIpRules(
            value=cidr
            action="Allow"
        )]
    [/#list]
    [#local networkAclsConfiguration = getStorageNetworkAcls(
        defaultAction="Deny"
        ipRules=ipRulesConfiguration
        virtualNetworkRules=virtualNetworkRulesConfiguration
        bypass="None"
    )]

    [#-- Retrieve Certificate Information --]
    [#local certificateObject = getCertificateObject(solution.Certificate, segmentQualifiers, sourcePortId, sourcePortName) ]
    [#local primaryDomainObject = getCertificatePrimaryDomain(certificateObject) ]
    [#local fqdn = formatDomainName(hostName, primaryDomainObject)]

    [#if deploymentSubsetRequired("s3", true)]

        [#-- TODO(rossmurr4y): Impliment tags. Currently the shared function getOccurrenceCoreTags
        in gen3\engine\common.ftl just formats a call to the function getCfTemplateCoreTags, which is aws
        provider specific. --]
        [@createStorageAccount
            name=accountId
            kind=storageProfile.Type
            sku=getStorageSku(storageProfile.Tier, storageProfile.Replication)
            location=regionId
            customDomain=getStorageCustomDomain(fqdn)
            networkAcls=networkAclsConfiguration
            accessTier=(storageProfile.AccessTier!{})
            azureFilesIdentityBasedAuthentication=
                (solution.Access.DirectoryService)?has_content?then(
                    getStorageAzureFilesIdentityBasedAuthentication(solution.Access.DirectoryService),
                    {}
                )
            isHnsEnabled=(storageProfile.HnsEnabled!false)
            dependsOn=dependencies
        /]

        [@createBlobService 
            name=blobId
            CORSBehaviours=solution.CORSBehaviours
            deleteRetentionPolicy=
                (solution.Lifecycle.BlobRetentionDays)?has_content?then(
                    getStorageBlobServiceDeleteRetentionPolicy(solution.Lifecycle.BlobRetentionDays),
                    {}
                )
            automaticSnapshotPolicyEnabled=(solution.Lifecycle.BlobAutoSnapshots!false)
            resources=[]
            dependsOn=dependencies
        /]

        [@createBlobServiceContainer 
            name=containerId
            publicAccess=solution.Access.PublicAccess
            dependsOn=dependencies        
        /]

    [/#if]

[/#macro]