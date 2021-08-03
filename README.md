

README.md
# Qlik SaaS Utils
Scripts utilitários para operar o SaaS, fazendo upload de apps, arquivos, extensões e temas, arquivos.

Também possibilita apagar arquivos e usuários existentes no SaaS.

## Qlik SaaS Utils

### Table of Contents

-[Upload](#upload)

-[Upload Files](#upload_files)

-[Delete Files](#delete_files)

-[Delete Users](#delete_users)

-[Instalação](#instalation)


### Upload

qlik_saas_upload.ps1

O script qlik_saas_upload.ps1 faz o upload de vários arquivos localizados em subdiretórios determinados via linha de comando. 

Você pode subir Aplicativos (QVF), Arquivos (QVDs, XLSX, etc.), Extensões e Themas diretamente para o SaaS a partir de diretórios locais. Cada diretório local vira um Space dentro do SaaS e você ainda pode definir se ele será criado como 'Shared' ou 'Managed'. 

O script ainda publica as pastas das Apps carregadas, o que ajuda muito na hora de criar ambiente iniciais ou mesmo para atualizar aqueles existentes.

Esse programa foi criado para permitir automatizar o processo de carga e geração de ambientes do SaaS. 

**Sintaxe:**

    qlik_saas_upload -path [rootPath], -size [maxAppSize], -type [spaceType], -pub [yes|no]
        rootPath   = Path wich contains directories Apps, Themes and Extensions wich
                     contains the files to be upload. Any subdirectory inside Apps
                     will be created as a Space at Qlik Context. Default = './'
        maxAppSize = Filter Max App size during subdirectories scanning. 
                     Default = 1Gb
        spaceType =  Type of Space created. 'managed' (default) or 'shared'. Only
                     for Qlik SaaS Enterprise, not used to Qlik Business.
        update    =  yes | no. If 'yes', the objects will be updatades. Apps will
                     be localized by name and updated. Extensions will be deleted 
        Publish   =  yes | no. Default is 'yes' and it publish the sheets and apps.
                     if 'no', the space will not be created, the apps uploaded will
                     not be published and their sheets also will stay unpublished. 

## Upload Files

qlik_saas_upload_files.ps1

Esse script foi criado para realizar upload de arquivos diversos direto para o ambiente SaaS.

Basta apontar o diretório/arquivos a serem carregados e o Espaço dentro do SaaS que o programa fará a carga. 

Use os parâmetros de sobrescrita (overwrite) para enviar os arquivos mesmo que existam no destino ou deixe o programa verificar quem é mais novo para manter o ambiente do SaaS atualizado.

Sintaxe:

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

Criado para facilitar operar o ambiente SaaS, quando houver uma grande quantidade de arquivos e se tornar difícil a operação de limpeza de forma manual.

Sintaxe:

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

Com o script qlik_saas_delete_users.ps1 é possível apaga vários usuários por linha de comando do ambiente SaaS.

Criado para facilitar operar o ambiente SaaS, quando houver uma grande quantidade de usuários e se tornar difícil a operação de limpeza de forma manual.

Sintaxe:

    qlik_saas_delete_users -userName <userName> [-confirm <yes|no>]
        userName = The user name that will be deleted, you can use a wild card like '*', '?' to filter users. 
                    Default is 'none'.
        confirm   = If yes, then users will be deleted. If no, the users that will be deleted only will listed at
                    stdout. Default is no.


## Instalação
Para instalar os arquivos, baixe o zip QLIK_SAAS_UTILS.ZIP e descompate-o em um diretório. Se necessário, coloque o na PATH do seu ambiente. Em seguida basta executar qualquer script pela linha de comando.

Os programas foram testados em ambientes MS-Windows 10, MS-WIndows Server 2012 R2 e Linux Mint 20.1, o que dá um boa margem de compatibilidade.

Para usa-los será necessário:

**Passo 1 - Instalando o qlik-cli**

O *qlik-cli* contempla as bibliotecas para integração com o ambiente do SaaS. Escrito pela Qlik, esse aplicativo está disponível em https://qlik.dev/libraries-and-tools/qlik-cli. 

Para instala-lo no Linux, basta seguir o mesmo procedimento do Mac, descrito no link acima, primeiro instalando o *brew* e depois do *qlik-cli*. 

No Windows, você deverá descompactar o arquivo baixado e colocar o executável *qlik.exe* na PATH, mas o melhor é copia-lo para *c:\windows\system32* que o acesso fica garantido.

Após a instalação do *qlik-cli* você deverá configurar o acesso ao tenant, executando o comando, via cmd (ou bash) *qlik-cli context init*. Esse comando irá solicitar o endereço do tenant (p.ex. https://tenant.us.qlikcloud.com) e a chave api, que você deverá baixar a partir do Configurações do Perfil--> Ferramentas do seu usuário (p.ex. https://tenant.us.qlikcloud.com/settings/tools)

    PS /home/pbergo> qlik context init
    Acquiring access to Qlik Sense SaaS
    To complete the setup you have to have the 'developer' role and have
    API-keys enabled. If you're unsure, you can ask your tenant-admin.
    
    Specify your tenant URL, usually in the form: https://<tenant>.<region>.qlikcloud.com
    Where <tenant> is the name of the tenant and <region> is eu, us, ap, etc...
    Enter tenant url: https://tenant.us.qlikcloud.com
    To generate a new API-key, go to https://tenant.us.qlikcloud.com/settings/api-keys
    API-key:  asdfasfpoasd fn135j a-pf09ua skj1-09u dfaçlsdfkja -091u5413P)U_))(ASF


Para testar se está tudo correto, digite o comando a seguir e ele dever responder com o nome do contexto em uso.

    PS /home/pbergo> qlik context ls
    Name                              Server                                    Current     Comment
    tenant.us.qlikcloud.com           https://tenant.us.qlikcloud.com           *           


**Passo 2 -  Instalando o Powershell 7**

Baixe o Powershell versão 7 em https://docs.microsoft.com/pt-br/powershell/.

Os scripts foram construídos na versão 7 pois é multiplataforma desenvolvida e funcionam em diversos ambientes. Mais detalhes podem ser vistos no blog da MS https://devblogs.microsoft.com/powershell/announcing-powershell-7-0/

Para saber a versão que está instalada no seu computador ou servidor, basta acessar o Powershell e executar o comando *get-host*. Os ambientes Mac e Linux não possuem instalado por padrão então, tem que baixar mesmo, seguindo as instruções da MS.

    PS /home/pbergo> get-host
    
    Name             : ConsoleHost
    Version          : 7.1.3
    InstanceId       : 15f0132d-9d74-4d12-9eb3-0a2ed7957fd7
    UI               : System.Management.Automation.Internal.Host.InternalHostUserInterface
    CurrentCulture   : pt-BR
    CurrentUICulture : pt-BR
    PrivateData      : Microsoft.PowerShell.ConsoleHost+ConsoleColorProxy
    DebuggerEnabled  : True
    IsRunspacePushed : False
    Runspace         : System.Management.Automation.Runspaces.LocalRunspace

**Passo 3 - Aplicativo cURL**

O cURL é necessário para usar os programas de upload de Arquivos, pois a API utilizada ainda não está aberta à comunidade.

Se não possuir o cURL, baixe-o em https://curl.se/download.html e copie-o para coloque-o na PATH, p.ex. c:\Windows\System32 ou /usr/bin

Para saber se ele está instalado em seu sistema, basta entrar no cmd (ou terminal) e executar o comando *curl* .

    pbergo@aditi-pbergo:~$ curl --version
    curl 7.68.0 (x86_64-pc-linux-gnu) libcurl/7.68.0 OpenSSL/1.1.1f zlib/1.2.11 brotli/1.0.7 libidn2/2.2.0 libpsl/0.21.0 (+libidn2/2.2.0) libssh/0.9.3/openssl/zlib nghttp2/1.40.0 librtmp/2.3
    Release-Date: 2020-01-08
    Protocols: dict file ftp ftps gopher http https imap imaps ldap ldaps pop3 pop3s rtmp rtsp scp sftp smb smbs smtp smtps telnet tftp 
    Features: AsynchDNS brotli GSS-API HTTP2 HTTPS-proxy IDN IPv6
    Kerberos Largefile libz NTLM NTLM_WB PSL SPNEGO SSL TLS-SRP UnixSockets
    pbergo@aditi-pbergo:~$     
    

**Passo 4 - Configurando os arquivos qcs_api-key.txt e qcs_tenant.txt**

Encontrei um problema para usar a API e fui obrigado a criar arquivos com a chaves API e o nome do Tenant utilizado.

Dessa maneira você deverá colocar essas duas informações nesses arquivos, que devem estar no diretório ~/.qlik.

Para isso, faça o seguinte:
*Windows*

 - Abra um bloco de notas e insira o nome do tenant, **SEM** o protocolo
   (https://) p.ex. tenant.us.qlikcloud.com 
  - Salvar --> Nome do arquivo *%HOMEPATH%/.qlik/qcs_tenant.txt*
      - (Prá quem não sabe, *%HOMEPATH%* é o diretório raiz do usuário logado)
  - Abra um novo bloco de notas e insira a chave API, aquela mesma informada no Passo 1.
  - Depois clique em Salvar --> Nome do arquivo *%HOMEPATH%/.qlik/qcs_api-key.txt*
 
*Linux / Mac*

 - Abra um bloco de notas (nano, editor ou sublime) e insira o nome do tenant, **SEM** o protocolo
   (https://) p.ex. tenant.us.qlikcloud.com 
  - Salvar --> Nome do arquivo *~/.qlik/qcs_tenant.txt*  
      - (Prá quem não sabe, *~/* é o diretório raiz do usuário logado) 
  - Abra um novo bloco de notas e insira a chave API, aquela mesma informada no Passo 1.
  - Depois clique em Salvar --> Nome do arquivo *~/.qlik/qcs_api-key.txt*
 

