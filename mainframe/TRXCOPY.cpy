      * COPYBOOK - REGISTRO DE TRANSACOES
      * LRECL=20
       01  REG-TRANSACAO.
           05  TRX-CLI-ID    PIC 9(05).
           05  TRX-ID        PIC 9(05).
           05  TRX-TIPO      PIC X(01).
           05  TRX-VALOR     PIC 9(09).
