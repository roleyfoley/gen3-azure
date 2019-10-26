[#ftl]

[#macro azure_s3_arm_solution occurrence]

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

    [#local accountName = resources["storageAccount"].Name]
    [#local blobName = resources["blobService"].Name]
    [#local containerName = resources["container"].Name]

    [#-- Process Resource Naming Conditions --]
    [#local accountNameConfig = processResourceNameConditions(accountName, getResourceType(accountId))]
    [#local blobNameConfig = processResourceNameConditions(blobName, getResourceType(blobId), accountNameConfig.fullName)]
    [#local containerNameConfig = processResourceNameConditions(containerName, getResourceType(containerId), accountNameConfig.fullName, blobNameConfig.fullName)]

    [#local storageProfile = getStorage(occurrence, "storageAccount")]

    [#-- Baseline component lookup 
    [#local baselineLinks = getBaselineLinks(occurrence, [ "CDNOriginKey" ])]
    [#local baselineComponentIds = getBaselineComponentIds(baselineLinks)]
    --]

    [#-- Add NetworkACL Configuration --]
    [#local virtualNetworkRulesConfiguration = []]
    [#list solution.PublicAccess?values as publicAccessConfiguration]

        [#local storageCIDRs = getGroupCIDRs(publicAccessConfiguration.IPAddressGroups)]

        [#list publicAccessConfiguration.Paths as publicPrefix]
            [#if publicAccessConfiguration.Enabled ]

                [#switch publicAccessConfiguration.Permissions ]
                    [#case "ro" ]
                        [#-- TODO - add RO config --]
                        [#break]
                    [#case "wo" ]
                        [#-- TODO - add WO config --]
                        [#break]
                    [#case "rw" ]
                        [#-- TODO - add RW config --]
                        [#break]
                [/#switch]
            [/#if]
        [/#list]
    [/#list]


    [#local ipRulesConfiguration = []]
    [#list storageCIDRs as cidr]
        [#local ipRulesConfiguration += asArray(getStorageNetworkAclsIpRules(cidr, "Allow"))]
    [/#list]


    [#local ipRulesConfiguration = []]
    [#local networkAclsConfiguration = getStorageNetworkAcls("Deny", ipRulesConfiguration, virtualNetworkRulesConfiguration, "None")]
    
    [#-- Retrieve Certificate Information --]
    [#if solution.Certificate?has_content]
        [#local certificateObject = getCertificateObject(solution.Certificate, segmentQualifiers, sourcePortId, sourcePortName) ]
        [#local primaryDomainObject = getCertificatePrimaryDomain(certificateObject) ]
        [#local fqdn = formatDomainName(hostName, primaryDomainObject)]
    [#else]
        [#local fqdn = ""]
    [/#if]
    
    [#if deploymentSubsetRequired("s3", true)]

        [#-- TODO(rossmurr4y): Impliment tags. Currently the shared function getOccurrenceCoreTags
        in gen3\engine\common.ftl just formats a call to the function getCfTemplateCoreTags, which is aws
        provider specific. --]
        [@createStorageAccount
            id=accountId
            name=accountNameConfig.fullName
            kind=storageProfile.Type
            sku=getStorageSku(storageProfile.Tier, storageProfile.Replication)
            location=regionId
            customDomain=fqdn?has_content?then(
                getStorageCustomDomain(fqdn),
                {})
            networkAcls=networkAclsConfiguration
            accessTier=(storageProfile.AccessTier!{})
            azureFilesIdentityBasedAuthentication=
                (solution.Access.DirectoryService)?has_content?then(
                    getStorageAzureFilesIdentityBasedAuthentication(solution.Access.DirectoryService),
                    {}
                )
            isHnsEnabled=(storageProfile.HnsEnabled!false)
        /]

        [@createBlobService 
            id=blobId
            name=blobNameConfig.fullName
            accountName=accountNameConfig.fullName
            CORSBehaviours=solution.CORSBehaviours
            deleteRetentionPolicy=
                (solution.Lifecycle.BlobRetentionDays)?has_content?then(
                    getStorageBlobServiceDeleteRetentionPolicy(solution.Lifecycle.BlobRetentionDays),
                    {}
                )
            automaticSnapshotPolicyEnabled=(solution.Lifecycle.BlobAutoSnapshots!false)
            resources=[]
            dependsOn=
                [
                    formatAzureResourceIdReference(accountId, accountNameConfig.fullName)
                ]
        /]

        [@createBlobServiceContainer 
            id=containerId
            name=containerNameConfig.fullName
            accountName=accountNameConfig.fullName
            blobName=blobName
            publicAccess=solution.PublicAccess.Enabled
            dependsOn=
                [
                    formatAzureResourceIdReference(accountId, accountNameConfig.fullName),
                    formatAzureResourceIdReference(blobId, blobNameConfig.fullName, "", "", [accountNameConfig.fullName, blobNameConfig.fullName])
                ]      
        /]

    [/#if]

[/#macro]