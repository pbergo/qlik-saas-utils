#################################################################################
#
# qlik_saas_upload_files
#
# Upload Files to SaaS
#
# (c) Pedro Bergo - pedroabergo@gmail.com - 2023
#
# PowerShell 7.2.13
# qlik-cli 2.22.00
#
#################################################################################

###### Parametros da aplicação
Param (
    [Parameter()][alias("space")][string]$spaceName   = 'personal',           #Espaço a ser utilizado.
    [Parameter()][alias("size")][bigint]$maxFileSize  = 629145600,            #TamMáximo dos arquivos = 600Mb
    [Parameter()][alias("files")][string]$fileNames   = 'none',               #Arquivos a serem eliminados
    [Parameter()][alias("ovw")][string]$overwrite     = 'no',                  #Determina se grava os mais novos ou todos
    [Parameter()][string]$LogFile = '.\' + (Get-Item $PSCommandPath).BaseName + '.log'         # Log file name and path
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
    $line | Export-Csv -Path $LogFile -Append -NoTypeInformation
}

function PowerVersion {
    $version = $PSVersionTable.PSVersion
    Return ($version.Major -lt 7) 
}

function Show-Help {
    $helpMessage = "
    
$((Get-Item $PSCommandPath).BaseName) is a command line to upload files from local folder to specified SaaS space.

Instructions:
    You need to specify the folder/files Name that contais the files to be uploaded. You can use wildcards like '*' and '?'.
    The Space Name must contains the name of SaaS Space wich has the files that will be uploaded. 
    If the space not exists, nothing will be uploaded.

    If you set the Overwrite parameter to 'yes', all files will be uploaded, otherwise only will be uploaded the newer local files.

    The API service will only receive files supported by Qlik SaaS, any other will be disregarded. Today the supported type files are
    '.qvd, .xlsx, .xls, .xlw, .xlsm, .xml, .csv, .txt, .tab, .qvo, .skv, .log, .html, .htm, .kml, .fix, .dat, .qvx, .prn, .php, .qvs'

    You need to create 2 files at ~/.qlik:
    - qcs-tenant.txt: This file must contains the tenant name without protocol, like: aditidemo.us.qlikcloud.com
    - qcs-api_key.txt: This file must contains the api key to connect saas.
    This informations are also inside ~/.qlik/context.yml


Usage:
    $((Get-Item $PSCommandPath).BaseName)  -fileNames <fileNames> [-spaceName <spaceName>] [-confirm <yes|no>] [-LogFile <Logfile path and name>]
        fileNames = The file name to be deleted. You can use wildcards like '*' and '?' to filter files. 
                    This parameter is mandatory.
        spaceName = The Name of Space wich has the files that will be deleted. Leave it blank to use the 
                    Personal space.
                    If there are more than one space with the same name, the first will be used.
        overwrite = If yes, then SaaS files will be overwrited, even they are newer than local files. 
                    If no, only the files older than local files will be uploaded. 
                    Default is no.
        LogFile   = Logfile path and name. 
                    Default is .\" + (Get-Item $PSCommandPath).BaseName + ".log

    *** CAUTION: Each file is deleted before uploading and there no exists roll-back in SaaS upload files, so proceed with caution. 

    "
    Write-Output $helpMessage
    return
}

function ConvPropert {
    [regex]$rx="\s{2,}"
    $properties = $rx.Split($raw[0].trim()) | Convert-StringProperty  
     for ($i=1;$i -lt $raw.count; $i++) {
          $splitData = $rx.split($raw[$i].Trim())
          #create an object for each entry
          $hash = [ordered]@{}
          for ($j=0;$j -lt $properties.count;$j++) {
            $hash.Add($properties[$j],$splitData[$j])
          } 
          [pscustomobject]$hash
    }
}


