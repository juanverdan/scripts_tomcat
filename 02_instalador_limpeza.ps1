<#
.SYNOPSIS
    Um script autocontido para instalar e executar a limpeza de arquivos do Tomcat.
.DESCRIPTION
    - Se executado com o parametro -Instalar, ele se copia para C:\Scripts\TomcatCleaner,
      cria um arquivo pastas.txt e agenda uma tarefa para sua execucao diaria.
    - Se executado sem parametros (como a tarefa agendada fara), ele executa a rotina de limpeza.
.EXAMPLE
    # Para instalar a automacao:
    .\instalador_limpeza.ps1 -Instalar

    # A tarefa agendada executara sem parametros para realizar a limpeza.
#>
[CmdletBinding()]
param (
    # Use este switch para acionar o modo de instalacao
    [Switch]$Instalar
)

# --- MODO DE INSTALAÇÃO ---
if ($Instalar) {
    # 1. Pede permissao de Administrador
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -ArgumentList '-Instalar'" -Verb RunAs
        exit
    }

    # 2. Define variaveis e cria a pasta de destino
    $NomeDaTarefa = "Limpeza Automatica de Dumps do Tomcat"
    $PastaDeDestino = "C:\Scripts\TomcatCleaner"
    $CaminhoDoScriptDestino = Join-Path $PastaDeDestino -ChildPath "AutoLimpador.ps1"
    $CaminhoDoConfigDestino = Join-Path $PastaDeDestino -ChildPath "pastas.txt"

    if (-not (Test-Path $PastaDeDestino)) { New-Item -ItemType Directory -Path $PastaDeDestino | Out-Null }

    # 3. Copia este proprio script para a pasta de destino
    Copy-Item -Path $MyInvocation.MyCommand.Path -Destination $CaminhoDoScriptDestino -Force
    Write-Host "Script copiado para '$CaminhoDoScriptDestino'"

    # 4. Cria o arquivo de configuracao se ele nao existir
    if (-not (Test-Path $CaminhoDoConfigDestino)) {
        $ConteudoPadrao = @(
            '# Adicione aqui os caminhos completos das pastas do Tomcat, um por linha.',
            '# Exemplo: C:\Tomcat\apache-tomcat-9.0.80'
        )
        Set-Content -Path $CaminhoDoConfigDestino -Value $ConteudoPadrao
        Write-Host "Arquivo de configuracao criado em '$CaminhoDoConfigDestino'"
    }

    # 5. Configura a Tarefa Agendada
    $Action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$CaminhoDoScriptDestino`""
    $Trigger = New-ScheduledTaskTrigger -Daily -At 3am
    $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest
    Register-ScheduledTask -TaskName $NomeDaTarefa -Action $Action -Trigger $Trigger -Principal $Principal -Force -Description "Executa a limpeza de arquivos .mdmp e hs_err_pid*.log do Tomcat."

    # 6. Mensagem de Sucesso e abre o arquivo de configuracao para edicao
    Write-Host "`nAutomacao instalada com SUCESSO!" -ForegroundColor Green
    Write-Host "A tarefa '$NomeDaTarefa' foi agendada."
    Write-Host "O arquivo de configuracao sera aberto para voce adicionar as pastas."
    Start-Sleep -Seconds 2
    Notepad.exe $CaminhoDoConfigDestino
    
    Read-Host "Pressione Enter para sair apos editar o arquivo."
}
#MODO DE LIMPEZA (execução normal)
else {
    $ScriptDirectory = $PSScriptRoot
    $ConfigFile = Join-Path -Path $ScriptDirectory -ChildPath "pastas.txt"

    try {
        $LogFolderPath = Join-Path -Path $ScriptDirectory -ChildPath "Logs"
        if (-not (Test-Path $LogFolderPath)) { New-Item -ItemType Directory -Path $LogFolderPath | Out-Null }
        Start-Transcript -Path (Join-Path $LogFolderPath "Log_Limpeza_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt")
    } catch { Write-Warning "Nao foi possivel iniciar o log." }

    Write-Host "Iniciando limpeza diaria..."

    if (-not (Test-Path $ConfigFile)) {
        Write-Error "ERRO: Arquivo de configuracao 'pastas.txt' nao encontrado."
    }
    else {
        $listaDePastas = Get-Content -Path $ConfigFile | Where-Object { $_.Trim() -ne '' -and $_ -notlike '#*' }
        foreach ($pasta in $listaDePastas) {
            Write-Host "`n-> Verificando a pasta: $pasta"
            if (Test-Path $pasta) {
                Get-ChildItem -Path $pasta -Include @("*.mdmp", "hs_err_pid*.log") -Recurse | ForEach-Object {
                    Write-Host "   Apagando: $($_.FullName)"
                    Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                }
            } else { Write-Warning "AVISO: A pasta '$pasta' nao foi encontrada." }
        }
    }

    Write-Host "`nLimpeza diaria concluida."
    Stop-Transcript
}