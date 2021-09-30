TITLE Low-Level I/O Procedures     (prog06_ennisa.asm)

; Author: Aaron Ennis
; Last Modified: 09 June 2020
; OSU email address: ennisa@oregonstate.edu
; Course number/section: CS271-401
; Project Number: 06	Due Date: 07 June 2020
; Description:	This program implements low-level I/O procdures to collect 10
;				32-bit signed integers from a user as keyboard string input.
;				It then validates the input, converts the string input to its
;				integer value and calculates the sum and average of the values.
;				Then each entered value, their sum, and their average are
;				displayed on the screen.

INCLUDE Irvine32.inc
; Constants
NUM_INTS = 10

; Macros
;-------------------------------------------------------------------------------
; 		Description: This macro gets input from the keyboard and stores it in
;					 a location in memory.
; 		 Parameters: A memory location for a prompt string, a memory location
;					 for an input string, and the max length of input.
; 	  Preconditions: There should a string prompt defined at the supplied memory
;					 location.
; Registers Changed: edx
;-------------------------------------------------------------------------------
getString MACRO promptAddr, inputAddr, inputLen
	push	edx
	mov		edx, promptAddr
	call	WriteString
	pop		edx
	push	ecx
	push	edx
	mov		edx, inputAddr
	mov		ecx, inputLen
	call	ReadString
	pop		edx
	pop		ecx
ENDM

;-------------------------------------------------------------------------------
; 		Description: This macro displays a string at a provided memory location.
; 		 Parameters: A memory location for a string.
; 	  Preconditions: There should a string defined at the supplied memory
;					 location.
; Registers Changed: edx
;-------------------------------------------------------------------------------
displayString MACRO stringNumber
	push	edx
	mov		edx, stringNumber
	call	WriteString
	pop		edx
ENDM

.data
; Variables to hold display strings
progTitle		BYTE	"	Designing Low-Level I/O Procedures"
				BYTE	" by Aaron Ennis", 0
greeting		BYTE	"In this program, you will be prompted to enter 10 "
				BYTE	"signed decimal integers.", 0dh, 0ah
				BYTE	"Each integer should fit inside a 32-bit register.", 0dh, 0ah
				BYTE	"After all integers have been entered and validated, "
				BYTE	"I will display ", 0dh, 0ah
				BYTE	"a list of the integers, their sum, and their average.", 0
intPrompt		BYTE	"Please enter a signed decimal integer: ", 0
intError		BYTE	"ERROR: Not a signed integer or integer too big.", 0
numbers			BYTE	"You entered the following numbers:", 0
intSum			BYTE	"The sum of these numbers is: ", 0
intAvg			BYTE	"The rounded average is: ", 0
spacing			BYTE	"  ", 0
goodbye			BYTE	"Goodbye! ", 0

; Other variables
intArray	SDWORD	NUM_INTS DUP(0)
sumArray	SDWORD	?
intString	BYTE	12 DUP(?)	; max 11 chars for signed 32-bit int +1 for EOS
strLen		DWORD	LENGTHOF intString

.code
main PROC
	; Display the introduction
	push	OFFSET progTitle
	push	OFFSET greeting
	call	introduction

	; Get integers
	push	edi
	push	ecx
	mov		edi, OFFSET intArray
	mov		ecx, NUM_INTS
	GetInteger:
		push	OFFSET intPrompt
		push	OFFSET intError
		push	OFFSET intString
		push	strLen	
		push	edi
		call	readVal
		add		edi, 4
		loop	GetInteger
	pop		ecx
	pop		edi


	; Display the integers
	push	edx
	mov		edx, OFFSET numbers
	call	WriteString
	call	CrLf
	pop		edx
	push	esi
	push	ecx
	mov		esi, OFFSET intArray
	mov		ecx, NUM_INTS
	DisplayInteger:
		push	OFFSET intString
		push	[esi]
		call	writeVal
		add		esi, 4
		push	edx
		mov		edx, OFFSET spacing
		call	WriteString
		pop		edx
		loop	DisplayInteger
	call	CrLf

	; Calculate the sum of the integers
	push	OFFSET intArray
	push	NUM_INTS
	push	OFFSET sumArray
	call	calcArraySum

	; Display the sum of the integers
	displayString OFFSET intSum
	push	OFFSET intString
	push	sumArray
	call	writeVal
	call	CrLf

	; Calculate the rounded average of the integers
	mov		eax, sumArray
	mov		ebx, NUM_INTS
	cdq
	idiv	ebx

	; Display the rounded average of the integers
	displayString OFFSET intAvg
	push	OFFSET intString
	push	eax
	call	writeVal
	call	Crlf

	displayString OFFSET goodbye

	exit	; exit to operating system
