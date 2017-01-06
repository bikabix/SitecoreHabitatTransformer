<#
Disclaimer: 
    This script is written for personal interests and does not come with any
    quarantee. Use it at your own risk and feel free to modify it to suit
    your particular needs.

Purpose:
    To patch the original Sitecore Habitat solution to your custom solution
    that utilises Habitat.

    Note that this only works on a brand new Habitat clone.

Prerequisites:
    - Make sure you have node.js (1.4+) installed and npm is available from
      command prompt
    - Make sure you have gulp installed globally by running
      npm install -g gulp

Usage:
    You need Windows Powershell and make sure you have the priviledge to
    execute a powershell script. Then follow the steps below:
    1. Put this script into the root of where you cloned the Habitat.
    2. Open a windows powershell console as Administrator
    3. CD to the root folder of the cloned Habitat (where it contains the
       Habitat.sln file).
    4. Type the following command and hit Enter
       .\TransformHabitat.ps1
    5. Follow the instructions on the screen.

Troubleshoot:
    Sorry you are on your own ;-)

Author:
    Dennis Lee (c_hsuan at hotmail dot com)

Revision History:
    Dec 2016 - initial version created
    Jan 2017 - revision 1
#>

# Global variables
$solutionName = ""
$solutionNameLower = ""
$instanceRoot = ""
$hostName = ""
$rootHostName = ""
$patchHabitatWebProject = $true
$pwd = ""

# Helper functions 

function Check-Administrator {
    return [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
}

function Msg-Info {
    Write-Host $args[0] -ForegroundColor Cyan
}

function Msg-Warn {
    Write-Host $args[0] -ForegroundColor Yellow
}

function Msg-Error {
    Write-Host $args[0] -ForegroundColor Red
}

function Replace-File-Content() {
    <#
    .SYNOPSIS
    Replace strings in a give file. 
    .DESCRIPTION
    The textToReplace array and replaceWith array must match each other, e.g. $a[0] is to be replaced with $b[0] and so on.
    .PARAMETER path
    #>
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory=$True, HelpMessage='The full path to the file to load content from')]
        [string]$path,

        [Parameter(Mandatory=$True, HelpMessage='An array of string(s) to be replaced.')]
        [Alias('searchArray')]
        [string[]]$textToReplace,

        [Parameter(Mandatory=$True, HelpMessage='An array of string(s) to replace with')]
        [Alias('replaceArray')]
        [string[]]$replaceWith
    )

    $needReplacing = $false

    $content = [System.IO.File]::ReadAllText($path)

    # Just make sure there is content to replace
    for ($i=0; $i -le $textToReplace.Length; $i++) {
        if ($content.Contains($textToReplace[$i])) {
            $needReplacing = $true
            break
        }
    }

    if ($needReplacing) {
        for ($i=0; $i -le $textToReplace.Length; $i++) {
            $content = $content.Replace($textToReplace[$i], $replaceWith[$i])
        }
        [System.IO.File]::WriteAllText($path, $content)
    }
}

function Replace-YML-Content([string]$path, [string[]]$textToReplace, [string[]]$replaceWith) {
    $replaced = $false
    $content = [System.IO.File]::ReadAllText($path)
    $lines = $content.Split("`n")

    for ($ri=1; $ri -lt $lines.Length; $ri++) {
        if ($lines[$ri].Length -gt 0) {
            $isRole = ($lines[$ri].IndexOf("Role:") -ge 0)
            $isPath = ($lines[$ri].IndexOf("Path:") -ge 0)
            $isValuePath = ($lines[$ri].IndexOf("Value: /") -ge 0)
            $isSecurityField = ($lines[$ri-1].IndexOf("Hint: __Security") -ge 0)
            $isMediaImage = ($lines[$ri-1].IndexOf("Hint: MediaImage") -ge 0)

            $ti = $ri
            if ($isRole -or $isSecurityField -or $isMediaImage) {
                # Role / Security / media value is at next line
                $ti = $ri+1
            }

            if ($isPath -or $isRole -or $isValuePath -or $isSecurityField -or $isMediaImage) {
                for ($i=0; $i -le $textToReplace.Length; $i++) {
                    if ($lines[$ti].Contains($textToReplace[$i])) {
                        $lines[$ti] = $lines[$ti].Replace($textToReplace[$i], $replaceWith[$i])
                        $replaced = $true
                    }
                }
            }
        }
    }

    if ($replaced) {
        for($i=0; $i -lt $lines.Length; $i++) {
            $lines[$i] += "`n"
        }
        $replacedContent = [string]::Concat($lines)
        [System.IO.File]::WriteAllText($path, $replacedContent)
    }
}

