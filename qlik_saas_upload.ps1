###### Parametros da aplicação
Param (
    [Parameter()][alias("path")][string]$rootPath   = '.\',            #Diretório raiz
    [Parameter()][alias("size")][int]$maxFileSize   = 500Mb,           #TamMáximo da App --> Parametro importante para diferir do QSB ou QSaaS
    [Parameter()][alias("type")][string]$spaceType = 'managed',        #Tipo de space a ser criado
    [Parameter()][alias("pub")][string]$Publish   = 'yes'             #Determina se fara a publicação das pastas ou apps
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
    $line | Export-Csv -Path .\qlik_saas_upload.log -Append -NoTypeInformation
}

function Show-Help {
    $helpMessage = "
    
qlik_saas_upload is a command line that you can upload multiple apps, extensions and themes to a qlik saas tenant with one command line.

Instructions:
    The root path must to contain subdirectories named Apps, Extensions and/or Themes to upload files.
    Apps has to contains subdirectories with QVF|QVW files to be uploaded. The Apps subdirectories will 
    be created as spaces at Qlik SaaS and the QVF|QVW files will be published or moved to them, depends 
    on spaceType parameter. 
    All the apps and theirs sheets will be published by default, depends on Publish param.
    Themes and Extensions has to contain ZIP files with the extensions and themes.
    You need to create and select the Qlik tenant before use this command, using qlik context.

Usage:
    qlik_saas_upload -path [rootPath], -size [maxFileSize], -sptype [spaceType], -pub [yes|no]
        rootPath = Path wich contains directories Apps, Themes and Extensions wich contains the files to 
                   be upload
                   Any subdirectory inside Apps will be created as a Space at Qlik Context
                   default = '.\'
        maxFileSize = Filter Max file size during subdirectories scanning. Default = 500Mb
        spaceType = Type of Space created. 'managed' (default) or 'shared'.
                    Only for Qlik SaaS Enterprise, not used to Qlik Business.
        Publish = yes | no. if 'no', the space will not be created, the apps uploaded will not be published and their sheets also will stay unpublished. 
    "
    Write-Output $helpMessage
    return
}


function Up-Apps {
    #Lista os subdiretórios do diretório raiz das aplicações
    #Cada subdiretório se torna um Space, shared ou managed, conforme parâmetro
    $apps = gci $dirApps -Directory
    #Carrega as apps a partir dos subdiretórios
    foreach ($subDirectory in $apps) {
        #Lista os espaços existentes no servidor
        $spaces = qlik space filter --names "$subDirectory" | ConvertFrom-Json
        if (($spaces.name -ne $subDirectory) -and ($Publish -ne "no")) {
                #Cria os espaços no servidor
                Write-Log -Message "Creating $($spaceType) Space [$subDirectory]"
                qlik space create --name "$subDirectory" --description "Space created by upload automated" --type "$spaceType" | Out-Null;
                if ($?) {
                    Write-Log -Message "Space [$subDirectory] Created !";
                } Else {
                    Write-Log -Severity "Error" -Message "Error create Space [$subDirectory]";
                }
        }

        $files = gci $dirApps\$subDirectory\*.qv[f-w] -File | Where-Object -FilterScript {($_.Length -le $maxFileSize)}
        foreach ($file in $files) {
            #Faz o upload para a shared spaces ou para managed spaces
            $space = qlik space filter --names "$subDirectory" | ConvertFrom-Json

            Write-Log -Message "Uploading [$($file.BaseName)]";
            $UppedApp = qlik app import -f "$($file)" --fallbackName "$file.Name" | ConvertFrom-Json;
            if ($?) { 
                Write-Log -Message "File [$($file.BaseName)] uploaded Id [$($UppedApp.resourceId)]";
                #Publica as pastas da aplicação
                if ($Publish -ne "no") {
                    $sheetsApp = qlik app object ls -a "$($UppedApp.resourceId)" | ConvertFrom-String | where { ($_.P2 -eq 'sheet') -or ($_.P2 -eq 'bookmark')}
                    foreach ($sheet in $sheetsApp) {
                        Write-Log -Message "Publishing Sheet id [$($sheet.P1)] from app [$($File.BaseName)]";
                        qlik app object publish "$($sheet.P1)" -a "$($UppedApp.resourceId)"
                        if ($?) { 
                            Write-Log -Message "Object [$($sheet.P1)] type [$($sheet.P2)] published at app Id [$($UppedApp.resourceId)]";
                        } else { 
                            Write-Log -Severity "Error" -Message "Error publishing Object [$($sheet.P1)] type [$($sheet.P2)] at app Id [$($UppedApp.resourceId)]";
                        }
                    }
                    if ($space.type -eq "shared") {
                        #Para Shared Spaces deve-se mover as apps para o espaço shared
                        Write-Log -Message "Moving [$($file.BaseName)] to Shared Space [$($space.name)] Id [$($space.Id)]";
                        $PublishedApp = qlik app space update "$($UppedApp.resourceId)" --spaceId "$($space.Id)" | ConvertFrom-Json;
                        if ($?) { 
                            Write-Log -Message "App [$($UppedApp.resourceId)] moved at Shared Space Id [$($space.id)]";
                        } else { 
                            Write-Log -Severity "Error" -Message "Error moving app [$($UppedApp.resourceId)] to a Shared Space Id [$($space.id)]";
                        }
                    } else {
                        #Para Managed Spaces deve-se publicar as apps
                        Write-Log -Message "Publishing App [$($file.BaseName)] Id [$($UppedApp.resourceId)] to Managed Space [$($space.name)] Id [$($space.Id)]";
                        $PublishedApp = qlik app publish create "$($UppedApp.resourceId)" --spaceId "$($space.id)";
                        if ($?) { 
                            Write-Log -Message "App [$($UppedApp.resourceId)] published at Managed Space Id [$($space.id)]";
                        } else { 
                            Write-Log -Severity "Error" -Message "Error publishing app [$($UppedApp.resourceId)] to a Managed Space Id [$($space.id)]";
                        }
                    }
                }
            } else {
                Write-Log -Severity "Error" -Message "Error uploading App [$($file.BaseName)]";
            }
        }
    }
}


