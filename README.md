README.md
# Qlik SaaS Utils

Scripts utilitários para operar o SaaS, fazendo upload de apps, arquivos, extensões e temas, arquivos. Também possibilita apagar arquivos e usuários existentes no SaaS.

## Qlik SaaS Utils

## Table of Contents

-[Upload](#upload)

-[Upload Files](#upload_files)

-[Delete Files](#delete_files)

-[Delete Users](#delete_users)


## Upload

qlik_saas_upload.ps1

O programa qlik_saas_upload.ps1 faz o upload de vários arquivos localizados em subdiretórios determinados via linha de comando. 
- Apps: Esse programa, além de importar os apps, também cria Spaces onde eles serão publicados, publica os aplicativos para esses Spaces. Também publica pastas dos apps carregados de forma automática, evitando o processo manual.
- Arquivos: Os arquivos existentes nos subiretórios, faz upload diretamente para o SaaS.
- Extensões: As extensões são importadas para o SaaS.
- Temas: Temas também são carregados para o SaaS automaticamente.

Esse programa foi criado para permitir automatizar o processo de carga e geração de ambientes do SaaS. 

Usage:
    qlik_saas_upload -path [rootPath], -size [maxAppSize], -type [spaceType], -pub [yes|no]
        rootPath = Path wich contains directories Apps, Themes and Extensions wich contains the files to 
                   be upload
                   Any subdirectory inside Apps will be created as a Space at Qlik Context
                   default = './'
        maxAppSize = Filter Max App size during subdirectories scanning. Default = 1Gb
        spaceType = Type of Space created. 'managed' (default) or 'shared'.
                    Only for Qlik SaaS Enterprise, not used to Qlik Business.
        update = yes | no. If 'yes', the objects will be updatades. 
                 Apps will be localized by name and updated. 
                 Extensions will be deleted 
        Publish = yes | no. if 'no', the space will not be created, the apps uploaded will not be published 
                  and their sheets also will stay unpublished. 



## Upload Files

qlik_saas_upload_files.ps1

Esse programa foi escrito para realizar upload de arquivos diversos direto para o ambiente SaaS.
Basta apontar o diretório/arquivos a serem carregados e o Espaço dentro do SaaS que o programa fará a carga. Use os parâmetros de sobrescrita (overwrite) para enviar os arquivos mesmo que existam no destino ou deixe o programa verificar quem é mais novo para manter o ambiente do SaaS atualizado.

Usage:
    qlik_saas_upload_files -fileNames <fileNames> [-spaceName <spaceName>] [-confirm <yes|no>]
        fileNames = The file name to be deleted. You can use wildcards like '*' and '?' to filter files. 
                    This parameter is mandatory.
        spaceName = The Name of Space wich has the files that will be deleted. Leave it blank to use the 
                    Personal space.
                    If there are more than one space with the same name, the first will be used.
        overwrite = If yes, then SaaS files will be overwrited, even they are newer than local files. 
                    If no, only the files older than local files will be uploaded. 
                    Default is no.

    *** CAUTION: Each file is deleted before uploading and there no exists roll-back in SaaS upload files, so proceed with caution. 



## Delete Files

qlik_saas_delete_files.ps1

O programa qlik_saas_delete.ps1 apaga vários arquivos localizados em um Space do SaaS via linha de comando.

Esse programa foi criado para facilitar operar o ambiente SaaS, quando houver uma grande quantidade de arquivos e se tornar difícil a operação de limpeza de forma manual.

Usage:
    qlik_saas_delete_files -fileNames <fileNames> [-spaceName <spaceName>] [-date <date>] [-confirm <yes|no>]
        fileNames = The file name to be deleted. You can use wildcards like '*' and '?' to filter files. 
                    This parameter is mandatory.
        spaceName = The Name of Space wich has the files that will be deleted. Leave it blank to use the 
                    Personal space.
                    If there are more than one space with the same name, the first will be used.
        date      = (command not yet implemented)... Files before date will be deleted, at dd-mm-yyyy format.
                    Default is today.
        confirm   = If yes, then files will be deleted. If no, the files only will be listed at stdout. 
                    Default is no.




## Delete Users

qlik_saas_delete_users.ps1

O programa qlik_saas_delete_users.ps1 apaga vários usuários por linha de comando do ambiente SaaS.

Esse programa foi criado para facilitar operar o ambiente SaaS, quando houver uma grande quantidade de usuários e se tornar difícil a operação de limpeza de forma manual.

Usage:
    qlik_saas_delete_users -userName <userName> [-confirm <yes|no>]
        userName = The user name that will be deleted, you can use a wild card like '*', '?' to filter users. 
                    Default is 'none'.
        confirm   = If yes, then users will be deleted. If no, the users that will be deleted only will listed at
                    stdout. Default is no.


