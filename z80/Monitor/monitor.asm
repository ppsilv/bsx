;
; Title:        Z80 Monitor for BSX
; Author:       Dean Belfield
; Created:      12/05/2020
; Last Updated: 05/10/2020
;
; Modinfo:
; 22/05/2020:   Moved SYS_VARS to last page of RAM
;               Added B option to jump to BBC Basic
; 28/05/2020:   Added O(ut) and I(n) instructions
;               Added ASCII column for memory dump
; 29/05/2020:   O(ut) instruction now supports Hex and ASCII strings
; 03/06/2020:   Added Z80 disassembler
; 05/10/2020:   Added UART support, source formatting changes
; 29/09/2024:   Added RS232 baudrate to LCD
;
; Start
;



Start:                  LD      A, 0x80 			; All ports output A,B and C
	                    OUT     (PIO_M), A		; 
                        LD      A, 0x20    
                        OUT     (PIO_A), A
                        IF      SKIP_MEMTEST = 1
                        LD      HL,0x0000
                        XOR     A
                        JR      3F
                        ELSE
                        LD      HL,RAM_START
                        LD      C, 10101010b
1:                      LD      (HL),C
                        LD      A,(HL)
                        CP      C
                        JR      NZ,3F
                        INC     HL
                        LD      A,L
                        OR      A
                        JR      NZ,2F
;                       LD      A,"."
;                       OUT     (PORT_STM_IO),A         ; Output progress - no longer works (STM_IO depreciated)
2:                      LD      A,H
                        OR      A
                        JR      NZ,1B
                        ENDIF
3:                      LD      (SYS_VARS_RAMTOP),HL    ; Store last byte of physical RAM in the system variables
                        LD      SP,HL                   ; Set the stack pointer
                        ;JR      Z,Memtest_OK
                        JR      Memtest_OK
                        LD      HL,MSG_BADRAM
                        JR      Ready
Memtest_OK:             LD      HL,MSG_READY

Ready:                  PUSH    HL                      ; Stack the startup error message
                        LD      HL,UART_BAUD_38400       ; Baud rate = 38400
                        LD      A,0x03                  ; 8 bits, 1 stop, no parity
                        CALL    UART_INIT               ; Initialise the UART
                        ;lcd routines
                        CALL    initializeDisplay
                        LD      HL,MSGLCD001
                        CALL    LcdPrintString
                        LD      A, 0x40
                        CALL    cursorPos
                        LD      HL,MSGLCD002
                        CALL    LcdPrintString

                        LD      HL,MSG_CLEAR
                        CALL    Print_String
                        LD      HL,MSG_STARTUP
                        CALL    Print_String
                        POP     HL
                        CALL    Print_String

;***************************************************************************************
; AREA DE TESTES
;***************************************************************************************
TESTES:
                        ;LD      A,(0x8000)
                        ;JR      TESTES

Input:                  LD      HL,SYS_VARS_INPUT       ; Input buffer
                        LD      B,0                     ; Cursor position
Input_Loop:             CALL    Read_Char               ; Read a key from the keyboard
                        CALL    Print_Char              ; Output the character
                        CP      0x7F
                        JR      Z,Input_Backspace       ; Handle backspace

                        LD      (HL),A                  ; Store the character in the buffer
                        INC     HL                      ; Increment to next character in buffer
                        INC     B                       ; Increment the cursor position
                        CP      0x0D                    ; Check for newline
                        JR      NZ,Input_Loop           ; If not pressed, then loop

                        CALL    Print_CR                ; Output a carriage return

                        LD      A,(SYS_VARS_INPUT)      ; Check the first character of input
                        LD      HL,Input_Ret            ; Push the return address on the stack
                        PUSH    HL
                        CP      'B': JP Z,FN_Basic
                        CP      'D': JP Z,FN_Disassemble
                        CP      'M': JP Z,FN_Memory_Dump
                        CP      'L': JP Z,FN_Memory_Load
                        CP      'J': JP Z,FN_Jump
                        CP      'O': JP Z,FN_Port_Out
                        CP      'I': JP Z,FN_Port_In
                        CP      '2': JP Z,FN_I2c
                        CP      '?': JP Z,Print_Help
                        CP      'H': JP Z,Print_Help
                        CP      'h': JP Z,Print_Help
                        CP      0x0D
                        RET     Z
                        LD      HL,MSG_INVALID_CMD      ; Unknown command error
                        JP      Print_String

