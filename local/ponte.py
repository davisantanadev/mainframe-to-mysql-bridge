# ==================================================================
# PONTE.PY - INTEGRACAO COBOL <-> MYSQL VIA ODBC
# PROJETO 6 - SEMANA 8 - SISTEMA DE CONTAS BANCARIAS
#
# Le os arquivos gerados pelo programa COBOL (PROTRX6) e grava/
# atualiza os dados no MySQL atraves do driver ODBC (DSN PROJ6DSN).
#
# Funcionalidades:
#   - Le SAIDA_CLI.TXT  -> INSERT ou UPDATE na tabela CLIENTES
#   - Le SAIDA_TRX.TXT  -> valida saldo, INSERT na tabela TRANSACOES,
#                          atualiza saldo do cliente
#   - Le ERROS.TXT (gerado pelo COBOL) -> INSERT na tabela
#                          ERROS_PROCESSAMENTO
#   - Erros encontrados durante o processo no MySQL (ex: saldo
#     insuficiente) tambem sao gravados em ERROS_PROCESSAMENTO
#   - COMMIT a cada 100 registros processados
#   - ROLLBACK em caso de erro SQL
# ==================================================================

import pyodbc
import datetime
import sys

DSN = "PROJ6DSN"
PASTA = "."  # ajuste se os arquivos estiverem em outro diretorio

ARQ_SAIDA_CLI = f"{PASTA}/SAIDA_CLI.TXT"
ARQ_SAIDA_TRX = f"{PASTA}/SAIDA_TRX.TXT"
ARQ_ERROS_COBOL = f"{PASTA}/ERROS.TXT"

LREC_CLI = 35   # ID(5) + NOME(20) + SALDO(9) + OPER(1)
LREC_TRX = 20   # TRXID(5) + CLIID(5) + TIPO(1) + VALOR(9)

COMMIT_A_CADA = 100


def conectar():
    """Abre conexao ODBC usando o DSN configurado no Windows."""
    try:
        conn = pyodbc.connect(f"DSN={DSN}", autocommit=False)
        print(f"[OK] Conectado ao MySQL via DSN '{DSN}'")
        return conn
    except pyodbc.Error as e:
        print(f"[ERRO FATAL] Nao foi possivel conectar via ODBC: {e}")
        sys.exit(1)


def registrar_erro(cursor, cli_id, descricao):
    """Insere um registro na tabela ERROS_PROCESSAMENTO."""
    try:
        cursor.execute(
            "INSERT INTO ERROS_PROCESSAMENTO (CLI_ID, DESCRICAO_ERRO, "
            "DT_OCORRENCIA) VALUES (?, ?, ?)",
            (cli_id, descricao[:100], datetime.datetime.now())
        )
    except pyodbc.Error as e:
        print(f"  [AVISO] Falha ao gravar erro no banco: {e}")


def processar_clientes(conn):
    """Le SAIDA_CLI.TXT e faz INSERT ou UPDATE na tabela CLIENTES."""
    print("\n--- Processando CLIENTES ---")
    cursor = conn.cursor()
    total_lidos = 0
    total_ok = 0
    total_erro = 0

    try:
        with open(ARQ_SAIDA_CLI, "rb") as f:
            data = f.read()
    except FileNotFoundError:
        print(f"[ERRO] Arquivo {ARQ_SAIDA_CLI} nao encontrado.")
        return

    qtd_registros = len(data) // LREC_CLI

    for i in range(qtd_registros):
        bloco = data[i * LREC_CLI:(i + 1) * LREC_CLI]
        cli_id = int(bloco[0:5].decode("ascii"))
        nome = bloco[5:25].decode("ascii").rstrip()
        saldo = int(bloco[25:34].decode("ascii"))
        oper = bloco[34:35].decode("ascii")

        total_lidos += 1

        if not nome:
            print(f"  [ERRO] CLI_ID={cli_id} sem nome - rejeitado")
            registrar_erro(cursor, cli_id, "Nome obrigatorio ausente")
            total_erro += 1
            continue

        try:
            cursor.execute(
                "SELECT CLI_ID FROM CLIENTES WHERE CLI_ID = ?", (cli_id,)
            )
            existe = cursor.fetchone()

            if existe:
                cursor.execute(
                    "UPDATE CLIENTES SET CLI_NOME = ?, CLI_SALDO = ?, "
                    "DT_ATUALIZACAO = ? WHERE CLI_ID = ?",
                    (nome, saldo, datetime.date.today(), cli_id)
                )
                print(f"  [OK] Cliente {cli_id} ({nome}) atualizado")
            else:
                cursor.execute(
                    "INSERT INTO CLIENTES (CLI_ID, CLI_NOME, CLI_SALDO, "
                    "DT_ATUALIZACAO) VALUES (?, ?, ?, ?)",
                    (cli_id, nome, saldo, datetime.date.today())
                )
                print(f"  [OK] Cliente {cli_id} ({nome}) inserido")

            total_ok += 1

            if total_ok % COMMIT_A_CADA == 0:
                conn.commit()
                print(f"  [COMMIT] {total_ok} registros confirmados")

        except pyodbc.Error as e:
            print(f"  [ERRO SQL] Cliente {cli_id}: {e}")
            conn.rollback()
            registrar_erro(cursor, cli_id, f"Erro SQL: {str(e)[:80]}")
            conn.commit()
            total_erro += 1

    conn.commit()
    print(f"Clientes - Lidos: {total_lidos} | OK: {total_ok} | "
          f"Erros: {total_erro}")


