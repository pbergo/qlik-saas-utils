#################################################################################
#
# qlik_saas_change_owner
#
# Change the owner of apps
#
# (c) Pedro Bergo - pedroabergo@gmail.com - 2022
#
# PowerShell 7.1.3
# qlik-cli 2.3.1
#
#################################################################################

###### Parametros da aplicação
Param (
    [Parameter()][alias("owner")][string]$OldOwner = 'none',                    #Actual (or Old) owner name
    [Parameter()][alias("nowner")][string]$NewOwner = 'none',                   #Actual (or Old) owner name
    [Parameter()][alias("files")][string]$fileNames = 'none',                   #Apps a serem movidos
    [Parameter()][alias("space")][string]$spaceName = 'Personal',               #Space containing apps a serem movidos
    [Parameter()][alias("pub")][string]$publish = 'yes'                         #Publica sheets, stories e bookmarks antes de mover para o novo usuário
)

###### Funções
function Write-Log {
    param ( 
        [Parameter(Mandatory)][string]$Message,
        [Parameter()][ValidateSet('Info','Warn','Error')][string]$Severity = 'Info'
    )    
    $line = [pscustomobject]@{
        'DateTime' = (Get-Date)
        'Severity' = $Severity
        'Message' = $Message        
    }
    Write-Host "$($line.DateTime) [$($line.Severity)]: $($line.Message)"
    $line | Export-Csv -Path ./qlik_saas_upload.log -Append -NoTypeInformation
}

function PowerVersion {
    $version = $PSVersionTable.PSVersion
    Return ($version.Major -lt 7) 
}

function Show-Help {
    $helpMessage = "
    
qlik_saas_change_owner is a command line to change owner and info with one command line.

Instructions:
The space must contain the name of SaaS Space wich has the files that will be deleted. You can specify
the name files and / or older files date to date parameter, writed in dd-mm-yyy format.

If you set the Confirm parameter to 'no', nothing will be done, just the file names will be listed.

Usage:
qlik_saas_change_owner.ps1 -oldOwner <oldUserID> -newOwner <newUserID> [-fileNames <fileNames>] [-confirm <yes|no>]
    oldOwner  = The ID to owner to be used. 
                This parameter is mandatory.
    newOwner  = The Id to new owner to be used. 
                This parameter is mandatory.
    fileNames = The Name of Apps, you can use wildcards.
                Default is all files from oldOwner
    spaceName = The name of Space.
                Default is 'Personal'
    publish   = Publish all sheets, stories and bookmarks before moving it to new user
                Default is yes
    "
    Write-Output $helpMessage
    return
}

