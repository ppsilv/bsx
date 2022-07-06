


PIO_A	equ	0xA8		; CA80 user 8255 base address 	  (port A)
PIO_B	equ	0xA9		; CA80 user 8255 base address + 1 (port B)
PIO_C	equ	0xAA		; CA80 user 8255 base address + 2 (fport C)
PIO_M	equ	0xAB		; CA80 user 8255 control register


INIT_PIO:
        	LD      A, 0x80 			; All ports output A,B and C
	        OUT     (PIO_M), A		; 
            RET

WRITE_PORTA:
            OUT     (PIO_A), A
            RET

WRITE_PORTB:
            OUT     (PIO_B), A
            RET

WRITE_PORTC:
            OUT     (PIO_C), A
            RET