Input_Ret:              CALL    Print_CR                ; On return from the function, print a carriage return
                        LD      HL,MSG_READY            ; And the ready message
                        CALL    Print_String
                        JR      Input                   ; Loop around for next input line

Input_Backspace:        LD      A,B                     ; Are we on the first character?
                        OR      A
                        JR      Z,Input_Loop
                        DEC     HL                      ; Skip back in the buffer
                        DEC     B
                        LD      (HL),0
                        JR      Input_Loop

FN_Basic:               JP      BAS_START

FN_Jump:                LD      HL,SYS_VARS_INPUT+1
                        CALL    Parse_Hex16
                        EX      DE,HL
                        JP      (HL)
FN_I2c:                 LD      HL,SYS_VARS_INPUT+1
                        CALL    Parse_Hex8
                        LD      HL,MSG099
                        CALL    Print_String
                        LD      A,E 
                        CALL    Print_Hex8
                        CALL    writeDataToStdi2cDevice
                        RET
FN_Port_Out:            LD      HL,SYS_VARS_INPUT+1
                        CALL    Parse_Hex16
                        LD      A,(HL)
                        CP      ','
                        JR      NZ,FN_Port_Out_Err2
                        INC     HL
                        LD      A,D
                        OR      A
                        JR      NZ,FN_Port_Out_Err1
                        LD      C,E
1:                      LD      A,(HL)
                        CP      0x0D    ; CR
                        RET     Z
                        CP      0x22    ; Quote
                        JR      Z,2F
                        CALL    Parse_Hex8
                        OUT     (C),E
                        JR      1B

2:                      INC     HL
                        LD      A,(HL)
                        CP      0x0D
                        RET     Z
                        CP      0x22
                        JR      Z,3F
                        OUT     (C),A
                        JR      2B
3:                      INC     HL
                        JR      1B

FN_Port_Out_Err1:       LD      HL,MSG_INVALID_PORT
                        JP      Print_String
FN_Port_Out_Err2:       LD      HL,MSG_ERROR
                        JP      Print_String

FN_Port_In:             LD      HL,SYS_VARS_INPUT+1
                        CALL    Parse_Hex16
                        LD      A,(HL)
                        CP      ','
                        JR      NZ,1F
                        INC     HL
                        PUSH    DE
                        CALL    Parse_Hex16
                        POP     BC
                        LD      A,B
                        OR      A
                        JR      NZ,2F
                        LD      A,D
                        OR      E
                        JP      NZ,Port_Dump
1:                      LD      HL,MSG_ERROR
                        JP      Print_String
2:                      LD      HL,MSG_INVALID_PORT
                        JP      Print_String

FN_Memory_Load:         CALL    Read_Char: LD L,A
                        CALL    Read_Char: LD H,A
                        CALL    Read_Char: LD C,A
                        CALL    Read_Char: LD B,A
1:                      CALL    Read_Char
                        LD      (HL),A
                        INC     HL
                        DEC     BC
                        LD      A,B
                        OR      C
                        JR      NZ,1B
                        RET

FN_Disassemble:         LD      HL,SYS_VARS_INPUT+1
                        CALL    Parse_Hex16
                        LD      A,(HL)
                        CP      ','
                        JR      NZ,2F
                        INC     HL
                        PUSH    DE
                        CALL    Parse_Hex16
                        POP     HL
                        LD      B,D
                        LD      C,E
                        LD      IX,SYS_VARS_INPUT
                        LD      A,B
                        OR      C
                        JP      NZ,Disassemble
