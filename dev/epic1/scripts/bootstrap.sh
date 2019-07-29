#!/usr/bin/env bash

# This script is intended for use as a proof-of-concept for ARM template bootstrap scripts only.

# Install Az CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Create a file to copy to the Blob Storage
touch ~/myfile.txt

# Login to Azure with the CLI
az login --identity

# Upload the new file to Blob Storage to verify that the system-managed idenity is correct.
az storage blob upload --container-name container --file ~/myfile.txt --name "blobby007" --account-name $1
