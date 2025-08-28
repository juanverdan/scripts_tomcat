<#
.SYNOPSIS
    Limpa arquivos de dump (.mdmp) e logs de erro da JVM (hs_err_pid) de pastas do Tomcat.

.DESCRIPTION
    Este script foi projetado para ser executado como uma tarefa agendada. Ele percorre uma lista
    pré-definida de diretórios do Tomcat e remove recursivamente todos os arquivos .mdmp e
    logs de erro hs_err_pid*.log encontrados.

    Um log detalhado (transcript) de cada execução é salvo em uma subpasta "Logs".

.NOTES
    Autor:          Juan Verdan
    Data de Criação: 28/08/2025
    Versão:         1.0

.EXAMPLE
    .\Clean-TomcatCrashFiles.ps1
    (Nao sao necessarios parametros. A lista de pastas deve ser configurada na variavel abaixo)
#>

# =================================================================
# INICIA O LOG AUTOMATICO (TRANSCRIPT)
# =================================================================
try {
    # Define o caminho para a pasta de Logs (sera criada se nao existir)
    $LogFolderPath = Join-Path -Path $PSScriptRoot -ChildPath "Logs"
    if (-not (Test-Path $LogFolderPath)) {
        New-Item -ItemType Directory -Path $LogFolderPath | Out-Null
    }
    # Inicia a gravacao de tudo que acontece no console para um arquivo de log com nome unico
    Start-Transcript -Path (Join-Path $LogFolderPath "Log_Limpeza_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').txt")
} catch {
    Write-Warning "Nao foi possivel iniciar o log (transcript). Verifique as permissoes na pasta do script."
}

# =================================================================
# Adicione todas as pastas do Tomcat que voce quer limpar.
# =================================================================
$listaDePastas = @(
    "C:\Caminho\Para\Seu\Tomcat-1",
    "C:\Caminho\Para\Seu\Tomcat-2",
    "D:\Outro\Caminho\Para\Tomcat-3"
)

# =================================================================
# INICIO DO SCRIPT DE LIMPEZA
# =================================================================
Write-Host "Iniciando limpeza diaria de arquivos .mdmp e hs_err_pid*.log..."

foreach ($pasta in $listaDePastas) {
    Write-Host "`n-> Verificando a pasta: $pasta"
    
    if (Test-Path $pasta) {
        # Busca por dois padroes de arquivo: *.mdmp e hs_err_pid*.log
        Get-ChildItem -Path $pasta -Include @("*.mdmp", "hs_err_pid*.log") -Recurse | ForEach-Object {
            Write-Host "   Apagando: $($_.FullName)"
            Remove-Item -Path $_.FullName -Force
        }
    } else {
        Write-Warning "AVISO: A pasta '$pasta' nao foi encontrada e sera ignorada."
    }
}

Write-Host "`nLimpeza diaria concluida."
Stop-Transcript