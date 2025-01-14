#!/bin/bash

# install AZD - keep this version in sync with the version used in the file /.devcontainer/devcontainer.json file
curl -fsSL https://aka.ms/install-azd.sh | bash -s -- -- version 1.10.2

# add Microsoft package feed for the dotnet install
# Get Ubuntu version
declare repo_version=$(if command -v lsb_release &> /dev/null; then lsb_release -r -s; else grep -oP '(?<=^VERSION_ID=).+' /etc/os-release | tr -d '"'; fi)

# Download Microsoft signing key and repository
wget https://packages.microsoft.com/config/ubuntu/$repo_version/packages-microsoft-prod.deb -O packages-microsoft-prod.deb

# Install Microsoft signing key and repository
sudo dpkg -i packages-microsoft-prod.deb

# Clean up
rm packages-microsoft-prod.deb

# Update packages
sudo apt-get -y update

# install jq
sudo apt-get install -y jq

# install dotnet
sudo apt-get install -y dotnet-sdk-8.0

# install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# install pwsh core

# Download the PowerShell package file
wget https://github.com/PowerShell/PowerShell/releases/download/v7.4.1/powershell_7.4.1-1.deb_amd64.deb

###################################
# Install the PowerShell package
sudo dpkg -i powershell_7.4.1-1.deb_amd64.deb

# Resolve missing dependencies and finish the install (if necessary)
sudo apt-get install -f

# Delete the downloaded package file
rm powershell_7.4.1-1.deb_amd64.deb

# install Az module
sudo pwsh -Command "Install-Module -Name Az -Repository PSGallery -Scope AllUsers -Force"

###################################
# Install Docker
# https://docs.docker.com/engine/install/ubuntu/

sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