function moveOwner  {
    $spaces = qlik space filter --names "$($spaceName)" | ConvertFrom-Json
    if (($?) -or ($spaceName -eq 'personal')) {
        if ($spaceName -eq 'Personal') {
            if ($fileNames -eq 'none') {
                $apps = qlik app ls --ownerId "$($OldOwner)" --limit 10000 | ConvertFrom-String | where { ($_.P1 -ne 'ID') }
            } else {
                $apps = qlik app ls --ownerId "$($OldOwner)" --name "$($fileNames)" --limit 10000 | ConvertFrom-String | where { ($_.P1 -ne 'ID') }
            }
        } else {
            if ($fileNames -eq 'none') {
                $apps = qlik app ls --ownerId "$($OldOwner)" --spaceId "$($spaces.id)" --limit 10000 | ConvertFrom-String | where { ($_.P1 -ne 'ID') }
            } else {
                $apps = qlik app ls --ownerId "$($OldOwner)" --name "$($fileNames)" --spaceId "$($spaces.id)" --limit 10000 | ConvertFrom-String | where { ($_.P1 -ne 'ID') }
            }
        }
        while ( $($apps.Length) -ge 1) {
            foreach ($app in $apps) {
                Write-Log -Message "Moving app [$($app.P1)] to Owner [$($newOwner)]";
                #Publica as pastas da aplicação
                #$sheetsApp = qlik app object ls -a "$($UppedApp.resourceId)" | ConvertFrom-String | where { ($_.P2 -eq 'sheet') -or ($_.P2 -eq 'bookmark')}
                $sheetsApp = (qlik app object ls -a "$($app.P1)").Trim() -replace '\s{2,}', ',' | ConvertFrom-Csv | where { ($_.Type -eq 'sheet') -or ($_.Type -eq 'bookmark') -or ($_Type -eq 'story')}
                if ($publish -eq "yes") {
                    foreach ($sheet in $sheetsApp) {
                        Write-Log -Message "Publishing Sheet id [$($sheet.ID)] from app [$($app.P1)]";
                        $PublishedSheet = qlik app object publish "$($sheet.ID)" -a "$($app.P1)"
                        if ($?) { 
                            Write-Log -Message "Object [$($sheet.ID)] type [$($sheet.Type)] published at app Id [$($app.P1)]";
                        #} else { 
                        #    Write-Log -Severity "Error" -Message "Error publishing Object [$($sheet.ID)] type [$($sheet.Type)] at app Id [$($app.P1)]";
                        }
                    }    
                }
        
                $change=qlik app owner $app.P1 --ownerId $NewOwner | ConvertFrom-Json
                if ($change.attributes.ownerId -eq $NewOwner) {
                    Write-Log -Message "App [$($app.P1)] moved to Owner [$($newOwner)]";
                } else {
                    Write-Log -Severity "Error" -Message "Error moving app [$($app.P1)] to Owner [$($newOwner)]";
                }
            }
            Write-Host 'Next page...'
            if ($spaceName -eq 'Personal') {
                if ($fileNames -eq 'none') {
                    $apps = qlik app ls --ownerId "$($OldOwner)" --limit 10000 | ConvertFrom-String | where { ($_.P1 -ne 'ID') }
                } else {
                    $apps = qlik app ls --ownerId "$($OldOwner)" --name "$($fileNames)" --limit 10000 | ConvertFrom-String | where { ($_.P1 -ne 'ID') }
                }
            } else {
                if ($fileNames -eq 'none') {
                    $apps = qlik app ls --ownerId "$($OldOwner)" --spaceId "$($spaces.id)" --limit 10000 | ConvertFrom-String | where { ($_.P1 -ne 'ID') }
                } else {
                    $apps = qlik app ls --ownerId "$($OldOwner)" --name "$($fileNames)" --spaceId "$($spaces.id)" --limit 10000 | ConvertFrom-String | where { ($_.P1 -ne 'ID') }
                }
            }
        }
    }
}

###### Código principal
#Validações iniciais
if ( (PowerVersion) ) {
    $message = "
    *********************************************************************************************

    Wrong version... This command only works with Powershell >= 7. 

    Please download a newer PowerShell version at https://docs.microsoft.com/pt-br/powershell/

    *********************************************************************************************"
    Write-Log -Severity 'Error' -Message $message;
    return
}

#Check if exists context
$qlikContext = qlik context get 
if ($qlikContext -eq 'No current context'){
    Write-Log -Severity 'Error' -Message "You must create and select a context to upload files";
    Show-Help
    return
}
# Define your tenant URL
$tenant = Get-Content -Path ~/.qlik/qcs-tenant.txt
# Define your API key
$apikey = Get-Content -Path ~/.qlik/qcs-api_key.txt
If (!($tenant) -or !($apikey)) {
    Write-Log -Severity "Error" -Message "You must create files (qcs-tenant.txt) and (qcs-api_key.txt) at ~/.qlik to change apps owners...";
    Show-Help
    return
}
if (($OldOwner -eq 'none') -or ($NewOwner -eq 'none')) {
    Show-Help
    return
}

# Version <=5
# $qlikContext = qlik context get | ConvertFrom-String | where { ($_.P1 -eq 'Name:') }
# $qlikContextName = $qlikContext.P2
# Version >5
$qlikContextName = $qlikContext[0].replace(' ','').split(':')[1]

Write-Log -Message "#################################################"
###### Changing owner apps...
Write-Log -Message "oldOwner parameter used is [$($oldOwner)]"
Write-Log -Message "NewOwner parameter used is [$($NewOwner)]"
Write-Log -Message "fileName parameter used is [$($fileNames)]"
Write-Log -Message "spaceName parameter used is [$($spaceName)]"

moveOwner

Write-Log -Message "End of changing owner apps."
Write-Log -Message "#################################################"
