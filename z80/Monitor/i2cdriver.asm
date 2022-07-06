;Z80 I2C driver
;Author: Paulo da Silva (pdsilva|pgordao)
;Date..: 04/07/2022 an important day( USA Independence  ) 
;
;to compile zmac i2cdriver.z80 -o i2cdriver.hex


SCL			.EQU	$80	
SDA_WR		.EQU	$88	
SDA_RD		.EQU	$B0
LCD_ADDR	.EQU	0x27 ;the PCF8574 address
	
i2cInit:
	call	start_i2c
	ret

;******************************************************************
; This routines tests I2C bus with address 0x27 and sent 0xA% data
;
testeI2c:
    call    i2c_start_condition
	call	set_addr
	call	delay40US
    ld      A, 0x5A
    call    putbyte
	call	i2c_stop_condition
	call	delay40US
	call	delay40US
	call	delay40US
	call	delay40US
	call	delay40US
	jp      testeI2c

;******************************************************************
; Write data in A (acumulator) to I2C devices
; inputs    A = datum to be wrote.
;           B = device address 
; outputs   FC = flag carry 0=ok, != 0 = Error (missing implementation)
;
writeDataToi2cDevice:
	push	AF
    call    i2c_start_condition
	;call	set_addr_gen
	call	set_addr ; SET_ADDR ESCREVE NO DEFAULT set_addr_gen escrebe no device apontado por reg B
	call	delay40US
	pop		AF
	push	AF
    call    putbyte
	call	i2c_stop_condition
	call	delay40US
	pop		AF
    ret

;******************************************************************
; Write data in A (acumulator) to DEFAULT I2C devices
; inputs    A = datum to be wrote.
;          
; outputs   FC = flag carry 0=ok, != 0 = Error (missing implementation)
;
writeDataToStdi2cDevice:
	push	AF
    call    i2c_start_condition
	call	set_addr
	call	delay40US
	pop		AF
    call    putbyte
	call	i2c_stop_condition
	call	delay40US
    ret	

;******************************************************************
; This routine sends the address to the slave device to write data.
; to read its necessary implement a new one from this one.
set_addr:		    ; Reset device address counter to 00h, for i2c device on address D0
	ld 	a,LCD_ADDR	; Write Addr
    sla a
	call seti2cWR	;
	call get_ack	;	
	ret

;******************************************************************
; This routine sends the address to the slave device to write data.
; to read its necessary implement a new one from this one.
set_addr_gen:		    ; Reset device address counter to 00h, for i2c device on address D0
	ld 	a,b	; Write Addr
    sla a
	call seti2cWR	;
	call get_ack	;	
	ret



;******************************************************************
; This routines getack but is missing the test to verify ACK
;
get_ack:	; Get ACK from i2c slave
	call sclset			
	in		A,(SDA_RD)
	LD		B, A
	call sclclr
	CP	B, 0
	JP	NZ, get_ack 	
	ret
	; ToDo - implement the ACK timeout, right now we blindly assume the ACK came in.


;******************************************************************
; This routine was not tested yet!!!
;
getbyte:	; Read 8 bits from i2c bus
        push bc
		ld b,8
gb1:    call    sclset          ; Clock UP
		in A,(SDA_RD)			; SDA (RX data bit) is in A.0
		rrca					; move RX data bit to CY
		rl      c              	; Shift CY into C
        call    sclclr          ; Clock DOWN
        djnz    gb1
        ld a,c             		; Return RX Byte in A
		pop bc
        ret


;******************************************************************
; This routine write slave's address and set to write
;
seti2cWR: 	; Send byte from A to i2C bus
        push    bc
        ld      c,a             ;Shift register
        ld      b,7
pbks11: sla     c               ;B[7] => CY
        jr		nc, putL1
		call	putBitSdaHigh
		jp		cont1
putL1:  call	putBitSdaLow

cont1:  djnz    pbks11
		call	putBitSdaLow	;8th bit to sign a write operation
        pop     bc
        ret

;******************************************************************
; This routine write slave's address and set to read
;
seti2cRD: 	; Send byte from A to i2C bus
        push    bc
        ld      c,a             ;Shift register
        ld      b,7
pbks12: sla     c               ;B[7] => CY
        jr		nc, putL2
		call	putBitSdaHigh
		jp		cont2
putL2:  call	putBitSdaLow

cont2:  djnz    pbks12
		call	putBitSdaHigh	;8th bit to sign a write operation
        pop     bc
        ret


	
;******************************************************************
; This routine write a data byte in slave device
;
putbyte: 	; Send byte from A to i2C bus
        push    bc
        ld      c,a             ;Shift register
        ld      b,8
pbks1:  sla     c               ;B[7] => CY
        jr		nc, putL
		call	putBitSdaHigh
		jp		cont
putL:   call	putBitSdaLow
cont:   djnz    pbks1
        call    get_ack
		CP		A, 0
		JP		Z, END
        LD      HL,MSG_NOacck
        CALL    Print_String		
END:    pop     bc
        ret

;******************************************************************
; This routine initializes the I2C bus
start_i2c:          ; i2c START sequence, SDA goes LO while SCL is HI
			call	sdaset
			call	delay40US
			call    sclset
			call	delay40US
			call	delay40US
			call	delay40US
			call	delay40US
			call	delay40US
			ret

;******************************************************************
; Put SCL high widthout changing the SDA value.
;
scl_high:
sclset: 
        ld      a,$01
        out     (SCL),a
		call delay40US
        ret

;******************************************************************
; Put SCL low widthout changing the SDA value.
;
scl_low;
sclclr:  ; SCL LO without changing SDA       	
        ld      a, $00
        out     (SCL),a
		call delay40US
        ret

;******************************************************************
; Put SDA high widthout changing the SCL value.
;
sda_high:
sdaset:	; SDA HI without changing SCL
        ld      a, $01
        out     (SDA_WR),a
		call delay40US
        ret

;******************************************************************
; Put SDA low widthout changing the SCL value.
;
sda_low: ; SDA LO without changing SCL   	
sdaclr:
        ld     a, $00
        out     (SDA_WR),a
		call delay40US
        ret

;******************************************************************
; This routine write 0 in the the SDA bus
;
putBitSdaLow:
		call sda_low
		call sclset
		call delay40US
		call sclclr
		ret

;******************************************************************
; This routine write 1 in the the SDA bus
;
putBitSdaHigh:
		call sda_high
		call sclset
		call delay40US
		call sclclr
		ret
;******************************************************************
; I2C start condition
;
i2c_start_condition:
        call	sda_low
        call delay40US
        call	scl_low
        call delay40US
        ret

;******************************************************************
; I2C stop condition
;
i2c_stop_condition:
        ;Now stop condition
		call	scl_high
		call 	delay40US
		call	sda_high
		call	delay40US
		ret
;******************************************************************
; I2C teste
;
i2c_test:
        ld      b, 0x27
        ld      a, 0x5a
        call writeDataToi2cDevice
        ld      bc,0x8000
        call    delay40US
        ld      b, 0x27
        ld      a, 0xa5
        call writeDataToi2cDevice
        ld      bc,0x8000
        call    delay40US
        jp i2c_test		


MSG_NOacck: DZ " noack...\n\r"		
		
		