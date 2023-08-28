#################################################################################
#
# qlik_saas_delete_users
#
# Delete Users from SaaS
#
# (c) Pedro Bergo - pedroabergo@gmail.com - 2023
#
# PowerShell 7.2.13
# qlik-cli 2.22.13
#
#################################################################################

###### Parametros da aplicação
Param (
    [Parameter()][alias("user")][string]$userName = 'none',                      #Usuários a serem eliminados
    [Parameter()][alias("email")][string]$emailName = 'none',                    #emails dos Usuários a serem eliminados
    [Parameter()][alias("conf")][string]$confirm    = 'no',                        #Determina se executa ou não o comando
    [Parameter()][string]$LogFile = '.\' + (Get-Item $PSCommandPath).BaseName + '.log'        # Log file name and path)
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

function PowerVersion {
    $version = $PSVersionTable.PSVersion
    Return ($version.Major -lt 7) 
}

function Show-Help {
    $helpMessage = "
    
$((Get-Item $PSCommandPath).BaseName) is a command line to delete multiple users of your Qlik SaaS tenant.

Instructions:
    You need to specify the name or e-mail to delete the users.

    If you set the Confirm parameter to 'no', nothing will be done, just the users names will be listed. 

Usage:
    $((Get-Item $PSCommandPath).BaseName) [-userName <userName>] [-emailName <email>] [-confirm <yes|no>]  [-LogFile <Logfile path and name>]
        userName = The user name that will be deleted, you can use a wild card like '*', '?' to filter users. 
                    Default is 'none'.
        emailName = The email that will be deleted, you can use a wild card like '*', '?' to filter users. 
                    Default is 'none'.
        confirm   = If yes, then users will be deleted. If no, the users that will be deleted only will listed at
                    stdout. Default is no.
        LogFile   = Logfile path and name. 
                    Default is .\" + (Get-Item $PSCommandPath).BaseName + ".log
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


#################################################################################
###### Código principal
$Param = [pscustomobject]@{
    'userName' = $userName
    'emailName' = $emailName
    'dateFiles' = $dateFiles        
    'confirm' = $confirm        
}
$userName = $Param.userName
$emailName = $Param.emailName
$confirm   = $Param.confirm
$LogFile = $Param.LogFile

#Validações iniciais
if ( PowerVersion ) {
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
    Write-Log -Severity 'Error' -Message "Error You must create and select a context to upload files";
    Show-Help
    return
}
$qlikContextName = (qlik context get)[0].replace(' ','').split(':')[1]

if (($userName -eq 'none') -and ($emailName -eq 'none')) {
    Show-Help
    return
}

Write-Log -Message "#################################################"
###### Delete specified users...

Write-Log -Message "Starting deleting users from context [$qlikContextName]"
Write-Log -Message "Users filter used is [$($userName)]"
Write-Log -Message "Email filter used is [$($userName)]"
Write-Log -Message "Confirm parameter used is [$($confirm)]"

DeleteUsers

Write-Log -Message "End of deleting users."
Write-Log -Message "#################################################"
