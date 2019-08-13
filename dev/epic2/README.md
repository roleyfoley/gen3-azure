# ManageDeployment

This script enables the deployment of one or more Azure ARM Templates using an existing CodeOnTap CMDB. It is intended for deployment of any Azure resources that may not yet be implimented within CodeOnTap.

In order to deploy using this script, it requires a product CMDB setup, as per the CodeOnTap [readthedocs](https://codeontap.readthedocs.io/en/latest/getting-started/cmdb-setup/#cmdb-creation). You will also need to add the following environmental variables to your system.

|Variable|Description|
|--------|-----------|
|GENERATION_BASE_DIR|Set to the path of your cloned [github gen3 directory](https://github.com/codeontap/gen3)|
|GENERATION_DIR|Set to the path of your provider directory, typically a subdirectory of GENERATION_BASE_DIR|
|ACCOUNT|Set to the name of the account used by your CMDB|

This script should then be imported to your GENERATION_DIR.

# ARM Templates & Parameter Files
So that CodeOnTap knows where to find your templates and parameter files, you will need to place them at the following location, based on the LEVEL of the template. Possible LEVEL's are: "account", "product", "segment", "solution", "application" or "multiple".

```
 <cmdb-root-dir/<PRODUCT>/infrastructure/<PROVIDER>/<ENVIRONMENT>/<SEGMENT>
```

The template/parameter files should match the following naming convention:

> LEVEL-COMPONENT-ACCOUNT-REGION-template.json

> LEVEL-COMPONENT-ACCOUNT-REGION-config.json (parameter file)

The following example is for a number of segment components, each with their own ARM template & parameter file.

```
me@mycomputer$:ll <cmdb-root>/<account>/infrastructure/cf/integration/default
drwxrwxrwx 1 me me  4096 Aug 13 14:45 ./
drwxrwxrwx 1 me me  4096 Aug  1 11:06 ../
-rwxrwxrwx 1 me me   161 Jul 25 17:16 seg-iam-mswdev-eastus-config.json
-rwxrwxrwx 1 me me  1321 Aug 13 14:31 seg-iam-mswdev-eastus-template.json
-rwxrwxrwx 1 me me   161 Jul 21 15:09 seg-network-mswdev-eastus-config.json
-rwxrwxrwx 1 me me  2687 Jul 29 12:11 seg-network-mswdev-eastus-template.json
-rwxrwxrwx 1 me me   257 Aug 13 09:33 seg-rbac-mswdev-eastus-config.json
-rwxrwxrwx 1 me me  1567 Jul 29 12:11 seg-rbac-mswdev-eastus-template.json
-rwxrwxrwx 1 me me   380 Jul 22 18:13 seg-storage-mswdev-eastus-config.json
-rwxrwxrwx 1 me me  3560 Aug  8 17:36 seg-storage-mswdev-eastus-template.json
-rwxrwxrwx 1 me me  1205 Aug 13 14:12 seg-virtualmachines-mswdev-eastus-config.json
-rwxrwxrwx 1 me me 10380 Aug 13 14:32 seg-virtualmachines-mswdev-eastus-template.json
```


# Azure Deployments with ManageDeployment

For CodeOnTap to correctly use the CMDB to lookup values for the deployment, you will need to execute the script from the correct directory depending on the LEVEL of the resource you wish to deploy. Possible LEVEL's are: "account", "product", "segment", "solution", "application" or "multiple".

With this implemented, navigate to the following directory in bash. You will know its the correct directory because - assuming you setup the CMDB correcly - there will be a JSON file already in that directory, named after the LEVEL of deployment.

``` 
cd <cmdb-root-dir/<PRODUCT>/config/<TENANT>/<ENVIRONMENT>/<SEGMENT>

me@mycomputer$ ls
segment.json
```

From here, you can then execute the script for deployment. For help with the options, use the -h option.

```
. ${GENERATION_DIR}/manageDeployment.sh -h
```