; How to use lcd routines
;                        CALL    initializeDisplay
;                        LD      HL,MSGLCD001
;                        CALL    LcdPrintString
;                        LD      A, 0x40
;                        CALL    cursorPos
;                        LD      HL,MSGLCD002
;                        CALL    LcdPrintString
;
;

;commands
LCD_CLEARDISPLAY   	EQU	0x01
LCD_RETURNHOME     	EQU	0x02
LCD_ENTRYMODESET   	EQU	0x04
LCD_DISPLAYCONTROL 	EQU	0x08
LCD_CURSORSHIFT    	EQU	0x10
LCD_FUNCTIONSET    	EQU	0x20
LCD_SETCGRAMADDR   	EQU	0x40
LCD_SETDDRAMADDR   	EQU	0x80

;flags for display entry mode
LCD_ENTRYRIGHT 		    EQU	0x00
LCD_ENTRYLEFT 		    EQU	0x02
LCD_ENTRYSHIFTINCREMENT EQU	0x01
LCD_ENTRYSHIFTDECREMENT EQU	0x00

;flags for display on/off control
LCD_DISPLAYON  	EQU	0x04
LCD_DISPLAYOFF 	EQU	0x00
LCD_CURSORON   	EQU	0x02
LCD_CURSOROFF  	EQU	0x00
LCD_BLINKON    	EQU	0x01
LCD_BLINKOFF   	EQU	0x00

;flags for display/cursor shift
LCD_DISPLAYMOVE 	EQU	0x08
LCD_CURSORMOVE  	EQU	0x00
LCD_MOVERIGHT   	EQU	0x04
LCD_MOVELEFT    	EQU	0x00

;flags for function set
LCD_8BITMODE 		EQU	0x10
LCD_4BITMODE 		EQU	0x00
LCD_2LINE    		EQU	0x08
LCD_1LINE    		EQU	0x00
LCD_5x10DOTS 		EQU	0x04
LCD_5x8DOTS  		EQU	0x00

;flags for backlight control
LCD_BACKLIGHT 		EQU	0x08
LCD_NOBACKLIGHT 	EQU	0x00

BlON    EQU    0x08    ;   B00001000  Enable back light     pino 7 PCF8574
EnOR 	EQU    0x04    ;   B00000100  Enable bit            pino 6 PCF8574
EnAND 	EQU    0xFB    ;   B11111011  Enable bit            pino 6 PCF8574
Rw 	    EQU	0x02    ;   B00000010  Read/Write bit        pino 5 PCF8574
RsCMD 	EQU	0xF0    ;   B11111000  ZERO RS, R/W, EN
RsDATA 	EQU	0x01    ;   B00000001  Register select bit   pino 4 PCF8574
; pino  9 PCF8574 D4
; pino 10 PCF8574 D5
; pino 11 PCF8574 D6
; pino 12 PCF8574 D7

_displayfunction   .EQU (LCD_FUNCTIONSET | LCD_4BITMODE | LCD_1LINE | LCD_5x8DOTS);
_displaymode       .EQU (LCD_ENTRYMODESET | LCD_ENTRYLEFT | LCD_ENTRYSHIFTDECREMENT) ;
_backlightval      .EQU (LCD_BACKLIGHT);	
_displaycontrol    .EQU (LCD_DISPLAYCONTROL | LCD_DISPLAYON | LCD_CURSOROFF | LCD_BLINKOFF )


backlightON:
        LD      A, LCD_BACKLIGHT
        CALL    writeDataToi2cDevice
        RET

backlightOFF:
        LD      A, 0x00
        CALL    writeDataToi2cDevice
        RET

 
writeDataToLcd:
        PUSH    AF
        AND     A, 0xF0
        OR      A, RsDATA
        OR      A, LCD_BACKLIGHT
        CALL    writeDataToi2cDevice
        CALL    pulseEnable
        POP     AF
        SLA     A
        SLA     A
        SLA     A
        SLA     A
        OR      A, RsDATA
        OR      A, LCD_BACKLIGHT
        CALL    writeDataToi2cDevice
        CALL    pulseEnable
        RET

writeCmdToLcd:
        PUSH    AF
        AND     A, RsCMD
        CALL    writeDataToi2cDevice
        CALL    pulseEnable
        POP     AF
        SLA     A
        SLA     A
        SLA     A
        SLA     A
        AND     A, RsCMD
        CALL    writeDataToi2cDevice
        CALL    pulseEnable
        RET

writeHalfCmdToLcd:
        AND     A, RsCMD
        CALL    writeDataToi2cDevice
        CALL    pulseEnable
        RET


; input: Data in A
pulseEnable:
        PUSH    BC
        PUSH    AF
        OR      A, EnOR
        call    writeDataToi2cDevice
        LD      BC, 1
        call    delay
        POP     AF
        AND     A, EnAND
        call    writeDataToi2cDevice
        LD      BC, 1
        CALL    delay
        POP     BC 
        RET

displayCLEAR:
        LD      A, LCD_CLEARDISPLAY
        CALL    writeCmdToLcd
        LD      BC, 4
        CALL    delay
        RET

displayON:
        LD      A, 0x0C         ;REG DISPLAY CONTROL AND  DISPLAY ON 
        CALL    writeCmdToLcd
        LD      BC, 4
        CALL    delay
        RET

displayOFF:
        LD      A, 0x08
        CALL    writeCmdToLcd
        LD      BC, 4
        CALL    delay
        RET

displayEntryMode:
        LD      A, 0x06
        CALL    writeCmdToLcd
        LD      BC, 4
        CALL    delay
        RET

displayHome:
        LD      A, LCD_RETURNHOME
        CALL    writeCmdToLcd
        LD      BC, 4
        CALL    delay
        RET


;This must be called before any cmd, except read busy flag
functionSet:
        LD      A, 0x28 ; 2 lines 4 bits data lenght
        CALL    writeCmdToLcd
        LD      BC, 4
        CALL    delay
        RET

cursorPos: ; Expect position on A reg. 
           ; Line 0 col 0 = 0x00
           ; Line 1 col 0 = 0x40
        OR      A, LCD_SETDDRAMADDR 
        CALL    writeCmdToLcd
        LD      BC, 4
        CALL    delay
        RET

initializeDisplay:
        LD      BC, 0x2700      ;Wait for 50ms before display initialization.
        CALL    delay
        LD      A, 0x30         ;Initializing by instruction
        CALL    writeHalfCmdToLcd
        LD      BC, 325
        CALL    delay
        LD      A, 0x30         ;Initializing by instruction
        CALL    writeHalfCmdToLcd
        LD      BC, 325
        CALL    delay
        LD      A, 0x30         ;Initializing by instruction
        CALL    writeHalfCmdToLcd
        LD      BC, 325
        CALL    delay
        LD      A, 0x20         ;End Initializing by instruction
        CALL    writeHalfCmdToLcd
        CALL    delay100US

        CALL    functionSet
        CALL    displayON
        CALL    displayCLEAR
        CALL    displayEntryMode


        LD      BC, 225
        CALL    delay
 
        CALL    displayHome

        ;LD      A,0x41
        ;CALL    writeDataToLcd
        RET




LcdPrintChar:           JP      writeDataToLcd

LcdPrintString:         LD      A,(HL)
                        OR      A
                        RET     Z
                        CALL    LcdPrintChar
                        INC     HL
                        JR      LcdPrintString





        
