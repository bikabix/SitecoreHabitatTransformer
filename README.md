# Sitecore Habitat Transformer

This project contains a single windows Powershell script TransformHabitat.ps1 which basically does the following:

* Updates the Habitat visual studio solution to a custom-named solution. This includes project files, solution files, Unicorn serialization files, config files, javascript files when necessary.

Note that this script only works on a freshly cloned Habitat. See below or the beginning of the script for more information.

## Disclaimer
This script is written for personal interests and does not come with any quarantee. Use it at your own risk and feel free to modify it to suit your particular needs.

## Prerequisites
As Habitat utilizes Node.js and Gulp so make sure:
* Node.js (1.4+) installed and npm is available from command prompt
* Make sure you have gulp installed globally by running 

    npm install -g gulp

At the later part of the script will ask you if you wish to run the gulp script which will build the projects and sync Sitecore items via Unicorn. To be able to run this you will need to have an empty Sitecore (at the moment 8.2 Update 2) and the corresponding Web Forms for Marketers module installed. I recommend using [Sitecore Instance Manager](https://github.com/Sitecore/Sitecore-Instance-Manager) to install your local Sitecore instance. Keep a note at the host name used as the powershell script will ask for it when running.

## Usage
You need Windows Powershell and make sure you have the priviledge to execute a powershell script. Then follow the steps below:

1. Put this script into the root of where you cloned the Habitat
2. Open a windows powershell console as Administrator
3. CD to the root folder of the cloned Habitat (where it contains the Habitat.sln file)
4. Type the following command and hit Enter

    .\TransformHabitat.ps1
    
5. Follow the instructions on the screen.

## Troubleshoot
You are on your own ;)
