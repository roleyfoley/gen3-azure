[#ftl]

[#macro azure_baseline_arm_segment occurrence]

    [#if deploymentSubsetRequired("genplan", false)]
      [@addDefaultGenerationPlan subsets=["prologue", "template", "epilogue"] /]
      [#return]
    [/#if]

    [#local core = occurrence.Core ]
    [#local solution = occurrence.Configuration.Solution ]
    [#local resources = occurrence.State.Resources ]
    [#local links = getLinkTargets(occurrence )]

    [#-- make sure we only have one occurence --]
    [#if  ! ( core.Tier.Id == "mgmt" &&
      core.Component.Id == "baseline" &&
      core.Version.Id == "" &&
      core.Instance.Id == "" ) ]

      [@fatal
        message="The baseline component can only be deployed once as an unversioned component"
        context=core
      /]
      [#return]
    [/#if]

    [#-- Segment Seed --]
    [#local segmentSeedId = resources["segmentSeed"].Id]
    [#local segmentSeedValue = resources["segmentSeed"].Value]
    [#if !(getExistingReference(segmentSeedId)?has_content)]

      [#if deploymentSubsetRequired("prologue", false)]
        [@addToDefaultBashScriptOutput
          content=
          [
            "case $\{STACK_OPERATION} in",
            "  create|update)"
          ] +
          pseudoArmStackOutputScript(
            "Seed Values",
            { segmentSeedId : segmentSeedValue },
            "seed"
          ) +
          [
            "       ;;",
            "       esac"
          ]
        /]
      [/#if]
    [/#if]

    [#-- Baseline component lookup --]
    [#local baselineLinks = getBaselineLinks(occurrence, [ "Encryption" ], false, false )]
    [#local baselineComponentIds = getBaselineComponentIds(
      baselineLinks,
      AZURE_CMK_KEY_PAIR_RESOURCE_TYPE,
      AZURE_SSH_PRIVATE_KEY_RESOURCE_TYPE,
      "")]
    [#local cmkKeyId = baselineComponentIds["Encryption"]]
    [@debug message={ "KeyId" : cmkKeyId } enabled=false /]

    [#-- Parent Component Resources --]
    [#local tenantId = formatAzureSubscriptionReference("tenantId")]
    [#local accountId = resources["storageAccount"].Id]
    [#local accountName = resources["storageAccount"].Name]
    [#local blobId = resources["blobService"].Id]
    [#local blobName = resources["blobService"].Name]
    [#local keyvaultId = resources["keyVault"].Id]
    [#local keyvaultName = resources["keyVault"].Name]
    [#local keyVaultAccessPolicy = resources["keyVaultAccessPolicy"].Id]

    [#-- Process Resource Naming Conditions --]
    [#local accountName = formatAzureResourceName(accountName, getResourceType(accountId))]
    [#local blobName = formatAzureResourceName(blobName, getResourceType(blobId), accountName)]
    
    [#local storageProfile = getStorage(occurrence, "storageAccount")]

    [#-- storageAccount : Retrieve Certificate Information --]
    [#if solution.Certificate?has_content]
      [#local certificateObject = getCertificateObject(solution.Certificate, segmentQualifiers, sourcePortId, sourcePortName) ]
      [#local primaryDomainObject = getCertificatePrimaryDomain(certificateObject) ]
      [#local fqdn = formatDomainName(hostName, primaryDomainObject)]
    [#else]
        [#local fqdn = ""]
    [/#if]

    [#-- 
      storageAccount + keyVault : Retrieve NetworkACL Configuration
      Component roles will grant more explicit access to Storage + KeyVault.
      For now we just want blanket "deny-all" networkAcls.
    --]
    [#-- networkAcls object is used for both Storage Account and KeyVault --]
    [#local networkAclsConfiguration = getNetworkAcls("Deny", [], [], "AzureServices")]

    [@createStorageAccount
      id=accountId
      name=accountName
      kind=storageProfile.Type
      sku=getStorageSku(storageProfile.Tier, storageProfile.Replication)
      location=regionId
      customDomain=getStorageCustomDomain(fqdn)
      networkAcls=networkAclsConfiguration
      accessTier=(storageProfile.AccessTier)!{}
      azureFilesIdentityBasedAuthentication=
        (solution.Access.DirectoryService)?has_content?then(
          getStorageAzureFilesIdentityBasedAuthentication(solution.Access.DirectoryService),
          {}
        )
      isHnsEnabled=(storageProfile.HnsEnabled)!false
    /]

    [@createBlobService
      id=blobId
      name=blobName
      accountName=accountName
      CORSBehaviours=solution.CORSBehaviours
      deleteRetentionPolicy=
        (solution.Lifecycle.BlobRetentionDays)?has_content?then(
          getStorageBlobServiceDeleteRetentionPolicy(solution.Lifecycle.BlobRetentionDays),
          {}
        )
      automaticSnapshotPolicyEnabled=(solution.Lifecycle.BlobAutoSnapshots)!false
      dependsOn=
        [
          getReference(accountId, accountName)
        ]
    /]

    [@createKeyVault
      id=keyvaultId
      name=keyvaultName
      location=regionId
      properties=
        getKeyVaultProperties(
          tenantId,
          getKeyVaultSku("A", "standard"),
          [],
          "",
          true,
          true,
          true,
          false,
          "default",
          true,
          networkAclsConfiguration
        )
    /]

    [#-- Subcomponents --]
    [#list occurrence.Occurrences![] as subOccurrence]

      [#local subCore = subOccurrence.Core]
      [#local subSolution = subOccurrence.Configuration.Solution]
      [#local subResources = subOccurrence.State.Resources]

      [#-- storage containers --]
      [#if subCore.Type == BASELINE_DATA_COMPONENT_TYPE]
        [#local containerId = subResources["container"].Id]
        [#local containerName = subResources["container"].Name]

        [#-- Process Resource Naming Conditions --]
        [#local containerName = formatAzureResourceName(containerName, getResourceType(containerId), blobName)]

        [#if (deploymentSubsetRequired(BASELINE_COMPONENT_TYPE, true))]

          [#if subSolution.Role == "appdata"]
            [#local publicAccess = "Container"]
          [#else]
            [#local publicAccess = "None"]
          [/#if]

          [@createBlobServiceContainer
            id=containerId
            name=containerName
            accountName=accountName
            blobName=blobName
            publicAccess=publicAccess
            dependsOn=
              [ 
                getReference(accountId, accountName),
                getReference(blobId, blobName)
              ]
          /]
        [/#if]
      [/#if]

      [#-- Keys --]
      [#if subCore.Type == BASELINE_KEY_COMPONENT_TYPE]

        [#switch subSolution.Engine]
          [#case "cmk"]

            [#local localKeyPairId = subResources[LOCAL_CMK_KEY_PAIR_RESOURCE_TYPE].Id]
            [#local localKeyPairPublicKey = subResources[LOCAL_CMK_KEY_PAIR_RESOURCE_TYPE].PublicKey]
            [#local localKeyPairPrivateKey = subResources[LOCAL_CMK_KEY_PAIR_RESOURCE_TYPE].PrivateKey]
            [#local keyPairId = subResources[AZURE_CMK_KEY_PAIR_RESOURCE_TYPE].Id]
            [#local keyPairName = subResources[AZURE_CMK_KEY_PAIR_RESOURCE_TYPE].Name]
            [#local keyVaultName = keyvaultName]

            [#if deploymentSubsetRequired("epilogue")]

              [#-- Generate & Import CMK into keyvault --]
              [@addToDefaultBashScriptOutput 
                content=[
                  "function az_manage_cmk_credentials() {"
                  "  info \"Checking CMK credentials ...\"",
                  "  #",
                  "  # Create CMK credential for the segment",
                  "  mkdir -p \"$\{SEGMENT_OPERATIONS_DIR}\"",
                  "  az_create_pki_credentials \"$\{SEGMENT_OPERATIONS_DIR}\" " +
                      "\"" + regionId + "\" " +
                      "\"" + accountObject.Id + "\" " +
                      " cmk || return $?",
                  "  #",
                  "  # Update the credential if required",
                  "  if ! az_check_key_credentials" + " " +
                      "\"" + keyVaultName + "\" " +
                      "\"" + keyPairName + "\"; then",
                  "    pem_file=\"$\{SEGMENT_OPERATIONS_DIR}/" + localKeyPairPublicKey + "\"",
                  "    az_update_key_credentials" + " " +
                      "\"" + keyVaultName + "\" " +
                      "\"" + keyPairName + "\" " +
                      "\"$\{pem_file}\" || return $?",
                  "   [[ -f \"$\{SEGMENT_OPERATIONS_DIR}/" + localKeyPairPrivateKey + ".plaintext\" ]] && ",
                  "      { encrypt_file" + " " +
                          "\"" + regionId + "\"" + " " +
                          "\"" + keyPairId + "\"" + " " +
                          "\"$\{SEGMENT_OPERATIONS_DIR}/" + localKeyPairPrivateKey + ".plaintext\"" + " " +
                          "\"$\{SEGMENT_OPERATIONS_DIR}/" + localKeyPairPrivateKey + "\" || return $?; }",
                  "  fi",
                  "  #"
                ] +
                pseudoArmStackOutputScript(
                  "CMK Key Pair",
                  {
                    keyPairId : keyPairName,
                    formatId(keyVaultName, "Name") : keyVaultName
                  },
                  "cmk"
                ) +
                [
                  "  #",
                  "  az_show_key_credentials" + " " +
                      "\"" + keyVaultName + "\" " +
                      "\"" + keyPairName + "\" ",
                  "  #",
                  "  return 0"
                  "}",
                  "#",
                  "# Determine the required key pair name",
                  "key_pair_name=\"" + keyPairName + "\"",
                  "#",
                  "case $\{STACK_OPERATION} in",
                  "  delete)",
                  "    az_delete_key_credentials " + " " +
                    "\"" + keyVaultName + "\" " +
                    "\"$\{key_pair_name}\" || return $?",
                  "    az_delete_pki_credentials \"$\{SEGMENT_OPERATIONS_DIR}\" " +
                        "\"" + regionId + "\" " +
                        "\"" + accountObject.Id + "\" " +
                        " cmk || return $?",
                  "    rm -f \"$\{CF_DIR}/$(fileBase \"$\{BASH_SOURCE}\")-keypair-pseudo-stack.json\"",
                  "    ;;",
                  "  create|update)",
                  "    az_manage_cmk_credentials || return $?",
                  "    ;;",
                  "esac"
                ]
              /]

            [/#if]
          [#break]
          [#case "ssh"]

            [#local localKeyPairId = subResources[LOCAL_SSH_PRIVATE_KEY_RESOURCE_TYPE].Id]
            [#local localKeyPairPublicKey = subResources[LOCAL_SSH_PRIVATE_KEY_RESOURCE_TYPE].PublicKey]
            [#local localKeyPairPrivateKey = subResources[LOCAL_SSH_PRIVATE_KEY_RESOURCE_TYPE].PrivateKey]
            [#local vmKeyPairId = subResources[AZURE_SSH_PRIVATE_KEY_RESOURCE_TYPE].Id]
            [#local vmKeyPairName = subResources[AZURE_SSH_PRIVATE_KEY_RESOURCE_TYPE].Name]
            [#local vmKeyVaultName = keyvaultName]

            [#if deploymentSubsetRequired("epilogue")]

              [#-- Generate & Import SSH credentials into keyvault --]
              [@addToDefaultBashScriptOutput 
                content=[
                  "function az_manage_ssh_credentials() {"
                  "  info \"Checking SSH credentials ...\"",
                  "  #",
                  "  # Create SSH credential for the segment",
                  "  mkdir -p \"$\{SEGMENT_OPERATIONS_DIR}\"",
                  "  az_create_pki_credentials \"$\{SEGMENT_OPERATIONS_DIR}\" " +
                      "\"" + regionId + "\" " +
                      "\"" + accountObject.Id + "\" " +
                      " ssh || return $?",
                  "  #",
                  "  # Update the credential if required",
                  "  if ! az_check_key_credentials" + " " +
                      "\"" + vmKeyVaultName + "\" " +
                      "\"" + vmKeyPairName + "\"; then",
                  "    pem_file=\"$\{SEGMENT_OPERATIONS_DIR}/" + localKeyPairPublicKey + "\"",
                  "    az_update_key_credentials" + " " +
                      "\"" + vmKeyVaultName + "\" " +
                      "\"" + vmKeyPairName + "\" " +
                      "\"$\{pem_file}\" || return $?",
                  "   [[ -f \"$\{SEGMENT_OPERATIONS_DIR}/" + localKeyPairPrivateKey + ".plaintext\" ]] && ",
                  "      { encrypt_file" + " " +
                          "\"" + regionId + "\"" + " " +
                          "\"" + cmkKeyId + "\"" + " " +
                          "\"$\{SEGMENT_OPERATIONS_DIR}/" + localKeyPairPrivateKey + ".plaintext\"" + " " +
                          "\"$\{SEGMENT_OPERATIONS_DIR}/" + localKeyPairPrivateKey + "\" || return $?; }",
                  "  fi",
                  "  #"
                ] +
                pseudoArmStackOutputScript(
                  "SSH Key Pair",
                  {
                    vmKeyPairId : vmKeyPairName,
                    formatId(vmKeyVaultName, "Name") : vmKeyVaultName
                  },
                  "keypair"
                ) +
                [
                  "  #",
                  "  az_show_key_credentials" + " " +
                      "\"" + vmKeyVaultName + "\" " +
                      "\"" + vmKeyPairName + "\" ",
                  "  #",
                  "  return 0"
                  "}",
                  "#",
                  "# Determine the required key pair name",
                  "key_pair_name=\"" + vmKeyPairName + "\"",
                  "#",
                  "case $\{STACK_OPERATION} in",
                  "  delete)",
                  "    az_delete_key_credentials " + " " +
                    "\"" + vmKeyVaultName + "\" " +
                    "\"$\{key_pair_name}\" || return $?",
                  "    az_delete_pki_credentials \"$\{SEGMENT_OPERATIONS_DIR}\" " +
                        "\"" + regionId + "\" " +
                        "\"" + accountObject.Id + "\" " +
                        " ssh || return $?",
                  "    rm -f \"$\{CF_DIR}/$(fileBase \"$\{BASH_SOURCE}\")-keypair-pseudo-stack.json\"",
                  "    ;;",
                  "  create|update)",
                  "    az_manage_ssh_credentials || return $?",
                  "    ;;",
                  "esac"
                ]
              /]
            [/#if]
          [#break]
        [/#switch]
      [/#if]
    [/#list]
[/#macro]