function Update-Folder-Files-Generic ([string]$folderPath, [string[]]$filters, [string[]]$stringToReplace, [string[]]$replaceWith, [bool]$replaceFolderName = $false, [bool]$replaceFileContent = $true) {

    if ($filters -eq [string]::Empty) {
        $files = Get-ChildItem $folderPath -File
    }
    else {
        $files = Get-ChildItem ($folderPath + "\*") -File -Include $filters
    }

    # Replacing file content and file name
    foreach ($f in $files) {
        if ($f.Extension -eq ".yml") {
            # Only replace the Path line for yml files
            Replace-YML-Content $f.FullName $stringToReplace $replaceWith
        }
        elseif ($replaceFileContent) {
            Replace-File-Content $f.FullName $stringToReplace $replaceWith
        }
        for ($i=0; $i -lt $stringToReplace.Length; $i++) {
            if ($f.Name.Contains($stringToReplace[$i])) {
                Rename-Item -Path ($f.FullName) -NewName ($f.Directory.FullName + "\" + $f.Name.Replace($stringToReplace[$i], $replaceWith[$i]))
            }
        }
    }

    $folders = Get-ChildItem $folderPath -Directory
    foreach ($folder in $folders) {
        Update-Folder-Files-Generic $folder.FullName $filters $stringToReplace $replaceWith $replaceFolderName $replaceFileContent
    }

    if ($replaceFolderName) {
        # Rename folder name if needed
        $workingFolder = Get-Item ($folderPath)
        $workingFolderParentPath = [System.IO.Path]::GetDirectoryName($folderPath)

        for ($i=0; $i -lt $stringToReplace.Length; $i++) {
            if ($workingFolder.Name.Contains($stringToReplace[$i])) {
                Rename-Item -Path ($workingFolder.FullName) -NewName ($workingFolderParentPath + "\" + $workingFolder.Name.Replace($stringToReplace[$i], $replaceWith[$i]))
            }
        }
    }
}

function Update-Habitat-Folder-Files ([string]$folderPath, [string]$filters) {
    Update-Folder-Files-Generic $folderPath $filters @("Habitat", "habitat") @($solutionName, $solutionNameLower) $true $true
}

# Worker functions

function Remove-Git {
    $yesNo = Read-Host -Prompt "Do you want to remove Git source binding? [y/N]"

    If (($yesNo -eq "Y" -or $yesNo -eq "y")) {
        Msg-Info "`nRemoving Git binding..."
        Remove-Item ".\.git" -Recurse -Force

        Msg-Info "  --> Done`n"
    }
}

function Cleanup-Files {
    Msg-Info "Cleaning up..."
    Remove-Item "*.md" -ErrorAction SilentlyContinue
    Remove-Item "Habitat.v2.ncrunchsolution" -ErrorAction SilentlyContinue
    Remove-Item "LICENSE" -ErrorAction SilentlyContinue

    $path = $pwd + "\Habitat.sln"
    Replace-File-Content $path `
                         @("LICENSE = LICENSE",
                           "README.md = README.md"
                          ) `
                         @(" ", 
                           " "
                          ) -ErrorAction SilentlyContinue

    Msg-Info "  --> Done`n"

    Remove-Git
}

function Update-SolutionName {
    Msg-Info "Updating solution file name..."
    Rename-Item "Habitat.sln" ($solutionName + ".sln")
    Rename-Item "Habitat.sln.DotSettings" ($solutionName + ".sln.DotSettings")
    Msg-Info "  --> Done`n"
}

function Update-AppSettings {
    Msg-Info "Updating appSettings.config..."
    Replace-File-Content ($pwd + "\appSettings.config") `
                         @(
                             "http://demo.habitat.test5ua1.dk.sitecore.net/",
                             "http://habitat.dev.local"
                         ) `
                         @(
                             ("http://demo." + $hostName),
                             ("http://" + $hostName)
                         )
    Msg-Info "  --> Done`n"
}

function Update-MiscFiles {
    Msg-Info "Updating misc. files..."
    Replace-File-Content ($pwd + "\etc\tests.proxy.asmx") "habitat" $solutionNameLower
    Msg-Info "  --> Done`n"
}

function Update-Gulp-Config {
    Msg-Info "Updating gulp-config.js..."
    $path = $pwd + "\gulp-config.js"
    Replace-File-Content $path @("C:\\websites\\Habitat.dev.local", "Habitat") @($instanceRoot.Replace("\", "\\"), $solutionName)
    Msg-Info "  --> Done`n"
}

function Update-Publish-Targets {
    Msg-Info  "Updating publishsettings.targets..."
    $path = $pwd + "\publishsettings.targets"
    Replace-File-Content $path @("http://habitat.dev.local") @("http://" + $hostName)
    Msg-Info "  --> Done`n"
}

function Update-GulpFile-Js {
    Msg-Info  "Updating gulpfile.js and related javascript files..."
    
    # Patch scripts\habitat.js
    Replace-File-Content ($pwd + "\scripts\habitat.js") `
                         @("habitat", "Habitat") `
                         @($solutionNameLower, $solutionName) -ErrorAction SilentlyContinue

    # Rename scripts\habitat.js to <solutionNameLower>.js
    Rename-Item ($pwd + "\scripts\habitat.js") ($pwd + "\scripts\$solutionNameLower.js") -ErrorAction SilentlyContinue

    # Patch the gulpfile.js
    $path = $pwd + "\gulpfile.js"
    Replace-File-Content $path `
                         @("var habitat", 
                           "./scripts/habitat.js", 
                           "habitat.getSiteUrl()",
                           "Habitat}"
                          ) `
                         @(("var " + $solutionNameLower), 
                           ("./scripts/" + $solutionNameLower + ".js"),
                           ($solutionNameLower + ".getSiteUrl()"),
                           ($solutionName + "}")
                          )

    # Patch the gilpfile-ci.js
    $path = $pwd + "\gulpfile-ci.js"
    Replace-File-Content $path @("Habitat") @($solutionName)

    Msg-Info "  --> Done`n"
}

function Update-Features {
    $featureFolderPath = Get-Item ($pwd + "\src\Feature")
    $featureFolders = Get-ChildItem $featureFolderPath -Directory
    foreach ($folder in $featureFolders) {
        # Clean up
        Msg-Info ("Cleaning up feature folder [" + $folder.FullName + "]...")
        Remove-Item -Path ($folder.FullName + "\code\Habitat*")

        # Sitecore rocks
        $rocksFiles = Get-ChildItem ($folder.FullName + "\code") -File -Filter "*.sitecore"
        foreach ($file in $rocksFiles) {
            Replace-File-Content $file.FullName @("habitat.dev.local") @($hostName)
        }

        # The rest
        Update-Folder-Files-Generic $featureFolderPath @("*.csproj", "*.config") @("Habitat") @($solutionName) $false $true
    }
}

function Update-Foundation {
    $foundationFolderPath = Get-Item ($pwd + "\src\Foundation")
    $foundationFolders = Get-ChildItem $foundationFolderPath -Directory
    foreach ($folder in $foundationFolders) {
        # Clean up
        Msg-Info ("Cleaning up foundation folder [" + $folder.FullName + "]...")
        Remove-Item -Path ($folder.FullName + "\code\Habitat*")

        # Sitecore rocks
        $rocksFiles = Get-ChildItem ($folder.FullName + "\code") -File -Filter "*.sitecore"
        foreach ($file in $rocksFiles) {
            Replace-File-Content $file.FullName @("habitat.dev.local") @($hostName)
        }

        # The rest
        Update-Folder-Files-Generic $foundationFolderPath @("*.csproj", "*.config", "AssemblyInfo.cs", "MongoRestoreServiceTests.cs") `
                                    @(
                                        "habitat.dev.local",
                                        "habitat_local_"
                                        "Habitat"
                                     ) `
                                    @(
                                        $hostName,
                                        ($solutionNameLower + "_local_"),
                                        $solutionName
                                     ) `
                                    $false `
                                    $true
    }    
}

# Habitat website project patching functions

function Rename-Habitat-Folders-Files {
    Msg-Info "Renaming Habitat folders and files..."

    Rename-Item -Path ($pwd + "\src\Project\Habitat\code\App_Config\Include\Project\z.Habitat.DevSettings.config") -NewName ($pwd + "\src\Project\Habitat\code\App_Config\Include\Project\z." + $solutionName + ".DevSettings.config") -ErrorAction SilentlyContinue
    Rename-Item -Path ($pwd + "\src\Project\Habitat\code\Sitecore.Habitat.Website.csproj") -NewName ($pwd + "\src\Project\Habitat\code\" + $solutionName + ".Website.csproj") -ErrorAction SilentlyContinue
    Rename-Item -Path ($pwd + "\src\Project\Habitat\code\Sitecore.Habitat.Website.csproj.sitecore") -NewName ($pwd + "\src\Project\Habitat\code\" + $solutionName + ".Website.csproj.sitecore") -ErrorAction SilentlyContinue
    Rename-Item -Path ($pwd + "\src\Project\Habitat\code\Sitecore.Habitat.Website.csproj.user") -NewName ($pwd + "\src\Project\Habitat\code\" + $solutionName + ".Website.csproj.user") -ErrorAction SilentlyContinue
    Rename-Item -Path ($pwd + "\src\Project\Habitat\code\App_Config\Include\Project\Habitat.Website.config") -NewName ($pwd + "\src\Project\Habitat\code\App_Config\Include\Project\" + $solutionName + ".Website.config") -ErrorAction SilentlyContinue
    Rename-Item -Path ($pwd + "\src\Project\Habitat\code\App_Config\Include\Project\Habitat.Website.Serialization.config") -NewName ($pwd + "\src\Project\Habitat\code\App_Config\Include\Project\" + $solutionName + ".Website.Serialization.config") -ErrorAction SilentlyContinue
    Rename-Item -Path ($pwd + "\src\Project\Habitat\specs\Habitat.Website") -NewName ($pwd + "\src\Project\Habitat\specs\" + $solutionName + ".Website") -ErrorAction SilentlyContinue
    Rename-Item -Path ($pwd + "\src\Project\Habitat") -NewName ($pwd + "\src\Project\" + $solutionName) -ErrorAction SilentlyContinue
    Rename-Item ".\Habitat.TestScenarios.sln" (".\" + $solutionName + ".TestScenarios.sln") -ErrorAction SilentlyContinue
    Msg-Info "  --> Done`n"
}

function Update-Habitat-Project-Files {
    Msg-Info "Patching files under Habitat project..."

    # Habitat website project
    Replace-File-Content ($pwd + "\src\Project\" + $solutionName + "\code\" + $solutionName + ".Website.csproj") `
                         @("Sitecore.Habitat.Website", "http://habitat.dev.local", "Habitat") `
                         @(("$solutionName" + ".Website"), ("http://" + $hostName), $solutionName)

    # Habitat website project sitecore rocks configuration
    Replace-File-Content ($pwd + "\src\Project\" + $solutionName + "\code\" + $solutionName + ".Website.csproj.sitecore") `
                         @("habitat.dev.local") `
                         @($hostName)

    # Habitat website project sitecore rocks configuration
    Replace-File-Content ($pwd + "\src\Project\" + $solutionName + "\code\Properties\AssemblyInfo.cs") `
                         @("Sitecore.Habitat", "Habitat", "Sitecore 2015") `
                         @($solutionName, $solutionName, ($solutionName + " " + (Get-Date).Year))
    
    # Habitat website config
    Replace-File-Content ($pwd + "\src\Project\" + $solutionName + "\code\App_Config\Include\Project\" + $solutionName + ".Website.config") `
                         @("habitat") `
                         @($solutionNameLower)

    # Habitat serialization config
    Replace-File-Content ($pwd + "\src\Project\" + $solutionName + "\code\App_Config\Include\Project\" + $solutionName + ".Website.Serialization.config") `
                         @("habitat", "Habitat", "Project.Common.Website") `
                         @($solutionNameLower, $solutionName, ($solutionName + ".Common.Website"))

    # Habitat dev settings config
    Replace-File-Content ($pwd + "\src\Project\" + $solutionName + "\code\App_Config\Include\Project\z." + $solutionName + ".DevSettings.config") `
                         @("habitat", "C:\projects\Habitat\src", "dev.local") `
                         @($solutionNameLower, ($pwd + "\src"), $rootHostName)

    # Security domain transformation file
    Replace-File-Content ($pwd + "\src\Project\" + $solutionName + "\code\App_Config\Security\domains.config.transform") `
                         @("habitat") `
                         @($solutionNameLower)

    Msg-Info "  --> Done`n"
}

function Update-Specs-Projects {

    Msg-Info "Updating spec projects..."

    $specsFolderPath = ($pwd + "\src\Project\" + $solutionName + "\specs")
    Update-Folder-Files-Generic $specsFolderPath @("*.cs", "*.csproj", "*.feature") @("Habitat", "habitat") @($solutionName, $solutionNameLower) $true $true

    Replace-File-Content ($pwd + "\" + $solutionName + ".TestScenarios.sln") `
                         @("Sitecore.Habitat.Website.Specflow", "Habitat") `
                         @(($solutionName + ".Website.Specflow"), $solutionName)

    Msg-Info "  --> Done`n"
}


function Update-Habitat-Unicorn-Items {
    Msg-Info "Patching Habitat Unicorn serialization items..."
    $serializationRoot = ($pwd + "\src\Project\" + $solutionName + "\serialization")

    # Looping through serialization folders
    Update-Habitat-Folder-Files $serializationRoot "*.yml"

    Msg-Info "  --> Done`n"
}

function Update-Feature-Unicorn-Items {
    Msg-Info "Patching Features Unicorn serialization items..."
    $featureRoot = ($pwd + "\src\Feature")

    # Looping through serialization folders
    Update-Habitat-Folder-Files $featureRoot "*.yml"

    Msg-Info "  --> Done`n"
}

function Update-Habitat-Solution {
    #TODO: update solution file to replace Habitat with $solutionName
    Msg-Info ("Updating $solutionName.sln...")
    
    Replace-File-Content ($pwd + "\" + $solutionName + ".sln") `
                         @("Sitecore.Habitat", "Sitecore.Common", "Habitat") `
                         @($solutionName, ($solutionName + ".Common"), $solutionName)

    Msg-Info "  --> Done`n"
}

function Update-Habitat {
    Rename-Habitat-Folders-Files
    Update-Habitat-Project-Files
    Update-Habitat-Solution
    Update-Habitat-Unicorn-Items
    Update-Specs-Projects
}

function Rename-Common-Folders-Files {
    Msg-Info "Renaming Common folders and files..."

    Replace-File-Content ($pwd + "\src\Project\Common\code\Properties\AssemblyInfo.cs") `
                         @("Sitecore.Common.Website", "Habitat", "Sitecore 2015") `
                         @(($solutionName + ".Common.Website"), $solutionName, ($solutionName + " " + (Get-Date).Year))

    Replace-File-Content ($pwd + "\src\Project\Common\code\App_Config\Include\Project\Common.Website.config") `
                         @("dev.local") `
                         @($rootHostName)

    Replace-File-Content ($pwd + "\src\Project\Common\code\App_Config\Include\Project\Common.Website.Serialization.config") `
                         @("Project.Common.Website") `
                         @(($solutionName + ".Common.Website"))

    Replace-File-Content ($pwd + "\src\Project\Common\code\Sitecore.Common.Website.csproj.sitecore") `
                         @("habitat.dev.local") `
                         @($hostName)

    Replace-File-Content ($pwd + "\src\Project\Common\code\Sitecore.Common.Website.csproj") `
                         @("Habitat.pubxml") `
                         @(($solutionName + ".pubxml"))

    Rename-Item -Path ($pwd + "\src\Project\Common\code\Sitecore.Common.Website.csproj") -NewName ($pwd + "\src\Project\Common\code\" + $solutionName + ".Common.Website.csproj") -ErrorAction SilentlyContinue
    Rename-Item -Path ($pwd + "\src\Project\Common\code\Sitecore.Common.Website.csproj.sitecore") -NewName ($pwd + "\src\Project\Common\code\" + $solutionName + ".Common.Website.csproj.sitecore") -ErrorAction SilentlyContinue
    Rename-Item -Path ($pwd + "\src\Project\Common\code\Properties\PublishProfiles\Habitat.pubxml") -NewName ($pwd + "\src\Project\Common\code\Properties\PublishProfiles\" + $solutionName + ".pubxml") -ErrorAction SilentlyContinue


    Msg-Info "  --> Done`n"
}

function Update-Common-Unicorn-Items {
    Msg-Info "Patching Common Unicorn serialization items..."
    $serializationRoot = ($pwd + "\src\Project\Common\serialization")

    # Looping through serialization folders
    Update-Folder-Files-Generic $serializationRoot "*.yml" @("Habitat", "habitat") @($solutionName, $solutionNameLower) $true $true

    Msg-Info "  --> Done`n"
}

function Update-Common {
    Rename-Common-Folders-Files
    Update-Common-Unicorn-Items
}

function Check-Clean-Clone {
    # Correct path?
    if (!(Test-Path .\gulp-config.js)) {
        Return $false
    }

    # Habitat.sln
    if (!(Test-Path .\Habitat.sln)) {
        Return $false
    }

    Return $true
}

function Check-NodeJs {
    try {
        $nodeVer = $(node --version)
        Msg-Info ("Detected Node version: " + $nodeVer)
        Return $true
    }
    catch [System.Exception] {
        Return $false
    }
}

function Check-Gulp {
    try {
        $gulpVer = $(gulp --version)
        Msg-Info ("Detected Gulp version: " + $gulpVer)
        Return $true
    }
    catch [System.Exception] {
        Return $false
    }
}

function Print-Disclaimer() {

    Msg-Warn "=-[DISCLAIMER]-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=`n"
    Msg-Info " * Check the beginning of this script to see some general info."
    Msg-Info " * This script should only run against a freshly cloned Habitat so"
    Msg-Info "   make sure you have a backup of the clean Habitat in case you need"
    Msg-Info "   to re-run the script."
    Msg-Info " * Modify the script as you wish to suit your needs.`n"
    Msg-Warn "=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-`n`n"
}

function Print-Success-Message() {

    Msg-Info "----------------------------------------------------------------------"
    Msg-Info " Congratulations!!"
    Msg-Info " Habitat has been transformed into $solutionName"
    Msg-Info "----------------------------------------------------------------------`n`n"
}

function Run-NPM-Install {
    $yesNo = Read-Host -Prompt "`nDo you want to run npm install? [Y/n]"
    If ($yesNo -eq [string]::Empty) {
        $yesNo = "Y"
    }

    If (-NOT ($yesNo -eq "Y" -or $yesNo -eq "y")) {
        Return
    }
    else {
        Msg-Info "`nRunning npm install..."
        cmd /c npm install
        Msg-Info "`n  --> Done`n"
    }
}

function Run-Gulp {
    Msg-Info "`n--[Info]-----------------------------------------------------------------`n"
    Msg-Info " Habitat provides a gulp script to facilitate the build and publish"
    Msg-Info " code and content to your local site. If you have installed your local"
    Msg-Info " Sitecore and configured your IIS to match the information you provided"
    Msg-Info " at the beginning of the script (it is recommended to use SIM to"
    Msg-Info " install your local Sitecore instance) you probably want to run this"
    Msg-Info " to make your initial Habitat (transformed) site running and Sitecore"
    Msg-Info " items installed.`n"
    Msg-Warn " Note: it will take a while when running Unicorn sync. If you think it"
    Msg-Warn "       is freezing, check the sitecore log to see sync progress.`n"
    Msg-Info "-------------------------------------------------------------------------`n"
    
    $yesNo = Read-Host -Prompt "`nDo you want to run the default gulp script? [Y/n]"
    If ($yesNo -eq [string]::Empty) {
        $yesNo = "Y"
    }

    If (-NOT ($yesNo -eq "Y" -or $yesNo -eq "y")) {
        Return
    }
    else {
        Msg-Info "`nRunning default gulp task..."
        cmd /c gulp
        Msg-Info "`n  --> Done`n"
    }
}

function Update-Main() {
    $pwd = $(pwd).Path

    $yesNo = Read-Host -Prompt "`nAre you sure you want to proceed? [y/N]"

    If (-NOT ($yesNo -eq "Y" -or $yesNo -eq "y")) {
        Return
    }

    Msg-Info "`n"

    $solutionName = Read-Host -Prompt "Enter your solution name (e.g. ClientName), do not put .sln suffix"
    If ($solutionName -eq [string]::Empty) {
        Msg-Error "Solution name cannot be empty"
        Return
    }
    $solutionName = $solutionName -replace " ", ""
    $solutionNameLower = $solutionName.ToLower()
    Msg-Info ("  --> Using solution name: " + $solutionName)

    Msg-Info "`n---------------------------------------------------"
    Msg-Info " A recommended Sitecore website has the following "
    Msg-Info " folder structure: `n"
    Msg-Info " Root folder"
    Msg-Info "   |_ Data"
    Msg-Info "   |_ Website"
    Msg-Info "     |_ App_Config"
    Msg-Info "     |_ etc"
    Msg-Info "---------------------------------------------------`n"

    $instanceRoot = Read-Host -Prompt "Enter the physical path of your intended Root folder of local published website"
    if ($instanceRoot -eq [string]::Empty) {
        Msg-Error "Root folder path cannot be empty"
        Return
    }
    Msg-Info ("  --> Root path: " + $instanceRoot + "`n")

    $hostName = Read-Host -Prompt "Enter your IIS hostname (e.g. sitename.localtest.me)"
    if ($hostName -eq [string]::Empty) {
        Msg-Error "IIS hostname cannot be empty"
        Return
    }

    $rootHostName = $hostName.Substring($hostName.IndexOf(".")+1)

    Msg-Info ("  --> IIS Hostname: " + $hostName)
    Msg-Info ("  --> Root hostname: " + $rootHostName)
    Msg-Info "`n"

    $patchHabitatWebProjectInput = Read-Host -Prompt "Do you want to rename the Habitat website project? [Y/n]"
    if (!$patchHabitatWebProjectInput -eq [string]::Empty) {
        if ($patchHabitatWebProjectInput.ToLower() -eq "n") {
            $patchHabitatWebProject = $false
            Msg-Warn "    You have chosen No here which means you will need to manually create a new website project for your solution."
        }
    }
    Msg-Info ("  --> Rename Habitat website project: " + $patchHabitatWebProject + "`n")

    Cleanup-Files
    Update-SolutionName
    Update-AppSettings
    Update-MiscFiles
    Update-Gulp-Config
    Update-Publish-Targets
    Update-GulpFile-Js
    Update-MiscFiles
    Update-Foundation
    Update-Features
    Update-Feature-Unicorn-Items

    if ($patchHabitatWebProject) {
        Update-Habitat
        Update-Common
    }

    Print-Success-Message
    Run-NPM-Install
    Run-Gulp

    Msg-Info "`nYou should be able to browse to http://$hostName to see your local site.`n`n"
}

# ==============
# Main
# ==============
Clear-Host
Print-Disclaimer

if (!(Check-Administrator)) {
    Msg-Warn "`nThe script requires the Powershell console to run as Administrator.`n"
    Return
}

if (!(Check-Clean-Clone)) {
    Msg-Warn "Ummm, looks like this is not a valid Habitat solution, please check:`n"
    Msg-Info "  - You put this script in the root of the Habitat solution folder, and"
    Msg-Info "  - You have not transformed this solution before.`n"
    Msg-Info "(Current working folder is: $(pwd))`n`n"
    Return
}

if (!(Check-NodeJs)) {
    Msg-Warn "Looks like you do not have Node.js installed, please install it before running the script.`n`n"
    Return
}

if (!(Check-Gulp)) {
    Msg-Warn "Looks like you do not have gulp installed, please install using`n  npm install -g gulp`n`n"
    Return
}

Update-Main
