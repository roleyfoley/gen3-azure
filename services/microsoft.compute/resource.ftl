[#ftl]

[@addResourceProfile
  service=AZURE_VIRTUALMACHINE_SERVICE
  resource=AZURE_VIRTUALMACHINE_SCALESET_RESOURCE_TYPE
  profile=
    {
      "apiVersion" : "2019-03-01",
      "type" : "Microsoft.Compute/virtualMachineScaleSets"
    }
/]

[#assign AZURE_VIRTUALMACHINE_SCALESET_OUTPUT_MAPPINGS = 
  {
    REFERENCE_ATTRIBUTE_TYPE : {
      "Property" : "id"
    },
    NAME_ATTRIBUTE_TYPE : {
      "Property" : "name"
    }
  }
]

[#assign outputMappings +=
  { AZURE_VIRTUALMACHINE_SCALESET_RESOURCE_TYPE : AZURE_VIRTUALMACHINE_SCALESET_OUTPUT_MAPPINGS }
]

[#function getVirtualMachineProfileLinuxConfigPublicKey
  path
  data]

  [#return
    {
      "path" : path,
      "keyData" : data
    }
  ]

[/#function]

[#function getVirtualMachineProfileLinuxConfig
  publicKeys
  disablePasswordAuth=true]

  [#return
    {
      "ssh" : {
        "publicKeys" : publicKeys
      }
    } +
    attributeIfTrue("disablePasswordAuth", disablePasswordAuth, disablePasswordAuth) +
  ]

[/#function]

[#function getVirtualMachineProfileWindowsConfig
  autoUpdatesEnabled=false
  timeZone=""
  unattendContent=[]
  winRM={}]

  [#return
    {} + 
    attributeIfTrue("enableAutomaticUpdates", autoUpdatesEnabled, autoUpdatesEnabled) +
    attributeIfContent("timeZone", timeZone) +
    attributeIfContent("additionalUnattendContent", unattendContent) +
    attributeIfContent("winRM", winRM)
  ]

[/#function]

[#function getVirtualMachineProfile
  vmNamePrefix
  adminName
  storageAccountType
  imagePublisher
  imageOffer
  imageSku
  nicConfigurations
  licenseType=""
  linuxConfiguration={}
  windowsConfiguration={}
  priority="Regular"
  imageVersion="latest"]

  [#return 
    {
      "osProfile" : {
        "computerNamePrefix" : vmNamePrefix,
        "adminUsername" : adminName
      } +
      attributeIfContent("linuxConfiguration", linuxConfiguration) +
      attributeIfContent("windowsConfiguration", windowsConfiguration),
      "storageProfile" : {
        "osDisk" : {
          "createOption" : "FromImage",
          "managedDisk" : {  
          } +
          attributeIfContent("storageAccountType", storageAccountType)
        },
        "imageReference" : {
          "publisher" : imagePublisher,
          "offer" : imageOffer,
          "sku" : imageSku
          "version" : imageVersion
        }
      },
      "networkProfile" : {
        "networkInterfaceConfigurations" : nicConfigurations
      },
      "priority" : priority
    } +
    attributeIfContent("licenseType", licenseType)
  ]

[/#function]

[#macro createVMScaleSet
  id
  name
  location
  skuName
  skuTier
  skuCapacity
  vmProfile
  identity={}
  zones=[]
  outputs={}
  dependsOn={}]

  [@armResource
    id=id
    name=name
    profile=AZURE_VIRTUALMACHINE_SCALESET_RESOURCE_TYPE
    location=location
    sku=
      {
        "name" : skuName,
        "tier" : skuTier,
        "capacity" : skuCapacity
      }
    identity=identity
    outputs=outputs
    dependsOn=dependsOn
    zones=zones
    properties=
      { "virtualMachineProfile" : vmProfile }
  /]

[/#macro]