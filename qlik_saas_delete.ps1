###### Parametros da aplicação
Param (
    [Parameter()][alias("space")][string]$spaceName = 'Personal',               #Espaço a ser utilizado.
    [Parameter()][alias("files")][string]$fileNames = '*',                      #Arquivos a serem eliminados
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
    The space must contain the name of SaaS Space wich has the files that will be deleted, you can specify
    the name files and / or older files date to date parameter, writed in dd-mm-yyy format.

    If you set the testCmd parameter to no, nothing will be done, just the file names will be listed. 

Usage:
    qlik_saas_delete -spaceName <spaceName> [-fileNames <fileNames>] [-date <date>] [-confirm <yes|no>]
        spaceName = The Name of Space wich has the files that will be deleted. Today we can't delete files from
                    Personal Space.
                    If there are more than one space with the same name, the first will be used.
        fileNames = The file deletion will use a wild card, you can use '*', '?' to filter files that will
                    be deleted. Defaul is '*'.
        date      = (command not yet implemented)... Files before date will be deleted, at dd-mm-yyyy format.
                    Today is default. 
        confirm   = If yes, then files will be delete. If no, the files that will be deleted only will listed at
                    stdout. Defaul is no.
    "
    Write-Output $helpMessage
    return
}


function DeleteSpaceDataFiles {
    #Localiza os espaços existentes no servidor
    $spaces = qlik space filter --names "$spaceName" | ConvertFrom-Json
    if ($?) {
        Write-Log -Message "Space [$spaceName] ID [$($spaces.id)] localized !";
        $dataconnection = qlik raw get v1/data-connections --query space="$($spaces.id)" | ConvertFrom-Json | Where-Object {$_.qName -eq 'DataFiles' }
        if ($?) {
            Write-Log -Message "Deleting files from [$spaceName] ID [$($spaces.id)]... !";
            $listfiles = qlik raw get v1/qix-datafiles --query connectionId="$($dataconnection.id)",top=100000 | ConvertFrom-Json | Where-Object {$_.name -like $fileNames}

            # O comando devolve 100000 registros, então faz a paginação até terminar de apagar os arquivos
            while ( $($listfiles.Length) -gt 1) {
                foreach ($file in $listfiles) {
                    Write-Log "Deleting file $($file.name)...";
                    if ($confirm -eq 'yes') {
                        $filedelete = qlik raw delete v1/qix-datafiles/$($file.id)
                        if ($?) {
                            Write-Log -Message "File $($file.name) id $($file.id) deleted...";
                        } Else {
                            Write-Log -Severity "Error" -Message "Error deleting file $($file.name) id $($file.id)...";
                        }
                    } Else {
                            Write-Log -Message "Testing deleting file $($file.name) id $($file.id)...";
                    }
                }
                if ($confirm -ne 'yes') {
                    return
                } Else {
                    $listfiles = qlik raw get v1/qix-datafiles --query connectionId="$($dataconnection.id)",top=100000 | ConvertFrom-Json | Where-Object {$_.name -like $fileNames}
                    Write-Host 'Next page'
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
$qlikContext = qlik context get 
if ($qlikContext -eq 'No current context'){
    Write-Log -Severity 'Error' -Message "Error You must create and select a context to upload files";
    Show-Help
    return
}
if ($spaceName -eq 'Personal') {
    Show-Help
    return
}

Write-Log -Message "#################################################"
###### Delete specified files...

Write-Log -Message "Starting deleting files from context [$($qlikContext.P2)]"
DeleteSpaceDataFiles

Write-Log -Message "End of deleting files."
Write-Log -Message "#################################################"
