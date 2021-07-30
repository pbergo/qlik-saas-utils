﻿###### Parametros da aplicação
Param (
    [Parameter()][alias("space")][string]$spaceName = 'personal',               #Espaço a ser utilizado.
    [Parameter()][alias("files")][string]$fileNames = 'none',                    #Arquivos a serem eliminados
    [Parameter()][alias("date")][string]$dateFiles  = (Get-Date).DateTime,      #Data a ser utilizada
    [Parameter()][alias("conf")][string]$confirm    = 'no'                      #Determina se executa ou não o comando
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
    $line | Export-Csv -Path .\qlik_saas_delete.log -Append -NoTypeInformation
}

function Show-Help {
    $helpMessage = "
    
qlik_saas_delete is a command line that you can delete multiple data files inside any authorized SaaS Space of your tenant.

Instructions:
    The space must contain the name of SaaS Space wich has the files that will be deleted. You can specify
    the name files and / or older files date to date parameter, writed in dd-mm-yyy format.

    If you set the Confirm parameter to 'no', nothing will be done, just the file names will be listed.

Usage:
    qlik_saas_delete -fileNames <fileNames> [-spaceName <spaceName>] [-date <date>] [-confirm <yes|no>]
        fileNames = The file name to be deleted. You can use wildcards like '*' and '?' to filter files. 
                    This parameter is mandatory.
        spaceName = The Name of Space wich has the files that will be deleted. Leave it blank to use the 
                    Personal space.
                    If there are more than one space with the same name, the first will be used.
        date      = (command not yet implemented)... Files before date will be deleted, at dd-mm-yyyy format.
                    Default is today.
        confirm   = If yes, then files will be deleted. If no, the files only will be listed at stdout. 
                    Default is no.
    "
    Write-Output $helpMessage
    return
}

function PowerVersion {
    $version = $PSVersionTable.PSVersion
    Return ($version.Major -lt 7) 
}


function DeleteSpaceDataFiles {
    #Localiza os espaços existentes no servidor
    $spaces = qlik space filter --names "$spaceName" | ConvertFrom-Json
    if (($?) -or ($spaceName -eq 'personal')) {
        #Trata as conexões do espaço personal
        if ($spaceName -eq 'personal') {
            Write-Log -Message "Using space Personal !";
            $dataconnection = qlik raw get v1/data-connections | ConvertFrom-Json | Where-Object { ($_.qName -eq 'DataFiles') -and ($_.space -eq $null) }
        } else {
            Write-Log -Message "Using space [$spaceName] ID [$($spaces.id)] !";
            $dataconnection = qlik raw get v1/data-connections --query space="$($spaces.id)" | ConvertFrom-Json | Where-Object {$_.qName -eq 'DataFiles' }
        }
        if ($?) {
            Write-Log -Message "Reading files from [$spaceName] ID [$($spaces.id)]... !";
            $listfiles = qlik raw get v1/qix-datafiles --query connectionId="$($dataconnection.id)",top=100000 | ConvertFrom-Json | Where-Object {$_.name -like $fileNames}

            # O comando devolve 100000 registros, então faz a paginação até terminar de apagar os arquivos
            while ( $($listfiles.Length) -ge 1) {
                foreach ($file in $listfiles) {
                    if ($confirm -eq 'yes') {
                        Write-Log "Deleting file [$($file.name)] id [$($file.id)]...";
                        $filedelete = qlik raw delete v1/qix-datafiles/$($file.id)
                        if ($?) {
                            Write-Log -Message "File [$($file.name)] deleted...";
                        } Else {
                            Write-Log -Severity "Error" -Message "Error deleting file [$($file.name)] id [$($file.id)]...";
                        }
                    } Else {
                            Write-Log -Message "Testing deleting file [$($file.name)] id [$($file.id)]...";
                    }
                }
                if ($confirm -ne 'yes') {
                    return
                } Else {
                    $listfiles = qlik raw get v1/qix-datafiles --query connectionId="$($dataconnection.id)",top=100000 | ConvertFrom-Json | Where-Object {$_.name -like $fileNames}
                    #Write-Host 'Next page'
                }
            }
        }
    } Else {
        Write-Log -Severity "Error" -Message "Error Space [$spaceName] not exists !";
    }
}


###### Código principal
#Validações iniciais

#Check if exists context
$qlikContext = (qlik context get)[0].replace(' ','').split(':')[1]
if ($qlikContext -eq 'No current context'){
    Write-Log -Severity 'Error' -Message "Error You must create and select a context to upload files";
    Show-Help
    return
}
if ($fileNames -eq 'none') {
    Show-Help
    return
}

if ( PowerVersion ) {
    $message = "
    *********************************************************************************************

    Wrong version... This command only works with Powershell >= 7. 

    Please download a newer PowerShell version at https://docs.microsoft.com/pt-br/powershell/

    *********************************************************************************************"
    Write-Log -Severity 'Error' -Message $message;
    return
}


Write-Log -Message "#################################################"
###### Delete specified files...

Write-Log -Message "Starting deleting files from context [$($qlikContext)]"
DeleteSpaceDataFiles

Write-Log -Message "End of deleting files."
Write-Log -Message "#################################################"