2:                      LD      HL,MSG_ERROR
                        JP      Print_String

FN_Memory_Dump:         LD      HL,SYS_VARS_INPUT+1
                        CALL    Parse_Hex16
                        LD      A,(HL)
                        CP      ','
                        JR      NZ,2F
                        INC     HL
                        PUSH    DE
                        CALL    Parse_Hex16
                        POP     HL
                        LD      A,D
                        OR      E
                        JP      NZ,Memory_Dump
2:                      LD      HL,MSG_ERROR
                        JP      Print_String

; Print a zero terminated string to the terminal port
; HL: Address of the string
;
Print_String:           LD      A,(HL)
                        OR      A
                        RET     Z
                        CALL    Print_Char
                        INC     HL
                        JR      Print_String

; Dump some ports out
;  C: Port
; DE: Number of bytes to read
;
Port_Dump:              IN      A,(C)
                        CALL    Print_Hex8
                        DEC     DE
                        LD      A,D
                        OR      E
                        RET     Z
                        CALL    Read_Char_NB
                        CP      0x1B
                        RET     Z
                        JR      Port_Dump

; Dump some memory out
; HL: Start of memory to dump
; DE: Number of bytes to dump out
;
Memory_Dump:            CALL    Print_Hex16
                        LD      A,':'
                        CALL    Print_Char
                        LD      A,' '
                        CALL    Print_Char
                        LD      B,16
                        LD      IX,SYS_VARS_INPUT
                        LD      (IX+0),' '
1:                      LD      A,(HL)
                        PUSH    AF
                        CP      32
                        JR      NC,2F
                        LD      A,'.'
2:                      LD      (IX+1),A
                        INC     IX
                        POP     AF
                        CALL    Print_Hex8
                        INC     HL
                        DEC     DE
                        LD      A,D
                        OR      E
                        JR      Z,3F
                        CALL    Read_Char_NB
                        CP      0x1B
                        JR      Z,3F
                        DJNZ    1B
                        CALL    5F
                        JR      Memory_Dump

3:                      LD      A,B
                        OR      A
                        JR      Z,5F
                        DEC     B
                        JR      Z,5F
                        LD      A,32
4:                      CALL    Print_Char
                        CALL    Print_Char
                        DJNZ    4B

5:                      LD      (IX+1),0x0D
                        LD      (IX+2),0x0A
                        LD      (IX+3),0x00
                        PUSH    HL
                        LD      HL,SYS_VARS_INPUT
                        CALL    Print_String
                        POP     HL
                        RET

; Parse a hex string (up to 2 nibbles) to a binary
; HL: Address of hex (ASCII)
;  E: Output
;
Parse_Hex8:             LD      DE,0
                        LD      B,2
                        JR      Parse_Hex

; Parse a hex string (up to 4 nibbles) to a binary
; HL: Address of hex (ASCII)
; DE: Output
;
Parse_Hex16:            LD      DE,0                    ; Clear the output
                        LD      B,4                     ; Maximum number of nibbles
Parse_Hex:              LD      A,(HL)                  ; Get the nibble
                        SUB     '0'                     ; Normalise to 0
                        RET     C                       ; Return if < ASCII '0'
                        CP      10                      ; Check if >= 10
                        JR      C,1F
                        SUB     7                       ; Adjust ASCII A-F to nibble
                        CP      16                      ; Check for > F
                        RET     NC                      ; Return
1:                      SLA     DE                      ; Shfit DE left 4 times
                        SLA     DE
                        SLA     DE
                        SLA     DE
                        OR      E                       ; OR the nibble into E
                        LD      E,A
                        INC     HL                      ; Increase pointer to next byte of input
                        DJNZ    Parse_Hex               ; Loop around
                        RET

; Print a 16-bit HEX number
; HL: Number to print
;
Print_Hex16:            LD      A,H
                        CALL    Print_Hex8
                        LD      A,L