main ENDP

;-------------------------------------------------------------------------------
; 		Description: This procedure displays the introduction information and
;					 instructions for the program.
; 		   Receives: References to the program title and introduction text on
;					 the system stack 
; 			Returns: Nothing
; 	  Preconditions: progTitle and greeting should be defined as
;					 strings in the .data section
; Registers Changed: edx
;-------------------------------------------------------------------------------
introduction PROC
	push	ebp
	mov		ebp, esp
	push	edx
	mov		edx, [ebp+12]
	call	WriteString
	pop		edx
	call	CrLf
	call	CrLf
	push	edx
	mov		edx, [ebp+8]
	call	WriteString
	pop		edx
	call	CrLf
	call	CrLf
	pop		ebp	
	ret		8
introduction ENDP

;-------------------------------------------------------------------------------
; 		Description: This procedure reads a string from the keyboard via a
;					 macro, and converts it to a signed integer value. If the
;					 string cannot be converted, an error message is displayed
;					 and the user is prompted to re-enter until a valid number
;					 is entered.
; 		   Receives: A string to prompt for input (by reference), a string to 
;					 hold that input (by reference), and its max length, a
;					 string that holds an error message (by refernce), and an
;					 address to store the converted string (by reference)
; 			Returns: A signed 32-bit integer
; 	  Preconditions: 
; Registers Changed: eax, ebx, edx, ecx, esi
;-------------------------------------------------------------------------------
readVal PROC
	push	ebp
	mov		ebp, esp
	push	edx
	push	esi
	push	ecx
	push	eax
	push	ebx
	push	edi
	StartRead:
	mov		edx, [ebp+24]		; intPrompt
	mov		esi, [ebp+16]		; intString
	mov		ecx, [ebp+12]		; strLen
	mov		edi, [ebp+8]
	getString edx, esi, ecx
	; Check initial character for: "+", "-", or "0"/null
	lodsb
	mov		edx, 0		; this will contain our converted integer
	mov		ebx, 1		; use to indicate sign (assume positive)
		CheckNull:
			cmp		al, 0
			je		DisplayError
		CheckPos:
			cmp		al, 43
			je		PosInt
			jmp		CheckNeg
		PosInt:						; If "+" detected in first position
			dec		ecx				; manually decrement 
			lodsb					; load the next byte
			cmp		al, 0			; and make sure it's not null
			je		DisplayError
			jmp		Convert			; before jumping to convert
		CheckNeg:
			cmp		al, 45
			je		NegInt
			jmp		Convert
		NegInt:						; If "-" detected in first position
			mov		ebx, -1			; set the sign indicator to negative
			dec		ecx				; manually decrement
			lodsb					; load the next byte
			cmp		al, 0			; and make sure it's not null
			je		DisplayError
			jmp		Convert			; before jumping to convert

	Convert:
		cmp		al, 0				; Check for end of string
		je		EndRead
		cmp		al, 48				; If ASCII value is less than 48
		jl		DisplayError		; it's not a digit
		cmp		al, 57				; If ASCII value is greater than 57
		jg		DisplayError		; it's not a digit
		sub		eax, 48				; Calulate the digit value
		imul	edx, 10				; Convert old value to next base 10
		jc		DisplayError		; if CF is set after IMUL, it's too big
		add		edx, eax			; Add the new digit to the old value
		jo		EndRead				; if OF is set, we might be done
		lodsb
		loop	Convert

	DisplayError:
		mov		edx, [ebp+20]	; intError
		call	WriteString
		call	CrLf
		jmp		StartRead
	EndRead:
		mov		eax, edx
		mov		edx, 0
		imul	ebx
		js		CheckSign		; If SF=1, check it wasn't due to overflow
		jmp		SaveValue
	CheckSign:
		cmp		ebx, -1			; If SF=1, but a neg wasn't entered,
		jne		DisplayError	; it was set due to overflow/carry
	SaveValue:
		mov		[edi], eax	; put the into into the memory location
	pop		edi
	pop		ebx
	pop		eax
	pop		ecx
	pop		esi
	pop		edx
	pop		ebp
	ret		20
