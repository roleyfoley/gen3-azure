[#ftl]

[#macro azure_input_shared_masterdata_seed]
  [@addMasterData
    data=
    {
      "Regions": {
        "eastus": {
          "Partitian": "azure",
          "Locality": "UnitedStates",
          "Zones": {
            "a": {
              "Title": "Zone A",
              "Description": "Zone A",
              "AzureId": "eastus",
              "NetworkEndpoints": [
                {
                  "Type": "Interface",
                  "ServiceName": "Microsoft.Storage"
                }
              ]
            }
          },
          "Accounts": {}
        }
      },
      "Tiers": {
        "api": {
          "Network": {
            "RouteTable": "default",
            "NetworkACL": "Private"
          }
        },
        "ana": {
          "Network": {
            "RouteTable": "default",
            "NetworkACL": "Private"
          }
        },
        "app": {
          "Network": {
            "RouteTable": "default",
            "NetworkACL": "Private"
          }
        },
        "db": {
          "Network": {
            "RouteTable": "default",
            "NetworkACL": "Private"
          }
        },
        "dir": {
          "Network": {
            "RouteTable": "default",
            "NetworkACL": "Private"
          }
        },
        "docs": {},
        "elb": {
          "Network": {
            "RouteTable": "default",
            "NetworkACL": "Public"
          }
        },
        "gbl": {
          "Components": {
          }
        },
        "ilb": {
          "Network": {
            "RouteTable": "default",
            "NetworkACL": "Private"
          }
        },
        "mgmt": {
          "Network": {
            "RouteTable": "default",
            "NetworkACL": "Public"
          },
          "Components": {
            "seg-cert": {
              "DeploymentUnits": [
                "cert"
              ]
            },
            "seg-dns": {
              "DeploymentUnits": [
                "dns"
              ],
              "Enabled": false
            },
            "seg-dashboard": {
              "DeploymentUnits": [
                "dashboard"
              ],
              "Enabled": false
            },
            "baseline": {
              "DeploymentUnits": [
                "baseline"
              ],
              "baseline": {
                "DataBuckets": {
                  "opsdata": {
                    "Role": "operations",
                    "Lifecycles": {
                      "awslogs": {
                        "Prefix": "AWSLogs",
                        "Expiration": "_operations",
                        "Offline": "_operations"
                      },
                      "cloudfront": {
                        "Prefix": "CLOUDFRONTLogs",
                        "Expiration": "_operations",
                        "Offline": "_operations"
                      },
                      "docker": {
                        "Prefix": "DOCKERLogs",
                        "Expiration": "_operations",
                        "Offline": "_operations"
                      }
                    },
                    "Links": {
                      "cf_key": {
                        "Tier": "mgmt",
                        "Component": "baseline",
                        "Instance": "",
                        "Version": "",
                        "Key": "oai"
                      }
                    }
                  },
                  "appdata": {
                    "Role": "appdata",
                    "Lifecycles": {
                      "global": {
                        "Expiration": "_data",
                        "Offline": "_data"
                      }
                    }
                  }
                },
                "Keys": {
                  "ssh": {
                    "Engine": "ssh"
                  },
                  "cmk": {
                    "Engine": "cmk"
                  },
                  "oai": {
                    "Engine": "oai"
                  }
                }
              }
            },
            "ssh": {
              "DeploymentUnits": [
                "ssh"
              ],
              "MultiAZ": true,
              "bastion": {
                "AutoScaling": {
                  "DetailedMetrics": false,
                  "ActivityCooldown": 180,
                  "MinUpdateInstances": 0,
                  "AlwaysReplaceOnUpdate": false
                }
              }
            },
            "vpc": {
              "DeploymentUnits": [
                "vpc"
              ],
              "MultiAZ": true,
              "network": {
                "RouteTables": {
                  "default" : {}
                },
                "NetworkACLs": {
                  "Public": {
                    "Rules": {
                      "internetAccess": {
                        "Priority": 200,
                        "Action": "allow",
                        "Source": {
                          "IPAddressGroups": [
                            "_localnet"
                          ]
                        },
                        "Destination": {
                          "IPAddressGroups": [
                            "_global"
                          ],
                          "Port": "any"
                        },
                        "ReturnTraffic": false
                      }
                    }
                  },
                  "Private": {
                    "Rules": {
                      "internetAccess": {
                        "Priority": 200,
                        "Action": "allow",
                        "Source": {
                          "IPAddressGroups": [
                            "_localnet"
                          ]
                        },
                        "Destination": {
                          "IPAddressGroups": [
                            "_global"
                          ],
                          "Port": "any"
                        }
                      },
                      "blockInbound": {
                        "Priority": 100,
                        "Action": "deny",
                        "Source": {
                          "IPAddressGroups": [
                            "_global"
                          ]
                        },
                        "Destination": {
                          "IPAddressGroups": [
                            "_localnet"
                          ],
                          "Port": "any"
                        }
                      }
                    }
                  }
                },
                "Links": {
                  "NetworkEndpoints": {
                    "Tier": "mgmt",
                    "Component": "vpcendpoint",
                    "Version": "",
                    "Instance": "",
                    "Destination" : "default"
                  }
                }
              }
            },
            "igw": {
              "DeploymentUnits": [
                "igw"
              ],
              "gateway": {
                "Engine": "igw",
                "Destinations": {
                  "default": {
                    "IPAddressGroups": "_global",
                    "Links": {
                      "Public": {
                        "Tier": "mgmt",
                        "Component": "vpc",
                        "Version": "",
                        "Instance": "",
                        "RouteTable": "default"
                      }
                    }
                  }
                }
              }
            },
            "nat": {
              "DeploymentUnits": [
                "nat"
              ],
              "gateway": {
                "Engine": "natgw",
                "Destinations": {
                  "default": {
                    "IPAddressGroups": "_global",
                    "Links": {
                      "Private": {
                        "Tier": "mgmt",
                        "Component": "vpc",
                        "Version": "",
                        "Instance": "",
                        "RouteTable": "default"
                      }
                    }
                  }
                }
              }
            },
            "vpcendpoint": {
              "DeploymentUnits": [
                "vpcendpoint"
              ],
              "gateway": {
                "Engine": "vpcendpoint",
                "Destinations": {
                  "default": {
                    "NetworkEndpointGroups": [
                      "storage",
                      "logs"
                    ],
                    "Links": {
                      "Private": {
                        "Tier": "mgmt",
                        "Component": "vpc",
                        "Version": "",
                        "Instance": "",
                        "RouteTable": "default"
                      },
                      "Public": {
                        "Tier": "mgmt",
                        "Component": "vpc",
                        "Version": "",
                        "Instance": "",
                        "RouteTable": "default"
                      }
                    }
                  }
                }
              }
            }
          }
        },
        "msg": {
          "Network": {
            "RouteTable": "default",
            "NetworkACL": "Private"
          }
        },
        "shared": {
          "Network": {
            "RouteTable": "default",
            "NetworkACL": "Public"
          }
        },
        "web": {
          "Network": {
            "RouteTable": "default",
            "NetworkACL": "Private"
          }
        }
      },
      "Storage": {
        "default": {
          "storageAccount": {
            "Tier": "Standard",
            "Replication": "LRS",
            "Type": "BlobStorage",
            "AccessTier": "Cool",
            "HnsEnabled": false
          }
        },
        "Blob": {
          "storageAccount": {
            "Tier": "Standard",
            "Replication": "LRS",
            "Type": "BlobStorage",
            "AccessTier": "Cool",
            "HnsEnabled": false
          }
        },
        "File": {
          "storageAccount": {
            "Tier": "Standard",
            "Replication": "LRS",
            "Type": "FileStorage",
            "HnsEnabled": false
          }
        },
        "Block": {
          "storageAccount": {
            "Tier": "Standard",
            "Replication": "LRS",
            "Type": "BlockBlobStorage",
            "HnsEnabled": false
          }
        }
      },
      "Processors": {
        "default": {}
      },
      "LogFiles": {},
      "LogFileGroups": {},
      "LogFileProfiles": {
        "default": {}
      },
      "CORSProfiles": {
        "S3Write": {
          "AllowedHeaders": [
            "Content-Length",
            "Content-Type",
            "Content-MD5",
            "Authorization",
            "Expect",
            "x-amz-content-sha256",
            "x-amz-security-token"
          ]
        },
        "S3Delete": {
          "AllowedHeaders": [
            "Content-Length",
            "Content-Type",
            "Content-MD5",
            "Authorization",
            "Expect",
            "x-amz-content-sha256",
            "x-amz-security-token"
          ]
        }
      },
      "ScriptStores": {},
      "Bootstraps": {},
      "BootstrapProfiles": {
        "default": {}
      },
      "SecurityProfiles": {
        "default": {}
      },
      "BaselineProfiles": {
        "default": {
          "OpsData": "opsdata",
          "AppData": "appdata",
          "Encryption": "cmk",
          "SSHKey": "ssh",
          "CDNOriginKey": "oai"
        }
      },
      "LogFilters": {},
      "NetworkEndpointGroups": {
        "compute" : {
          "Services" : []
        },
        "security" : {
          "Services" : []
        },
        "configurationMgmt" : {
          "Services" : []
        },
        "containers" : {
          "Services" : []
        },
        "serverless" : {
          "Services" : []
        },
        "logs" : {
          "Services" : []
        },
        "storage" : {
          "Services" : [
            "Microsoft.Storage"
          ]
        }
      },
      "DeploymentProfiles": {
        "default": {
          "Modes": {
            "*": {}
          }
        }
      },
      "Segment": {
        "Network": {
          "InternetAccess": true,
          "Tiers": {
            "Order": [
              "web",
              "msg",
              "app",
              "db",
              "dir",
              "ana",
              "api",
              "spare",
              "elb",
              "ilb",
              "spare",
              "spare",
              "spare",
              "spare",
              "spare",
              "mgmt"
            ]
          },
          "Zones": {
            "Order": [
              "a",
              "b",
              "spare",
              "spare"
            ]
          }
        },
        "NAT": {
          "Enabled": true,
          "MultiAZ": false,
          "Hosted": true
        },
        "Bastion": {
          "Enabled": true,
          "Active": false,
          "IPAddressGroups": []
        },
        "ConsoleOnly": false,
        "S3": {
          "IncludeTenant": false
        },
        "RotateKey": true,
        "Tiers": {
          "Order": [
            "elb",
            "api",
            "web",
            "msg",
            "dir",
            "ilb",
            "app",
            "db",
            "ana",
            "mgmt",
            "docs",
            "gbl"
          ]
        }
      }
    }
  /]
[/#macro]