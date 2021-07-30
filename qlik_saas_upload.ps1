###### Parametros da aplicação
Param (
    [Parameter()][alias("path")][string]$rootPath   = './',           #Diretório raiz
    [Parameter()][alias("size")][int]$maxFileSize   = 500Mb,          #TamMáximo da App --> Parametro importante para diferir do QSB ou QSaaS
    [Parameter()][alias("type")][string]$spaceType = 'managed',       #Tipo de space a ser criado
    [Parameter()][alias("upfile")][string]$update = 'no',             #Determina se os arquivos serão atualizados ou substituídos em caso das extensões e themas
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
    $line | Export-Csv -Path ./qlik_saas_upload.log -Append -NoTypeInformation
}

function PowerVersion {
    $version = $PSVersionTable.PSVersion
    Return ($version.Major -lt 7) 
}

function Show-Help {
    $helpMessage = "
    
qlik_saas_upload is a command line that you can upload multiple apps, extensions and themes to a qlik saas tenant with one command line.

Instructions:
    The root path must to contain subdirectories named Apps, Extensions and/or Themes to upload files.
    Apps has to contains subdirectories with QVF|QVW files to be uploaded. The Apps subdirectories will 
    be created as spaces at Qlik SaaS and the QVF|QVW files will be published or moved to them, depends 
    on spaceType parameter.
    All the apps and theirs sheets will be published by default.
    Themes and Extensions has to contain ZIP files with the extensions and themes.
    You need to create and select the Qlik tenant before use this command, using qlik context.

Usage:
    qlik_saas_upload -path [rootPath], -size [maxFileSize], -type [spaceType], -pub [yes|no]
        rootPath = Path wich contains directories Apps, Themes and Extensions wich contains the files to 
                   be upload
                   Any subdirectory inside Apps will be created as a Space at Qlik Context
                   default = './'
        maxFileSize = Filter Max file size during subdirectories scanning. Default = 500Mb
        spaceType = Type of Space created. 'managed' (default) or 'shared'.
                    Only for Qlik SaaS Enterprise, not used to Qlik Business.
        update = yes | no. If 'yes', the objects will be updatades. 
                 Apps will be localized by name and updated. 
                 Extensions will be deleted 
        Publish = yes | no. if 'no', the space will not be created, the apps uploaded will not be published 
                  and their sheets also will stay unpublished. 
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

## Function in development...
function Up-Apps {

    #Lista os subdiretórios do diretório raiz das aplicações
    #Cada subdiretório se torna um Space, shared ou managed, conforme parâmetro
    $apps = gci $dirApps -Directory
    #Carrega as apps a partir dos subdiretórios
    foreach ($subDirectory in $apps) {
        #Lista os espaços existentes no servidor
        $subDirectoryName = $subDirectory.Name
        $spaces = qlik space filter --names "$subDirectoryName" | ConvertFrom-Json
        if (($spaces.name -ne $subDirectory.Name) -and ($Publish -ne "no")) {
                #Cria os espaços no servidor
                Write-Log -Message "Creating $($spaceType) Space [$subDirectoryName]"
                qlik space create --name "$subDirectoryName" --description "Space created by automated upload script" --type "$spaceType" | Out-Null;
                if ($?) {
                    Write-Log -Message "Space [$subDirectoryName] Created !";
                } Else {
                    Write-Log -Severity "Error" -Message "Error create Space [$subDirectoryName]";
                }
        }

        $files = gci $dirApps/$subDirectoryName/*.qv[f-w] -File | Where-Object -FilterScript {($_.Length -le $maxFileSize)}
        foreach ($file in $files) {
            #Faz o upload para a shared spaces ou para managed spaces
            $space = qlik space filter --names "$subDirectoryName" | ConvertFrom-Json

            Write-Log -Message "Uploading new app [$($file.BaseName)]";
            $UppedApp = qlik app import -f "$($file)" --fallbackName "$file.Name" | ConvertFrom-Json;
            if ($?) { 
                Write-Log -Message "File [$($file.BaseName)] uploaded Id [$($UppedApp.attributes.id)]";
                #Publica as pastas da aplicação
                if ($Publish -ne "no") {
                    #$sheetsApp = qlik app object ls -a "$($UppedApp.resourceId)" | ConvertFrom-String | where { ($_.P2 -eq 'sheet') -or ($_.P2 -eq 'bookmark')}
                    $sheetsApp = (qlik app object ls -a "$($UppedApp.attributes.id)").Trim() -replace '\s{2,}', ',' | ConvertFrom-Csv | where { ($_.Type -eq 'sheet') -or ($_.Type -eq 'bookmark')}
                    foreach ($sheet in $sheetsApp) {
                        Write-Log -Message "Publishing Sheet id [$($sheet.ID)] from app [$($File.BaseName)]";
                        $PublishedSheet = qlik app object publish "$($sheet.ID)" -a "$($UppedApp.attributes.id)"
                        if ($?) { 
                            Write-Log -Message "Object [$($sheet.ID)] type [$($sheet.Type)] published at app Id [$($UppedApp.attributes.id)]";
                        } else { 
                            Write-Log -Severity "Error" -Message "Error publishing Object [$($sheet.ID)] type [$($sheet.Type)] at app Id [$($UppedApp.attributes.id)]";
                        }
                    }
                    if ($space.type -eq "shared") {
                        #Para Shared Spaces deve-se mover as apps para o espaço shared
                        Write-Log -Message "Moving [$($file.BaseName)] id [$($UppedApp.attributes.id)] to Shared Space [$($space.name)] Id [$($space.id)]";
                        $PublishedApp = qlik app space update "$($UppedApp.attributes.id)" --spaceId "$($space.id)" | ConvertFrom-Json;
                        #Write-Log -Message "$($PublishedApp.attributes)";
                        if ($?) { 
                            Write-Log -Message "App [$($UppedApp.attributes.id)] moved at Shared Space Id [$($space.id)]";
                        } else { 
                            Write-Log -Severity "Error" -Message "Error moving app [$($UppedApp.attributes.id)] to a Shared Space Id [$($space.id)]";
                        }
                    } else {
                        #Para Managed Spaces deve-se publicar as apps
                        Write-Log -Message "Publishing App [$($file.BaseName)] Id [$($UppedApp.attributes.id)] to Managed Space [$($space.name)] Id [$($space.id)]";
                        $PublishedApp = qlik app publish create "$($UppedApp.attributes.id)" --spaceId "$($space.id)";
                        if ($?) { 
                            Write-Log -Message "App [$($UppedApp.attributes.id)] published at Managed Space Id [$($space.id)]";
                        } else { 
                            Write-Log -Severity "Error" -Message "Error publishing app [$($UppedApp.attributes.id)] to a Managed Space Id [$($space.id)]";
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
    $files = gci $dirExts/*.zip -File 
    foreach ($file in $files)
    {
        #Verifica se a extensão existe e atualiza caso exista
        $Extension = qlik extension ls | ConvertFrom-Json | where-object { ($_.file.originalname -eq "$($file.FullName)") };
        if (($Extension.file.originalname -eq "$($file.FullName)" ) ) {
            Write-Log -Message "Updating existing extension [$($file.BaseName)]"
            $UppedExt = qlik extension patch "$($Extension.id)"-f "$($file.FullName)" | ConvertFrom-Json
            if ($?) {
                Write-Log -Message "Extension [$($UppedExt.Name)] updated !";
            } Else {
                Write-Log -Severity "Error" -Message "Error updating extension [$($file.BaseName)]";
            }
        } else {
            #Faz upload da extensão
            Write-Log -Message "Uploading new Extension [$($file.BaseName)]"
            $UppedExt = qlik extension create -f "$($file.FullName)" | ConvertFrom-Json
            if ($?) { 
                Write-Log -Message "File [$($file.BaseName)] uploaded Id [$($UppedExt.id)] ";
            } else {
                Write-Log -Severity "Error" -Message "Error uploading extension [$($file.BaseName)]";
            }            
        }
    }
}




Function Up-Themes {
    ###### Faz upload dos Temas
    #Lista os arquivos do diretório dos temas
    $files = gci $dirThemes/*.zip -File 
    foreach ($file in $files)
    {
        #Verifica se o tema existe e atualiza caso exista
        $Theme = qlik theme ls | ConvertFrom-Json | where-object { ($_.file.originalname -eq "$($file.FullName)") };
        if (($Theme.file.originalname -eq "$($file.FullName)" ) ) {
            Write-Log -Message "Updating existing theme [$($file.BaseName)]"
            $UppedTheme = qlik theme patch "$($Theme.id)"-f "$($file.FullName)" | ConvertFrom-Json
            if ($?) {
                Write-Log -Message "Theme [$($UppedTheme.Name)] updated !";
            } Else {
                Write-Log -Severity "Error" -Message "Error updating theme [$($file.BaseName)]";
            }
        } else {
            #Faz upload do tema
            Write-Log -Message "Uploading new Theme [$($file.BaseName)]"
            $UppedTheme = qlik theme create -f "$($file.FullName)" | ConvertFrom-Json
            if ($?) { 
                Write-Log -Message "File [$($file.BaseName)] uploaded Id [$($UppedTheme.id)]";
            } else {
                Write-Log -Severity "Error" "Error Upload Theme [$($file.BaseName)]";
            }
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
if ($rootPath -notmatch '\/$') { $rootPath += '/' }
$dirApps   = $rootPath+'Apps'       #Diretório raiz das aplicações
$dirThemes = $rootPath+'Themes'     #Diretório raiz dos temas
$dirExts   = $rootPath+'Extensions' #Diretório raiz das extensões
$dirFiles  = $rootPath+'Files'      #Diretório raiz dos arquivos de dados

# Version <=5
# $qlikContext = qlik context get | ConvertFrom-String | where { ($_.P1 -eq 'Name:') }
# $qlikContextName = $qlikContext.P2
# Version >5
$qlikContext = qlik context get
$qlikContextName = $qlikContext[0].replace(' ','').split(':')[1]
If (!(test-path $dirApps) -and !(test-path $dirThemes) -and !(test-path $dirExts)) {
    Write-Log -Severity "Error" -Message "Error You must create at least one subdirectory called Apps, Extensions or Themes, below [$($rootPath)] to upload files...";
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
###### Faz upload das Aplicações, cria e publica os Spaces

Write-Log -Message "Starting uploading files to context [$($qlikContextName)]"
If((test-path $dirApps))    { Write-Log -Message "Application (QVF | QVW) directory used is [$($dirApps)]"    } else { Write-Log -Severity 'Warn' -Message "No apps directory found"}
If((test-path $dirThemes))  { Write-Log -Message "Themes (zip) directory used is [$($dirThemes)]"       } else { Write-Log -Severity 'Warn' -Message "No themes directory found"}
If((test-path $dirExts))    { Write-Log -Message "Extensions (zip) directory used is [$($dirExts)]"     } else { Write-Log -Severity 'Warn' -Message "No extensions directory found"}
Write-Log -Message "Publishing parameter used is [$($Publish)]"
Write-Log -Message "Updating parameter used is [$($update)]"

If((test-path $dirApps)) { Up-Apps }
If((test-path $dirThemes)) { Up-Themes }
If((test-path $dirExts)) { Up-Extensions }

Write-Log -Message "End of uploading files."
Write-Log -Message "#################################################"
