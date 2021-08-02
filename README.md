README.md
# Qlik SaaS Utils

Scripts utilitários para operar o SaaS, fazendo upload de apps, arquivos, extensões e temas, arquivos. Também possibilita apagar arquivos e usuários existentes no SaaS.

## Qlik SaaS Utils

## Table of Contents

-[Upload](#upload)

-[Upload Files] (#upload files)

-[Delete Files](#delete files)

-[Delete Users](#delete_users)


## Upload

qlik_saas_upload.ps1

O programa qlik_saas_upload.ps1, escrito em PowerShell, faz o upload de vários arquivos localizados em subdiretórios determinados via linha de comando. 
- Apps: Esse programa, além de importar os apps, também cria Spaces onde eles serão publicados, publica os aplicativos para esses Spaces. Também publica pastas dos apps carregados de forma automática, evitando o processo manual.
- Extensões: As extensões são importadas para o SaaS.
- Temas: Temas também são carregados para o SaaS automaticamente.

Esse programa foi criado para permitir automatizar o processo de carga e geração de ambientes do SaaS. 


## Upload Files

qlik_saas_upload_files.ps1

Esse programa foi escrito em Powershell para realizar upload de arquivos diversos direto para o ambiente SaaS.
Basta apontar o diretório/arquivos a serem carregados e o Espaço dentro do SaaS que o programa fará a carga. Use os parâmetros de sobrescrita (overwrite) para enviar os arquivos mesmo que existam no destino ou deixe o programa verificar quem é mais novo para manter o ambiente do SaaS atualizado.


## Delete

qlik_saas_delete_files.ps1

O programa qlik_saas_delete.ps1, escrito em PowerShell, apaga vários arquivos localizados em um Space do SaaS via linha de comando.

Esse programa foi criado para facilitar operar o ambiente SaaS, quando houver uma grande quantidade de arquivos e se tornar difícil a operação de limpeza de forma manual.

## Delete Users

qlik_saas_delete_users.ps1

O programa qlik_saas_delete_users.ps1, escrito em PowerShell, apaga vários usuários por linha de comando do ambiente SaaS.

Esse programa foi criado para facilitar operar o ambiente SaaS, quando houver uma grande quantidade de usuários e se tornar difícil a operação de limpeza de forma manual.



