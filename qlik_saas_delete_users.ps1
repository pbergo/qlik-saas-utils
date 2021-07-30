﻿###### Parametros da aplicação
Param (
    [Parameter()][alias("users")][string]$userName = 'nonexx',                    #Usuários a serem eliminados
    [Parameter()][alias("emails")][string]$emailName = 'nonexx',                  #emails dos Usuários a serem eliminados
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
    $line | Export-Csv -Path .\qlik_saas_delete_users.log -Append -NoTypeInformation
}

function Show-Help {
    $helpMessage = "
    
qlik_saas_delete_users is a command line that you can delete multiple users at any authorized SaaS Tenant of your tenant.

Instructions:
    You need to determine the name or e-mail to delete the users.

    If you set the Confirm parameter to no, nothing will be done, just the users names will be listed. 

Usage:
    qlik_saas_delete_users -userName <userName> [-confirm <yes|no>]
        userName = The user name that will be deleted, you can use a wild card like '*', '?' to filter users. 
                    Default is 'none'.
        confirm   = If yes, then users will be deleted. If no, the users that will be deleted only will listed at
                    stdout. Defaul is no.
    "
    Write-Output $helpMessage
    return
}


function DeleteUsers {
    #Localiza os espaços existentes no servidor
    Write-Log -Message "Deleting users... !";
    $usersList = qlik user ls --limit 1000 --fields "name,email" | ConvertFrom-Json | Where-Object {($_.name -like "$($userName)") -or ($_.email -like "$($emailName)") }

    # O comando devolve 100 registros, então faz a paginação até terminar de apagar os arquivos
    while ( $($usersList.Length) -ge 1) {
        foreach ($user in $usersList) {
            Write-Log "Deleting user $($user.name)...";
            if ($confirm -eq 'yes') {
                $userdelete = qlik user rm $($user.id)
                if ($?) {
                    Write-Log -Message "User $($user.name) id $($user.id) deleted...";
                } Else {
                    Write-Log -Severity "Error" -Message "Error deleting user $($user.name) id $($user.id)...";
                }
            } Else {
                    Write-Log -Message "Testing deleting user $($user.name) id $($user.id)...";
            }
        }
        if ($confirm -ne 'yes') {
            return
        } Else {
            $usersList = qlik user ls --limit 1000 --fields "name,email" | ConvertFrom-Json | Where-Object {$_.name -like "$($userName)" }
            Write-Host 'Next page'
        }
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

Write-Log -Message "#################################################"
###### Delete specified users...

Write-Log -Message "Starting deleting users from context [$qlikContext]"
DeleteUsers

Write-Log -Message "End of deleting users."
Write-Log -Message "#################################################"