readVal ENDP

;-------------------------------------------------------------------------------
; 		Description: This procedure converts a numeric value to a string and
;					 displays it on the screen via a macro.
; 		   Receives: An array of 32-bit signed integers (by reference), and a
;					 memory location to accumulate the converted string
; 			Returns: None
; 	  Preconditions: The array should already be populated
; Registers Changed: eax, ebx, ecx, edx, esi, edi, ebp
;-------------------------------------------------------------------------------
writeVal PROC
	push	ebp
	mov		ebp, esp
	push	eax
	push	edi
	push	edx
	push	ebx
	push	ecx
	push	esi
	mov		eax, [ebp+8]		; number from intArray
	mov		edi, [ebp+12]		; memory location to keep the converted string
	mov		ecx, 0				; to keep track of string size
	mov		ebx, 10				; divisor
	mov		esi, 1				; Use esi as the sign indicator. Assume positive
	cmp		eax, 0				; Check for negative value
	jg		IntToAscii
	mov		esi, -1
	imul	eax, esi			; swap the sign on the negative value
	; while eax >= 0
	IntToAscii:
	cdq
	idiv	ebx
	add		edx, 48				; add 48 to remainder to get ASCII value
	push	edx					; we'll use the stack as temp storage for the string
	inc		ecx					; increment the string size
	cmp		eax, 0
	jg		IntToAscii
	; String is in reverse order, so we need to reverse it
	cmp		esi, 0				; sign indicator from above
	jg		LoadString		; If sign indicator positive	
	; If sign indicator is negative, we need to first add a "-" sign
	mov		eax, 45			; ASCII 45 = "-"
	stosb					; store the "-" in edi
	LoadString:
		pop		eax
		stosb
		loop	LoadString
	mov		edi, [ebp+12]
	displayString edi
	pop		esi
	pop		ecx
	pop		ebx
	pop		edx
	pop		edi
	pop		eax
	pop		ebp
	ret		8
writeVal ENDP

;-------------------------------------------------------------------------------
; 		Description: This procedure calculates the sum of an array of  signed 
;					 32-bit integers.
; 		   Receives: A array of signed 32-bit integers (by reference), its 
;					 length (by value), and a memory location to store the sum.
; 			Returns: The sum of the array in the referenced memory location.
; 	  Preconditions: The provided array should be filled with signed 32-bit
;					 integers.
; Registers Changed: 
;-------------------------------------------------------------------------------
calcArraySum PROC
	push	ebp
	mov		ebp, esp
	push	eax
	push	ecx
	push	edx
	push	ebx
	mov		eax, [ebp+16]		; address of intArray
	mov		ecx, [ebp+12]		; NUM_INTS
	mov		edx, [ebp+8]		; address of sumArray
	Calculate:
		mov		ebx, [eax]
		add		[edx], ebx
		add		eax, 4
		loop	Calculate
	pop		ebx
	pop		edx
	pop		ecx
	pop		eax
	pop		ebp
	ret		12
calcArraySum ENDP

END main