function Up-Files {
    #Lista os subdiretórios do diretório raiz dos arquivos
    #Cada subdiretório se torna um Space, shared ou managed, conforme parâmetro
    $datafiles = gci $dirFiles -Directory
    #Carrega os arquivos a partir dos subdiretórios
    foreach ($subDirectory in $datafiles) {
        #Lista os espaços existentes no servidor
        $spaces = qlik space filter --names "$subDirectory" | ConvertFrom-Json
        if (($spaces.name -ne $subDirectory) -and ($Publish -ne "no")) {
                #Cria os espaços no servidor
                Write-Log -Message "Creating $($spaceType) Space [$subDirectory]"
                qlik space create --name "$subDirectory" --description "Space created by upload automated" --type "$spaceType" | Out-Null;
                if ($?) {
                    Write-Log -Message "Space [$subDirectory] Created !";
                } Else {
                    Write-Log -Severity "Error" -Message "Error create Space [$subDirectory]";
                }
        }

        $files = gci $dirApps\$subDirectory\* -File | Where-Object -FilterScript {($_.Length -le $maxFileSize)}
        foreach ($file in $files) {
            #Faz o upload para a shared spaces ou para managed spaces
            $space = qlik space filter --names "$subDirectory" | ConvertFrom-Json

            Write-Log -Message "Uploading [$($file.BaseName)]";
            $UppedApp = qlik app import -f "$($file)" --fallbackName "$file.Name" | ConvertFrom-Json;
            if ($?) { 
                Write-Log -Message "File [$($file.BaseName)] uploaded Id [$($UppedApp.resourceId)]";
                #Publica as pastas da aplicação
                if ($Publish -ne "no") {
                    $sheetsApp = qlik app object ls -a "$($UppedApp.resourceId)" | ConvertFrom-String | where { ($_.P2 -eq 'sheet') -or ($_.P2 -eq 'bookmark')}
                    foreach ($sheet in $sheetsApp) {
                        Write-Log -Message "Publishing Sheet id [$($sheet.P1)] from app [$($File.BaseName)]";
                        qlik app object publish "$($sheet.P1)" -a "$($UppedApp.resourceId)"
                        if ($?) { 
                            Write-Log -Message "Object [$($sheet.P1)] type [$($sheet.P2)] published at app Id [$($UppedApp.resourceId)]";
                        } else { 
                            Write-Log -Severity "Error" -Message "Error publishing Object [$($sheet.P1)] type [$($sheet.P2)] at app Id [$($UppedApp.resourceId)]";
                        }
                    }
                    if ($space.type -eq "shared") {
                        #Para Shared Spaces deve-se mover as apps para o espaço shared
                        Write-Log -Message "Moving [$($file.BaseName)] to Shared Space [$($space.name)] Id [$($space.Id)]";
                        $PublishedApp = qlik app space update "$($UppedApp.resourceId)" --spaceId "$($space.Id)" | ConvertFrom-Json;
                        if ($?) { 
                            Write-Log -Message "App [$($UppedApp.resourceId)] moved at Shared Space Id [$($space.id)]";
                        } else { 
                            Write-Log -Severity "Error" -Message "Error moving app [$($UppedApp.resourceId)] to a Shared Space Id [$($space.id)]";
                        }
                    } else {
                        #Para Managed Spaces deve-se publicar as apps
                        Write-Log -Message "Publishing App [$($file.BaseName)] Id [$($UppedApp.resourceId)] to Managed Space [$($space.name)] Id [$($space.Id)]";
                        $PublishedApp = qlik app publish create "$($UppedApp.resourceId)" --spaceId "$($space.id)";
                        if ($?) { 
                            Write-Log -Message "App [$($UppedApp.resourceId)] published at Managed Space Id [$($space.id)]";
                        } else { 
                            Write-Log -Severity "Error" -Message "Error publishing app [$($UppedApp.resourceId)] to a Managed Space Id [$($space.id)]";
                        }
                    }
                }
            } else {
                Write-Log -Severity "Error" -Message "Error uploading App [$($file.BaseName)]";
            }
        }
    }
}


