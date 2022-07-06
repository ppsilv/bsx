;
; Title:	TL16C550CN UART code
; Author:       Dean Belfield
; Created:      12/05/2020
; Co Author:	Paulo da Silva(pdsilva | pgordao)
; Since:		03/07/2022
; Last Updated:	03/07/2022
;
; Modinfo:
;

UART_PORT:		EQU	0xB8		; UART Z80 port base address
UART_BAUD:		EQU	115200		; Maximum baud rate
UART_FREQUENCY: EQU 19660800	; 82C50 | 16C550 CLOCK

UART_REG_RBR:		EQU	UART_PORT+0	; Receive buffer
UART_REG_THR:		EQU	UART_PORT+0	; Transmitter holding
UART_REG_DLL:		EQU	UART_PORT+0	; Divisor latch low
UART_REG_IER:		EQU	UART_PORT+1	; Interrupt enable
UART_REG_DLH:		EQU	UART_PORT+1	; Divisor latch high
UART_REG_IIR:		EQU	UART_PORT+2	; Interrupt identification
UART_REG_LCR:		EQU	UART_PORT+3	; Line control
UART_REG_MCR:		EQU	UART_PORT+4	; Modem control
UART_REG_LSR:		EQU	UART_PORT+5	; Line status
UART_REG_MSR:		EQU	UART_PORT+6	; Modem status
UART_REG_SCR:		EQU UART_PORT+7	; Scratch

UART_TX_WAIT		EQU	600		; Count before a TX times out

; HL: Address in baud rate table
;  A: Flow control bits
; 
UART_INIT:	PUSH	AF
			LD		A,(HL)
			INC 	HL
			LD		H,(HL)
			LD 		L,A
			LD		A,0x00: OUT (UART_REG_IER),A	; Disable interrupts
			LD		A,0x80: OUT (UART_REG_LCR),A 	; Turn DLAB on
			LD		A,L:	OUT (UART_REG_DLL),A	; Set divisor low
			LD		A,H:	OUT (UART_REG_DLH),A	; Set divisor high
			POP		AF:		OUT (UART_REG_LCR),A	; Write out flow control bits
			LD 		A, 0x81							; Turn on FIFO, with trigger level of 8.
			OUT (UART_REG_IIR), A					; This turn on the 16bytes buffer!	
			RET

; A: Data to write
; Returns:
; F = C if written
; F = NC if timed out
;
UART_TX:	PUSH 	HL 
			PUSH 	DE 
			PUSH	BC						; Stack BC
			PUSH	AF 						; Stack AF
			LD	B,low  UART_TX_WAIT			; Set CB to the transmit timeout
			LD	C,high UART_TX_WAIT
1:			IN	A,(UART_REG_LSR)			; Get the line status register
			AND 	0x60					; Check for TX empty
			JR	NZ,2F						; If set, then TX is empty, goto transmit
			DJNZ	1B: DEC	C: JR NZ,1B		; Otherwise loop
			POP	AF							; We've timed out at this point so
			POP	BC							; Restore the stack
			OR	A							; Clear the carry flag and preserve A
			RET	
2:			POP	AF							; Good to send at this point, so
			OUT	(UART_REG_THR),A			; Write the character to the UART transmit buffer
			call	delay2
			POP	BC							; Restore the stack
			POP DE 
			POP	HL
			SCF								; Set the carry flag
			RET 

; A: Data read
; Returns:
; F = C if character read
; F = NC if no character read
;
UART_RX:	IN	A,(UART_REG_LSR)		; Get the line status register
			AND 	0x01				; Check for characters in buffer
			RET	Z						; Just ret (with carry clear) if no characters
			IN	A,(UART_REG_RBR)		; Read the character from the UART receive buffer
			SCF 						; Set the carry flag
			RET

; Baudrates
;
UART_BAUD_9600:		DW	UART_FREQUENCY/(9600 * 16)
UART_BAUD_14400:	DW	UART_FREQUENCY/(14400 * 16)
UART_BAUD_19200:	DW	UART_FREQUENCY/(19200 * 16)
UART_BAUD_38400:	DW	UART_FREQUENCY/(38400 * 16)
UART_BAUD_57600:	DW	UART_FREQUENCY/(57600 * 16)
UART_BAUD_115200:	DW	UART_FREQUENCY/(115200 * 16)
