      *===============================================================*
      * PROTRX6 - SISTEMA DE CONTAS BANCARIAS                        *
      * PROJETO 6 - SEMANA 8                                         *
      * COBOL 74 - VERSAO LOCAL (GNUCOBOL) PARA INTEGRACAO ODBC      *
      *                                                               *
      * OBS: PROGRAMA PROCESSA AS REGRAS DE NEGOCIO E GERA ARQUIVOS  *
      *      DE SAIDA. A GRAVACAO NO MYSQL E FEITA POR SCRIPT PYTHON *
      *      (PONTE.PY) QUE LE ESTES ARQUIVOS E USA ODBC.            *
      *===============================================================*
       IDENTIFICATION DIVISION.
       PROGRAM-ID. PROTRX6.
       AUTHOR. HERC01.
      *
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-370.
       OBJECT-COMPUTER. IBM-370.
      *
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT ARQCLI ASSIGN TO "CLIENTES.TXT"
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL.
           SELECT ARQTRX ASSIGN TO "TRANSACOES.TXT"
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL.
           SELECT ARQLOG ASSIGN TO "LOGS.TXT"
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL.
           SELECT ARQERR ASSIGN TO "ERROS.TXT"
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL.
           SELECT ARQSCL ASSIGN TO "SAIDA_CLI.TXT"
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL.
           SELECT ARQSTX ASSIGN TO "SAIDA_TRX.TXT"
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE  IS SEQUENTIAL.
      *
       DATA DIVISION.
       FILE SECTION.
      *
       FD  ARQCLI
           RECORDING MODE IS F
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 34 CHARACTERS.
       COPY CLICOPY.
      *
       FD  ARQTRX
           RECORDING MODE IS F
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 20 CHARACTERS.
       COPY TRXCOPY.
      *
       FD  ARQLOG
           RECORDING MODE IS F
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 80 CHARACTERS.
       01  REG-LOG           PIC X(80).
      *
       FD  ARQERR
           RECORDING MODE IS F
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 80 CHARACTERS.
       01  REG-ERRO          PIC X(80).
      *
       FD  ARQSCL
           RECORDING MODE IS F
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 35 CHARACTERS.
       01  REG-SAICLI        PIC X(35).
      *
       FD  ARQSTX
           RECORDING MODE IS F
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 20 CHARACTERS.
       01  REG-SAITRX        PIC X(20).
      *
       WORKING-STORAGE SECTION.
      *
       01  WS-FLAGS.
           05  WS-FIM-CLI    PIC X(01) VALUE 'N'.
           05  WS-FIM-TRX    PIC X(01) VALUE 'N'.
      *
       01  WS-CONTADORES.
           05  WS-TOT-LIDOS  PIC 9(05) VALUE ZEROS.
           05  WS-TOT-OK     PIC 9(05) VALUE ZEROS.
           05  WS-TOT-ERRO   PIC 9(05) VALUE ZEROS.
           05  WS-TOT-CLI    PIC 9(05) VALUE ZEROS.
      *
       01  WS-LINHA-LOG.
           05  WS-LOG-CLID   PIC 9(05).
           05  FILLER        PIC X(01) VALUE SPACES.
           05  WS-LOG-NOME   PIC X(20).
           05  FILLER        PIC X(01) VALUE SPACES.
           05  WS-LOG-OPER   PIC X(07).
           05  FILLER        PIC X(01) VALUE SPACES.
           05  WS-LOG-STAT   PIC X(20).
           05  FILLER        PIC X(24) VALUE SPACES.
      *
       01  WS-LINHA-ERR.
           05  WS-ERR-CLID   PIC 9(05).
           05  FILLER        PIC X(01) VALUE SPACES.
           05  WS-ERR-TIPO   PIC X(07).
           05  FILLER        PIC X(01) VALUE SPACES.
           05  WS-ERR-DESC   PIC X(40).
           05  FILLER        PIC X(26) VALUE SPACES.
      *
      * LAYOUT DA SAIDA DE CLIENTES PARA O PYTHON LER
      * POS 01-05 ID / POS 06-25 NOME / POS 26-34 SALDO / POS 35 OPER
       01  WS-LINHA-SCL.
           05  WS-SCL-ID     PIC 9(05).
           05  WS-SCL-NOME   PIC X(20).
           05  WS-SCL-SALDO  PIC 9(09).
           05  WS-SCL-OPER   PIC X(01).
      *
      * LAYOUT DA SAIDA DE TRANSACOES PARA O PYTHON LER
      * POS 01-05 TRXID / 06-10 CLIID / 11 TIPO / 12-20 VALOR
       01  WS-LINHA-STX.
           05  WS-STX-TRXID  PIC 9(05).
           05  WS-STX-CLIID  PIC 9(05).
           05  WS-STX-TIPO   PIC X(01).
           05  WS-STX-VALOR  PIC 9(09).
      *
       01  WS-LINHA-REL.
           05  FILLER        PIC X(20)
               VALUE 'TOTAL LIDOS.......'.
           05  WS-REL-LIDOS  PIC 9(05).
           05  FILLER        PIC X(55) VALUE SPACES.
      *
       01  WS-LINHA-RE2.
           05  FILLER        PIC X(20)
               VALUE 'TOTAL OK.........'.
           05  WS-REL-OK     PIC 9(05).
           05  FILLER        PIC X(55) VALUE SPACES.
      *
       01  WS-LINHA-RE3.
           05  FILLER        PIC X(20)
               VALUE 'TOTAL ERROS......'.
           05  WS-REL-ERR    PIC 9(05).
           05  FILLER        PIC X(55) VALUE SPACES.
      *
       PROCEDURE DIVISION.
      *
       0000-PRINCIPAL.
           MOVE ZEROS TO WS-TOT-LIDOS.
           MOVE ZEROS TO WS-TOT-OK.
           MOVE ZEROS TO WS-TOT-ERRO.
           MOVE ZEROS TO WS-TOT-CLI.
           MOVE 'N'   TO WS-FIM-CLI.
           MOVE 'N'   TO WS-FIM-TRX.
      *
           OPEN INPUT  ARQCLI.
           OPEN INPUT  ARQTRX.
           OPEN OUTPUT ARQLOG.
           OPEN OUTPUT ARQERR.
           OPEN OUTPUT ARQSCL.
           OPEN OUTPUT ARQSTX.
      *
           PERFORM 1000-PROC-CLIENTES
               UNTIL WS-FIM-CLI = 'S'.
      *
           PERFORM 2000-PROC-TRANSACOES
               UNTIL WS-FIM-TRX = 'S'.
      *
           PERFORM 9000-RELATORIO.
      *
           CLOSE ARQCLI.
           CLOSE ARQTRX.
           CLOSE ARQLOG.
           CLOSE ARQERR.
           CLOSE ARQSCL.
           CLOSE ARQSTX.
      *
           DISPLAY 'PROCESSAMENTO COBOL FINALIZADO.'.
           DISPLAY 'ARQUIVOS GERADOS: LOGS.TXT ERROS.TXT '
                    'SAIDA_CLI.TXT SAIDA_TRX.TXT'.
      *
           STOP RUN.
      *
      *---------------------------------------------------------------*
       1000-PROC-CLIENTES.
           READ ARQCLI INTO REG-CLIENTE
               AT END MOVE 'S' TO WS-FIM-CLI.
           IF WS-FIM-CLI = 'S'
               NEXT SENTENCE
           ELSE
               ADD 1 TO WS-TOT-CLI
               PERFORM 1100-VALIDA-CLIENTE.
      *
       1100-VALIDA-CLIENTE.
           IF CLI-NOME = SPACES
               MOVE CLI-ID        TO WS-ERR-CLID
               MOVE 'CLIENTE'     TO WS-ERR-TIPO
               MOVE 'NOME OBRIGATORIO - REGISTRO REJEITADO'
                                  TO WS-ERR-DESC
               WRITE REG-ERRO FROM WS-LINHA-ERR
               ADD 1 TO WS-TOT-ERRO
           ELSE
               MOVE CLI-ID        TO WS-LOG-CLID
               MOVE CLI-NOME      TO WS-LOG-NOME
               MOVE 'CLIENTE'     TO WS-LOG-OPER
               MOVE 'CADASTRADO COM SUCESSO'
                                  TO WS-LOG-STAT
               WRITE REG-LOG FROM WS-LINHA-LOG
      *        GRAVA SAIDA PARA O PYTHON (OPERACAO = U -> UPSERT)
               MOVE SPACES        TO WS-LINHA-SCL
               MOVE CLI-ID        TO WS-SCL-ID
               MOVE CLI-NOME      TO WS-SCL-NOME
               MOVE CLI-SALDO     TO WS-SCL-SALDO
               MOVE 'U'           TO WS-SCL-OPER
               WRITE REG-SAICLI FROM WS-LINHA-SCL
               ADD 1 TO WS-TOT-OK.
      *
      *---------------------------------------------------------------*
       2000-PROC-TRANSACOES.
           READ ARQTRX INTO REG-TRANSACAO
               AT END MOVE 'S' TO WS-FIM-TRX.
           IF WS-FIM-TRX = 'S'
               NEXT SENTENCE
           ELSE
               ADD 1 TO WS-TOT-LIDOS
               PERFORM 2100-VALIDA-TRANSACAO.
      *
       2100-VALIDA-TRANSACAO.
           IF TRX-VALOR = ZEROS
               MOVE TRX-CLI-ID    TO WS-ERR-CLID
               MOVE 'TRANSAC'     TO WS-ERR-TIPO
               MOVE 'VALOR ZERADO - TRANSACAO REJEITADA'
                                  TO WS-ERR-DESC
               WRITE REG-ERRO FROM WS-LINHA-ERR
               ADD 1 TO WS-TOT-ERRO
           ELSE
               IF TRX-TIPO NOT = 'C' AND TRX-TIPO NOT = 'D'
                   MOVE TRX-CLI-ID TO WS-ERR-CLID
                   MOVE 'TRANSAC'  TO WS-ERR-TIPO
                   MOVE 'TIPO INVALIDO - DEVE SER C OU D'
                                   TO WS-ERR-DESC
                   WRITE REG-ERRO FROM WS-LINHA-ERR
                   ADD 1 TO WS-TOT-ERRO
               ELSE
                   PERFORM 2200-PROC-SALDO.
      *
       2200-PROC-SALDO.
      *    OBS: NESTA VERSAO LOCAL NAO HA LEITURA DO SALDO ATUAL
      *    DO BANCO (ISSO E FEITO PELO SCRIPT PYTHON NO MOMENTO DA
      *    GRAVACAO). O COBOL APENAS REGISTRA A TRANSACAO COMO
      *    VALIDA PARA TIPO E VALOR. A VALIDACAO DE SALDO SUFICIENTE
      *    PARA DEBITO E FEITA EM CONJUNTO COM A PONTE PYTHON/MYSQL,
      *    QUE CONSULTA O SALDO REAL ANTES DE GRAVAR.
           MOVE TRX-ID       TO WS-STX-TRXID
           MOVE TRX-CLI-ID   TO WS-STX-CLIID
           MOVE TRX-TIPO     TO WS-STX-TIPO
           MOVE TRX-VALOR    TO WS-STX-VALOR
           WRITE REG-SAITRX FROM WS-LINHA-STX.
      *
           MOVE TRX-CLI-ID   TO WS-LOG-CLID
           MOVE SPACES       TO WS-LOG-NOME
           IF TRX-TIPO = 'D'
               MOVE 'DEBITO '   TO WS-LOG-OPER
           ELSE
               MOVE 'CREDITO'   TO WS-LOG-OPER.
           MOVE 'ENVIADO PARA PROCESSAMENTO ODBC'
                             TO WS-LOG-STAT
           WRITE REG-LOG FROM WS-LINHA-LOG.
           ADD 1 TO WS-TOT-OK.
      *
      *---------------------------------------------------------------*
       9000-RELATORIO.
           MOVE WS-TOT-CLI    TO WS-REL-LIDOS.
           WRITE REG-LOG FROM WS-LINHA-REL.
           MOVE WS-TOT-OK     TO WS-REL-OK.
           WRITE REG-LOG FROM WS-LINHA-RE2.
           MOVE WS-TOT-ERRO   TO WS-REL-ERR.
           WRITE REG-LOG FROM WS-LINHA-RE3.