Function Up-Extensions {
    ###### Faz upload das Extensões
    #Lista os arquivos do diretório das extensões
    $files = gci $dirExts\*.zip -File 
    foreach ($file in $files)
    {
        #Faz upload da extensão
        Write-Log -Message "Uploadind Extension [$($file.BaseName)]"
        $UppedExt = qlik extension create -f "$($file.FullName)" | ConvertFrom-Json
        if ($?) { 
            Write-Log -Message "File [$($file.BaseName)] uploaded Id [$($UppedExt.id)] ";
        } else {
            Write-Log -Severity "Error" -Message "Erro Upload Extensão [$($file.BaseName)]";
        }
    }
}




Function Up-Themes {
    ###### Faz upload dos Temas
    #Lista os arquivos do diretório dos temas
    $files = gci $dirThemes\*.zip -File 
    foreach ($file in $files)
    {
        #Faz upload do tema
        Write-Log -Message "Uploadind Theme [$($file.BaseName)]"
        $UppedTheme = qlik theme create -f "$($file.FullName)" | ConvertFrom-Json
        if ($?) { 
            Write-Log -Message "File [$($file.BaseName)] uploaded Id [$($UppedTheme.id)]";
        } else {
            Write-Log -Severity "Error" "Erro Upload Theme [$($file.BaseName)]";
        }
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
if ($rootPath -notmatch '\\$') { $rootPath += '\' }
$dirApps   = $rootPath+'Apps'       #Diretório raiz das aplicações
$dirThemes = $rootPath+'Themes'     #Diretório raiz dos temas
$dirExts   = $rootPath+'Extensions' #Diretório raiz das extensões
$dirFiles  = $rootPath+'Files'      #Diretório raiz dos arquivos de dados
$qlikContext = qlik context get | ConvertFrom-String | where { ($_.P1 -eq 'Name:') }
If (!(test-path $dirApps) -and !(test-path $dirThemes) -and !(test-path $dirExts)) {
    Write-Log -Severity "Error" -Message "Error You must create at least one subdirectory called Apps, Extensions or Themes, below [$($rootPath)] to upload files...";
    Show-Help
    return
} 

Write-Log -Message "#################################################"
###### Faz upload das Aplicações, cria e publica os Spaces

Write-Log -Message "Starting uploading files to context [$($qlikContext.P2)]"
If((test-path $dirApps))    { Write-Log -Message "Application (QVF | QVW) directory used is [$($dirApps)]"    } else { Write-Log -Severity 'Warn' -Message "No apps directory found"}
If((test-path $dirThemes))  { Write-Log -Message "Themes (zip) directory used is [$($dirThemes)]"       } else { Write-Log -Severity 'Warn' -Message "No themes directory found"}
If((test-path $dirExts))    { Write-Log -Message "Extensions (zip) directory used is [$($dirExts)]"     } else { Write-Log -Severity 'Warn' -Message "No extensions directory found"}
Write-Log -Message "Publishing parameter used is [$($Publish)]"

If((test-path $dirApps)) { Up-Apps }
If((test-path $dirThemes)) { Up-Themes }
If((test-path $dirExts)) { Up-Extensions }

Write-Log -Message "End of uploading files."
Write-Log -Message "#################################################"
