      *===============================================================*
      * PROTRX6 - SISTEMA DE CONTAS BANCARIAS                        *
      * PROJETO 6 - SEMANA 8                                         *
      * COBOL 74 - TK5/MVS                                           *
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
           SELECT ARQCLI ASSIGN TO UT-S-CLIENTES
               ACCESS MODE  IS SEQUENTIAL.
           SELECT ARQTRX ASSIGN TO UT-S-TRANSACS
               ACCESS MODE  IS SEQUENTIAL.
           SELECT ARQLOG ASSIGN TO UT-S-LOGS
               ACCESS MODE  IS SEQUENTIAL.
           SELECT ARQERR ASSIGN TO UT-S-ERROS
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
       01  REG-CLIENTE.
           05  CLI-ID        PIC 9(05).
           05  CLI-NOME      PIC X(20).
           05  CLI-SALDO     PIC 9(09).
      *
       FD  ARQTRX
           RECORDING MODE IS F
           LABEL RECORDS ARE STANDARD
           BLOCK CONTAINS 0 RECORDS
           RECORD CONTAINS 20 CHARACTERS.
       01  REG-TRANSACAO.
           05  TRX-CLI-ID    PIC 9(05).
           05  TRX-ID        PIC 9(05).
           05  TRX-TIPO      PIC X(01).
           05  TRX-VALOR     PIC 9(09).
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
       WORKING-STORAGE SECTION.
      *
       01  WS-FLAGS.
           05  WS-FIM-CLI    PIC X(01) VALUE 'N'.
           05  WS-FIM-TRX    PIC X(01) VALUE 'N'.
           05  WS-ACHOU      PIC X(01) VALUE 'N'.
      *
       01  WS-CONTADORES.
            05  WS-TOT-LIDOS  PIC 9(05) VALUE ZEROS.
            05  WS-TOT-OK     PIC 9(05) VALUE ZEROS.
            05  WS-TOT-ERRO   PIC 9(05) VALUE ZEROS.
            05  WS-TOT-CLI    PIC 9(05) VALUE ZEROS.
       01  WS-TAB-CLI-COUNT   PIC 9(03) VALUE ZEROS.
       01  TABELA-CLIENTES.
           05  TAB-CLI-ITEM OCCURS 50 TIMES.
               10  TAB-CLI-ID     PIC 9(05).
               10  TAB-CLI-NOME   PIC X(20).
               10  TAB-CLI-SALDO  PIC 9(09).
       01  WS-IDX            PIC 9(03) VALUE ZEROS.
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
       01  WS-SALDO-ATUAL    PIC 9(09) VALUE ZEROS.
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
      *
           STOP RUN.
      *
      *------------------------------------------------------*
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
               ADD 1 TO WS-TOT-OK.
               ADD 1 TO WS-TAB-CLI-COUNT
               MOVE CLI-ID    TO TAB-CLI-ID(WS-TAB-CLI-COUNT)
               MOVE CLI-NOME  TO TAB-CLI-NOME(WS-TAB-CLI-COUNT)
               MOVE CLI-SALDO TO TAB-CLI-SALDO(WS-TAB-CLI-COUNT).
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
                    PERFORM 2150-BUSCA-CLIENTE
                    IF WS-ACHOU = 'N'
                         MOVE TRX-CLI-ID TO WS-ERR-CLID
                         MOVE 'TRANSAC'  TO WS-ERR-TIPO
                         MOVE 'CLIENTE INEXISTENTE'
                                         TO WS-ERR-DESC
                         WRITE REG-ERRO FROM WS-LINHA-ERR
                         ADD 1 TO WS-TOT-ERRO
                    ELSE
                         PERFORM 2200-PROC-SALDO.
      *
       2150-BUSCA-CLIENTE.
           MOVE 'N' TO WS-ACHOU.
           MOVE 1   TO WS-IDX.
           PERFORM 2160-LOOP-BUSCA
               UNTIL WS-IDX > WS-TAB-CLI-COUNT OR WS-ACHOU = 'S'.
      *
       2160-LOOP-BUSCA.
           IF TAB-CLI-ID(WS-IDX) = TRX-CLI-ID
               MOVE 'S' TO WS-ACHOU
           ELSE
               ADD 1 TO WS-IDX.
      *
       2200-PROC-SALDO.
           IF TRX-TIPO = 'D'
               IF TRX-VALOR > TAB-CLI-SALDO(WS-IDX)
                    MOVE TRX-CLI-ID  TO WS-ERR-CLID
                    MOVE 'TRANSAC'   TO WS-ERR-TIPO
                    MOVE 'SALDO INSUFICIENTE PARA DEBITO'
                                     TO WS-ERR-DESC
                    WRITE REG-ERRO FROM WS-LINHA-ERR
                    ADD 1 TO WS-TOT-ERRO
               ELSE
                    SUBTRACT TRX-VALOR FROM TAB-CLI-SALDO(WS-IDX)
                    MOVE TRX-CLI-ID  TO WS-LOG-CLID
                    MOVE TAB-CLI-NOME(WS-IDX) TO WS-LOG-NOME
                    MOVE 'DEBITO '   TO WS-LOG-OPER
                    MOVE 'DEBITADO COM SUCESSO'
                                     TO WS-LOG-STAT
                    WRITE REG-LOG FROM WS-LINHA-LOG
                    ADD 1 TO WS-TOT-OK.
           IF TRX-TIPO = 'C'
               ADD TRX-VALOR TO TAB-CLI-SALDO(WS-IDX)
               MOVE TRX-CLI-ID TO WS-LOG-CLID
               MOVE TAB-CLI-NOME(WS-IDX) TO WS-LOG-NOME
               MOVE 'CREDITO'  TO WS-LOG-OPER
               MOVE 'CREDITADO COM SUCESSO'
                               TO WS-LOG-STAT
               WRITE REG-LOG FROM WS-LINHA-LOG
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