def processar_transacoes(conn):
    """Le SAIDA_TRX.TXT, valida saldo, grava transacao e atualiza saldo."""
    print("\n--- Processando TRANSACOES ---")
    cursor = conn.cursor()
    total_lidos = 0
    total_ok = 0
    total_erro = 0

    try:
        with open(ARQ_SAIDA_TRX, "rb") as f:
            data = f.read()
    except FileNotFoundError:
        print(f"[ERRO] Arquivo {ARQ_SAIDA_TRX} nao encontrado.")
        return

    qtd_registros = len(data) // LREC_TRX

    for i in range(qtd_registros):
        bloco = data[i * LREC_TRX:(i + 1) * LREC_TRX]
        trx_id = int(bloco[0:5].decode("ascii"))
        cli_id = int(bloco[5:10].decode("ascii"))
        tipo = bloco[10:11].decode("ascii")
        valor = int(bloco[11:20].decode("ascii"))

        total_lidos += 1

        try:
            cursor.execute(
                "SELECT CLI_SALDO FROM CLIENTES WHERE CLI_ID = ?", (cli_id,)
            )
            row = cursor.fetchone()

            if not row:
                print(f"  [ERRO] Cliente {cli_id} inexistente - "
                      f"transacao {trx_id} rejeitada")
                registrar_erro(cursor, cli_id,
                                f"Cliente inexistente - TRX {trx_id}")
                conn.commit()
                total_erro += 1
                continue

            saldo_atual = row[0]

            if tipo == "D" and valor > saldo_atual:
                print(f"  [ERRO] Saldo insuficiente p/ cliente {cli_id} "
                      f"- transacao {trx_id} rejeitada")
                registrar_erro(cursor, cli_id,
                                f"Saldo insuficiente - TRX {trx_id}")
                conn.commit()
                total_erro += 1
                continue

            novo_saldo = saldo_atual - valor if tipo == "D" \
                else saldo_atual + valor

            cursor.execute(
                "INSERT INTO TRANSACOES (TRX_ID, CLI_ID, TRX_TIPO, "
                "TRX_VALOR, DT_PROCESSAMENTO) VALUES (?, ?, ?, ?, ?)",
                (trx_id, cli_id, tipo, valor, datetime.date.today())
            )
            cursor.execute(
                "UPDATE CLIENTES SET CLI_SALDO = ?, DT_ATUALIZACAO = ? "
                "WHERE CLI_ID = ?",
                (novo_saldo, datetime.date.today(), cli_id)
            )

            print(f"  [OK] TRX {trx_id} cliente {cli_id} tipo={tipo} "
                  f"valor={valor} novo_saldo={novo_saldo}")
            total_ok += 1

            if total_ok % COMMIT_A_CADA == 0:
                conn.commit()
                print(f"  [COMMIT] {total_ok} registros confirmados")

        except pyodbc.Error as e:
            print(f"  [ERRO SQL] Transacao {trx_id}: {e}")
            conn.rollback()
            registrar_erro(cursor, cli_id, f"Erro SQL: {str(e)[:80]}")
            conn.commit()
            total_erro += 1

    conn.commit()
    print(f"Transacoes - Lidas: {total_lidos} | OK: {total_ok} | "
          f"Erros: {total_erro}")


def main():
    print("=" * 60)
    print("PONTE COBOL -> MYSQL (ODBC) - PROJETO 6 SEMANA 8")
    print("=" * 60)

    conn = conectar()

    try:
        processar_clientes(conn)
        processar_transacoes(conn)
    except Exception as e:
        print(f"[ERRO INESPERADO] {e}")
        conn.rollback()
    finally:
        conn.close()
        print("\n[FIM] Conexao encerrada.")


if __name__ == "__main__":
    main()