; Print an 8-bit HEX number
; A: Number to print
;
Print_Hex8:             LD      C,A
                        RRA
                        RRA
                        RRA
                        RRA
                        CALL    1F
                        LD      A,C
1:                      AND     0x0F
                        ADD     A,0x90
                        DAA
                        ADC     A,0x40
                        DAA
                        JR      Print_Char

; Print CR/LF
;
Print_CR:               LD      A,0x0D
                        CALL    Print_Char
                        LD      A,0x0A
                        JP      Print_Char

; Print a single character
; A: ASCII character
;
Print_Char:             JP      UART_TX

; Read a character - waits for input
; NB is the non-blocking variant
;  A: ASCII character read
;  F: NC if no character read (non-blocking)
;  F:  C if character read (non-blocking)
;
Read_Char:              CALL    UART_RX
                        JR      NC,Read_Char
                        RET
Read_Char_NB:           JP      UART_RX

;Print_Char_STM32:      OUT     (PORT_STM_IO),A
;                       RET
;Read_Char_STM32:       CALL    Read_Char_NB_STM32
;                       JR      NC,Read_Char_STM32
;                       RET
;Read_Char_NB_STM32:    IN      A,(PORT_STM_FLAGS)
;                       AND     0x01
;                       RET     Z
;                       IN      A,(PORT_STM_IO)
;                       OR      A
;                       RET     Z
;                       SCF
;                       RET

;******************************************************
;This routine prints help
;by pdsilva

Print_Help:
						LD      HL,MSG000
                        CALL    Print_String
                        LD      HL,MSG001
                        CALL    Print_String
                        LD      HL,MSG002
                        CALL    Print_String
                        LD      HL,MSG003
                        CALL    Print_String
                        LD      HL,MSG004
                        CALL    Print_String
                        LD      HL,MSG005
                        CALL    Print_String
                        LD      HL,MSG006
                        CALL    Print_String
                        LD      HL,MSG007
                        CALL    Print_String
                        LD      HL,MSG008
                        CALL    Print_String
                        LD      HL,MSG098
                        CALL    Print_String
                        RET
                        
;
; Messages
;
MSG_STARTUP:            DZ "BSX Version 0.3.3\n\r"
MSG_CLEAR:              DZ "\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r\n\r"
MSG_READY:              DZ "Ready:> "
MSG_BADRAM:             DZ "Mem Fault\n\r"
MSG_ERROR:              DZ "Error\n\r"
MSG_INVALID_CMD:        DZ "Invalid Command\n\r"
MSG_INVALID_PORT:       DZ "Invalid Port #\n\r"
MSG_OUT_OF_RANGE:       DZ "Value out of range\n\r"
MSG000: DZ "Help  \n\r"
MSG001: DZ "  - Mnnnn,llll - Memory Hex Dump: Output llll bytes from memory location nnnn \n\r"
MSG002: DZ "  - Jnnnn - Jump to location nnnn \n\r"
MSG003: DZ "  - Onn,vv - O(utput) the value vv on Z80 port nn \n\r"
MSG004: DZ "  - Inn,llll - I(nput) llll values from Z80 port nn \n\r"
MSG005: DZ "  - L - Put the monitor into Load mode; it will wait for a binary stream of data on port 0 \n\r"
MSG006: DZ "  - B - Jump to address 0x4000 (where BBC Basic can be loaded) \n\r"
MSG007: DZ "  - 2nn - Send this data to standard I2C chip\n\r"
MSG008: DZ "  - Dnnnn,llll - Disassemble llll bytes from memory location nnnn \n\r"
MSG098: DZ "  - ? or H - Show this help \n\r"

MSG099: DZ "  - Sending this value: "
MSG100: DZ " to I2C chip: \n\r"

MSGLCD001: DZ "BSX by pdsilva  "
MSGLCD002: DZ "V0.3.3 Uart38400"