function Up-Files {
    #Localiza os espaços existentes no servidor
    if ($spaceName -eq 'personal') {
        Write-Log -Message "Using space Personal !";
        $dataconnection = qlik raw get v1/data-connections | ConvertFrom-Json | Where-Object { ($_.qName -eq 'DataFiles') -and ($_.space -eq $null) }
    } else {
        $spaces = qlik space ls --name "$spaceName" | ConvertFrom-Json
        if ($spaces) {
            Write-Log -Message "Using space [$spaceName] ID [$($spaces.id)] !";
            $dataconnection = qlik raw get v1/data-connections --query space="$($spaces.id)" | ConvertFrom-Json | Where-Object {$_.qName -eq 'DataFiles' }
        } else {
            Write-Log -Severity "Error" -Message "The space [$($spaceName)] doesn't exists !";
            return
        }

    }

    #Carrega os arquivos de dados a partir do diretório raiz
    $localfiles = gci $($fileNames) -File
    if ($spaceName -eq 'personal') {
        $saasfiles = qlik raw get v1/qix-datafiles --query top=100000 | ConvertFrom-Json 
    } else {
        $saasfiles = qlik raw get v1/qix-datafiles --query connectionId="$($dataconnection.id)",top=100000 | ConvertFrom-Json
    }

    foreach ($localfile in $localfiles) {

        $existfile = $false
        $uploadfile = $true

        #Verifica se o arquivo existe no destino
        if ($spaceName -eq 'personal') {
            $encodedLocalFile = [uri]::EscapeDataString($localfile.Name);
            $urlcmd = "https://$($tenant)/api/v1/qix-datafiles?name=$($encodedLocalFile)"
            $existfile = $saasfiles | Where-Object {($_.name -like $localfile.Name)}
        } else {
            #Faz o upload para a shared spaces ou para managed spaces
            $encodedLocalFile = [uri]::EscapeDataString($localfile.Name);
            $urlcmd = "https://$($tenant)/api/v1/qix-datafiles?connectionid=$($dataconnection.id)&name=$($encodedLocalFile)"
            $existfile = $saasfiles | Where-Object {($_.name -like $localfile.Name)}
        }
        if ($localfile.Length -gt $maxFileSize) {
            $localfileMb = [math]::Round(($localfile.Length / 1Mb),2)
            $MaxFileSizeMb = $maxFileSize / 1Mb
            Write-Log -Severity "Warn" -Message "The file [$($localfile.Name)] has $($localfileMb)Mb that exceeds API size limit ($($maxFileSizeMb)Mb) !";
            $existfile = $false
            $uploadfile = $false
        }

        #Se o arquivo existir, checa se é mais novo ou o parâmetro overwrited
        if ($existfile) {
            $uploadfile = $false
            if ( ($overwrite -eq 'yes') -or ($localfile.LastWriteTime -gt $existfile.modifieddate) ) {
                Write-Log -Message "Deleting SaaS file [$($localfile.Name)] in space [$spaceName] !";
                $filedelete = qlik raw delete v1/qix-datafiles/$($existfile[0].id)
                if ($?) { 
                    Write-Log -Message "File [$($localfile.Name)] deleted";
                    $uploadfile = $true
                } else {
                    Write-Log -Severity "Error" -Message "Error deleting File [$($localfile.Name)]";
                    $uploadfile = $false
                }
            }
        }
        if ($uploadfile) {
            Write-Log -Message "Uploading new File [$($localfile.Name)] to space [$spaceName] !";
            $UppedFile = curl -k -s X POST --header "Authorization: Bearer $($apikey)" --header "content-type: multipart/form-data" -F data=@"$($localfile.FullName)"  $urlcmd | ConvertFrom-Json
            if ($?) {
                $localfileMb = [math]::Round(($localfile.Length / 1Mb),2) 
                Write-Log -Message "File [$($localfile.Name)] uploaded Id [$($UppedFile.id)] size [$($localfileMb)Mb]";
            } else {
                Write-Log -Severity "Error" -Message "Error uploading File [$($localfile.Name)]";
            }
        }
    }
}

#################################################################################
###### Código principal
$Param = [pscustomobject]@{
    'spaceName' = $spaceName
    'maxFileSize' = $maxFileSize
    'fileNames' = $fileNames        
    'overwrite' = $overwrite        
    'LogFile' = $LogFile
}
$spaceName = $Param.spaceName
$maxFileSize = $Param.maxFileSize
$fileNames   = $Param.fileNames
$overwrite   = $Param.overwrite
$LogFile = $Param.LogFile

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
    Write-Log -Severity "Error" -Message "You must create files (qcs-tenant.txt) and (qcs-api_key.txt) at ~/.qlik to upload files...";
    Show-Help
    return
}
if ($fileNames -eq 'none') {
    Show-Help
    return
}

# Version <=5
# $qlikContext = qlik context get | ConvertFrom-String | where { ($_.P1 -eq 'Name:') }
# $qlikContextName = $qlikContext.P2
# Version >5
$qlikContextName = $qlikContext[0].replace(' ','').split(':')[1]

Write-Log -Message "#################################################"
###### Uploadind specified files...

Write-Log -Message "Starting uploadind files to context [$($qlikContextName)]"
Write-Log -Message "Space parameter used is [$($spaceName)]"
Write-Log -Message "Files filter used is [$($fileNames)]"
Write-Log -Message "Overwrite parameter used is [$($overwrite)]"

Up-Files

Write-Log -Message "End of uploading files."
Write-Log -Message "#################################################"

