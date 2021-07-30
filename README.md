README.md
# Qlik SaaS Utils

Scripts utilitários para operar o SaaS, fazendo upload de apps, extensões e temas, arquivos. Também possibilita apagar os arquivos existentes no SaaS.

## Qlik SaaS Utils

## Table of Contents

-[Upload](#upload)

-[Delete](#delete)

-[Delete Users](#delete_users)


## Upload

O programa qlik_saas_upload.ps1, escrito em PowerShell, faz o upload de vários arquivos localizados em subdiretórios determinados via linha de comando. 
- Apps: Esse programa, além de importar os apps, também cria Spaces onde eles serão publicados, publica os aplicativos para esses Spaces. Também publica pastas dos apps carregados de forma automática, evitando o processo manual.
- Extensões: As extensões são importadas para o SaaS.
- Temas: Temas também são carregados para o SaaS automaticamente.

Esse programa foi criado para permitir automatizar o processo de carga e geração de ambientes do SaaS. 

## Delete

O programa qlik_saas_delete.ps1, escrito em PowerShell, apaga vários arquivos localizados em um Space do SaaSvia linha de comando.

Esse programa foi criado para facilitar operar o ambiente SaaS, quando houver uma grande quantidade de arquivos e se tornar difícil a operação de limpeza de forma manual.

## Delete Users

O programa qlik_saas_delete_users.ps1, escrito em PowerShell, apaga vários usuários por linha de comando do ambiente SaaS.

Esse programa foi criado para facilitar operar o ambiente SaaS, quando houver uma grande quantidade de usuários e se tornar difícil a operação de limpeza de forma manual.




