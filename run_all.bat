@echo off
REM run_all.bat - Executa o COBOL e a ponte Python

:: Verifica se o executável existe
if not exist protrx6.exe (
  echo ERRO: protrx6.exe nao encontrado na raiz do projeto.
  exit /b 1
)

:: Executa o COBOL
echo Executando protrx6.exe...
.\protrx6.exe
if %ERRORLEVEL% NEQ 0 (
  echo O programa COBOL terminou com erro %ERRORLEVEL% && exit /b %ERRORLEVEL%
)

:: Executa a ponte Python
echo Executando a ponte Python (local\ponte.py)...
py local\ponte.py

necho Execucao finalizada.
pause
