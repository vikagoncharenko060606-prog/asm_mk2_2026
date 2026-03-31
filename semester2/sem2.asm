.386

stack_seg segment para stack 'stack' use16
    db 65535 dup(?)
stack_seg ends

data_seg segment para 'data' use16 
    formated_string_buffer db 256 dup(0)
    formated_string_buffer2 db 256 dup(0)
    formated_string_buffer3 db 256 dup(0)

    prompt_string db 1024 dup (?)
; messages
    msg_enter_numerical_system db 'enter input numerical system(h - hex):', 0
    msg_enter_expression db 'enter expression(for example: "-f + 1", "2 + 2"):', 0
    output_dec_msg db 'decimal: ', 0
    msg_hex db 'hex: ', 0

; errors
    overflow_msg db 'ERROR: Overflow!',  0dh, 0ah, 0
    invalid_exp_msg db 'ERROR: Invalid format',  0dh, 0ah, 0
    invalid_exp_operation_msg db 'ERROR: Invalid operator!',  0dh, 0ah, 0
    divide_by_zero db 'ERROR: Division by zero!',  0dh, 0ah, 0
    invalid_number_msg db 'ERROR: Invalid number',  0dh, 0ah, 0

    msg_vec dw offset overflow_msg, offset invalid_exp_msg, offset invalid_exp_operation_msg
            dw offset divide_by_zero, offset invalid_number_msg

    ERROR_OVERFLOW equ 0
    ERROR_INVALID_EXPRESSION equ 1
    ERROR_INVALID_EXPRESSION_OP equ 2
    ERROR_DIVIDE_BY_ZERO equ 3
    ERROR_INVALID_NUMBER equ 4

; global variables
    atoi_ptr     dw 0           ; pointer to conversion function (atoi_dec or atoi_hex)
    result_a     dw 0           ; first operand
    result_b     dw 0           ; second operand
    result_op    db 0           ; operation

data_seg ends

code_seg segment para 'code' use16
    assume cs:code_seg, ds:data_seg, ss:stack_seg



; _putstr - Output null-terminated string to standard output (via DOS 02h)
; Input:
;   [bp+4] = string address
; Output: none

_putstr:
    push bp
    mov bp, sp

    mov di, word ptr [bp+4]   ; DI = string address

    mov ah, 02h               ; DOS character output function

_putstr_loop:
    mov dl, byte ptr [di]     ; next character
    int 21h                   ; output

    inc di
    test dl, dl               ; if character = 0 (end of string) -> exit
    jnz _putstr_loop

    mov sp, bp
    pop bp
    ret

; _getstr - Read string from keyboard (standard input) using DOS 3Fh
; Input:
;   [bp+4] = buffer address (near pointer)
;   [bp+6] = maximum string length in bytes (including terminating null)
; Output:
;   AX = number of bytes read (excluding terminating null)

_getstr:
    push bp
    mov bp, sp

    mov dx, [bp+4]            ; DX = buffer address
    mov cx, [bp+6]            ; CX = maximum length
    mov bx, 0                 ; BX = standard input handle (0)
    mov ah, 3Fh               ; DOS read from file/device function
    int 21h                   ; read string, AX = length

    mov sp, bp
    pop bp
    ret


; itoa_hex - Convert 16-bit signed integer to hexadecimal string
; Input:
;   [bp+4] = output buffer (near pointer)
;   [bp+6] = number to convert (16-bit signed)
; Output:
;   Buffer contains null-terminated hexadecimal string (uppercase letters)
;   AX = number of characters written (always 4 digits for positive, 5 with sign)

itoa_hex:
    push bp
    mov bp, sp
    
    mov di, [bp+4] ; buffer address
    mov bx, [bp+6] ; number

    test bx, bx
    jnz itoa_hex_not_zero
    ; zero case
    mov byte ptr [di], '0'
    inc di
    mov ax, 0       ; (original code, return value maybe not used)
    jmp itoa_hex_done
itoa_hex_not_zero:
    ; check sign
    test bx, bx
    jns itoa_hex_positive
    ; negative: output '-' and take absolute value
    mov byte ptr [di], '-'
    inc di
    neg bx          ; now bx contains absolute value
itoa_hex_positive:
    mov cx, 4       ; number of hexadecimal digits
itoa_hex_loop:
    rol bx, 4       ; rotate left by 4 bits: high nibble becomes low
    mov al, bl
    and al, 0Fh     ; extract low nibble
    cmp al, 10  
    jl digit    
    add al, 'A' - 10 ; 'A'..'F'
    jmp put_char
digit:
    add al, '0'      ; '0'..'9'
put_char:
    mov byte ptr [di], al
    inc di
    loop itoa_hex_loop

    mov byte ptr [di], 0
itoa_hex_done:
    mov ax, 8
    pop bp
    ret


; itoa_dec - Convert 16-bit signed integer to decimal string
; Input:
;   [bp+4] = output buffer (near pointer)
;   [bp+6] = number to convert (16-bit signed)
; Output:
;   AX = number of characters written (excluding terminating null)

itoa_dec:
    push bp
    mov  bp, sp

    mov  di, word ptr [bp+4]   ; output buffer pointer
    mov  ax, word ptr [bp+6]   ; number

    ; handle zero separately (without sign)
    test ax, ax
    jnz  itoa_not_zero

    mov  byte ptr [di], '0'    ; write '0'
    mov  ax, 1                 ; output size = 1
    jmp  itoa_done

itoa_not_zero:
    xor  bx, bx                ; BX = 0 (sign not set)
    cmp  ax, 0
    jge  itoa_positive
    mov  bx, 1                 ; BX = 1 (negative)
    neg  ax                    ; take absolute value

itoa_positive:
    xor  cx, cx                ; digit counter
    mov  si, 10                ; divisor

itoa_divide_loop:
    xor  dx, dx
    div  si                    ; ax = quotient, dx = remainder (digit)
    push dx                    ; save digit on stack
    inc  cx
    test ax, ax
    jnz  itoa_divide_loop

    mov  di, word ptr [bp+4]   ; pointer to start of buffer again
    test bx, bx
    jz   itoa_no_sign
    mov  byte ptr [di], '-'    ; write minus sign
    inc  di

itoa_no_sign:
    mov  bx, cx                ; save number of digits
    jcxz itoa_skip_write   

itoa_write_loop:
    pop  dx
    add  dl, '0'
    mov  byte ptr [di], dl
    inc  di
    loop itoa_write_loop

    mov byte ptr [di], 0
itoa_skip_write:

    mov  ax, bx                
    test bx, bx                
    jz   itoa_done_size
    inc  ax                    ; add minus sign if present

itoa_done_size:
itoa_done:
    mov  sp, bp
    pop  bp
    ret

; itoa_hex32 - Convert 32-bit signed integer to hexadecimal string
; Input:
;   [bp+4] = output buffer (near pointer)
;   [bp+6] = high word (DX)
;   [bp+8] = low word (AX)
; Output:
;   Buffer contains null-terminated hexadecimal string (uppercase letters)
;   AX = number of characters written (including sign)

itoa_hex32:
    push    bp
    mov     bp, sp
    push    si
    push    di
    push    bx

    ; Load arguments
    mov     di, [bp+4]          ; DI = output buffer
    mov     dx, [bp+6]          ; DX = high word
    mov     ax, [bp+8]          ; AX = low word

    ; Handle sign (similar to itoa_dec32)
    xor     bh, bh              ; BH = sign flag (0 = positive, 1 = negative)
    test    dx, dx
    jns     itoa_hex32_positive ; jump if high word non-negative

    ; Negative number: output '-' and take two's complement
    mov     bh, 1
    mov     byte ptr [di], '-'
    inc     di
    not     dx
    not     ax
    add     ax, 1
    adc     dx, 0

itoa_hex32_positive:
    xor     bl, bl              ; BL = digit counter
    mov     cx, 16              ; base 16

itoa_hex32_digit_loop:
    push    ax                  ; save low word
    mov     ax, dx              ; copy high word to AX
    xor     dx, dx              ; clear DX for division
    div     cx                  ; AX = high/16, DX = high%16
    mov     si, ax              ; SI = quotient of high word
    pop     ax                  ; restore low word
    div     cx                  ; DX:AX / 16 -> AX = low/16, DX = next digit
    push    dx                  ; save digit on stack
    inc     bl                  ; increment digit counter
    mov     dx, si              ; DX = quotient of high word
    mov     si, ax              ; SI = quotient of low word
    or      si, dx              ; check if number is finished (both quotients zero)
    jnz     itoa_hex32_digit_loop

    xor     ch, ch
    mov     cl, bl              ; CX = number of digits
itoa_hex32_write_loop:
    pop     dx                  ; DX = digit (0..15)
    add     dl, '0'             ; convert to ASCII digit
    cmp     dl, '9'
    jbe     itoa_hex32_store
    add     dl, 'A'-'0'-10      ; adjust for 'A'..'F'
itoa_hex32_store:
    mov     byte ptr [di], dl
    inc     di
    dec     cx
    jnz     itoa_hex32_write_loop

    ; Terminate string with null
    mov     byte ptr [di], 0

    ; Return total characters written (sign + digits)
    mov     al, bl              ; number of digits
    add     al, bh              ; add sign if present
    xor     ah, ah

    ; Restore registers and return
    pop     bx
    pop     di
    pop     si
    mov     sp, bp
    pop     bp
    ret

; itoa_dec32 - Convert 32-bit signed integer to decimal string
; Input:
;   [bp+4] = output buffer (near pointer)
;   [bp+6] = high word (DX)
;   [bp+8] = low word (AX)
; Output:
;   AX = number of characters written (including sign)

itoa_dec32:
    push    bp
    mov     bp, sp
    push    si
    push    di
    push    bx

    ; Load arguments
    mov     di, [bp+4]          ; DI = output buffer
    mov     dx, [bp+6]          ; DX = high word
    mov     ax, [bp+8]          ; AX = low word

    ; Handle sign
    xor     bh, bh              ; BH = 0 (positive)
    test    dx, dx
    jns     itoa_dec32_positive

    ; Negative number: output '-' and take two's complement
    mov     bh, 1               ; BH = 1 (negative)
    mov     byte ptr [di], '-'
    inc     di
    not     dx
    not     ax
    add     ax, 1
    adc     dx, 0

itoa_dec32_positive:
    ; Convert absolute value to digits
    xor     bx, bx              ; BX = digit counter (0..10)
    mov     cx, 10              ; divisor

itoa_dec32_digit_loop:
    push    ax                  ; save low word
    mov     ax, dx              ; high word to AX
    xor     dx, dx              ; clear DX for division
    div     cx                  ; AX = high/10, DX = high%10
    mov     si, ax              ; SI = quotient of high word
    pop     ax                  ; restore low word
    div     cx                  ; DX:AX / 10 -> AX = low/10, DX = digit
    push    dx                  ; save digit on stack
    inc     bl                  ; increment digit counter
    mov     dx, si              ; DX = quotient of high word
    mov     si, ax              ; SI = quotient of low word
    or      si, dx              ; check if number is finished (both quotients zero)
    jnz     itoa_dec32_digit_loop

    ; Write digits in reverse order
    mov     cx, bx              ; CX = number of digits
itoa_dec32_write_loop:
    pop     dx
    add     dl, '0'
    mov     [di], dl
    inc     di
    dec     cx
    jnz     itoa_dec32_write_loop

    ; Terminate string with null
    mov     byte ptr [di], 0

    ; Return total characters written (sign + digits)
    mov     al, bl              ; number of digits
    add     al, bh              ; add sign if present
    xor     ah, ah

    pop     bx
    pop     di
    pop     si
    mov     sp, bp
    pop     bp
    ret


; atoi_dec - Convert decimal string to signed 16-bit integer
; Input:
;   [bp+4] = pointer to string
;   [bp+6] = string length (in bytes)
; Output:
;   AX = converted number (on success)
;   CF = 0 on success, 1 on overflow
;   On overflow AX = ERROR_OVERFLOW

atoi_dec:
    push bp
    mov  bp, sp
    push si
    push di
    push bx
    push dx

    ; Load arguments
    mov  si, word ptr [bp+4]          ; SI = pointer to string
    mov  cx, word ptr [bp+6]          ; CX = length

    xor  ax, ax              ; result = 0
    xor  di, di              ; sign = 0 (positive)

    test cx, cx
    jz   atoi_dec_end_convert

    ; Check for '-' sign
    mov  bl, byte ptr [si]
    cmp  bl, '-'
    jne  atoi_dec_no_sign

    inc  di                  ; sign = negative
    inc  si
    dec  cx

    test cx, cx
    jz   atoi_dec_end_convert

atoi_dec_no_sign:

atoi_dec_convert_loop:
    mov  bl, byte ptr [si]

    ; Check if character is valid digit
    cmp  bl, 0dh
    jb   atoi_dec_end_convert
    cmp  bl, '0'
    jb   atoi_dec_invalid_number
    cmp  bl, '9'
    ja   atoi_dec_invalid_number


    sub  bl, '0'
    mov  bh, 0               ; BX = digit (0..9)

    ; ---- OVERFLOW CHECK BEFORE MULTIPLICATION BY 10 ----
    ; AX must be <= 3276 because 3276*10 = 32760, after adding digit <= 32767

    mov  dx, ax
    cmp  dx, 3276
    ja   atoi_dec_overflow

    jne  atoi_dec_safe_mul

    ; AX == 3276 → check allowed digit for limit
    cmp  di, 0
    jne  atoi_dec_neg_limit

    ; positive limit: digit must be ≤ 7
    cmp  bl, 7
    ja   atoi_dec_overflow
    jmp  atoi_dec_safe_mul

atoi_dec_neg_limit:
    ; negative limit: digit must be ≤ 8 (for -32768)
    cmp  bl, 8
    ja   atoi_dec_overflow

atoi_dec_safe_mul:
    ; AX = AX * 10
    mov  dx, 10
    mul  dx                  ; DX:AX = AX * 10

    test dx, dx
    jnz  atoi_dec_overflow

    ; AX += digit
    add  ax, bx
    jc   atoi_dec_overflow

    inc  si
    dec  cx
    jnz  atoi_dec_convert_loop

atoi_dec_end_convert:
    ; Apply sign with special case for -32768
    test di, di
    clc
    jz   atoi_dec_done

    cmp  ax, 32768           ; Check absolute value 32768
    clc
    jne  atoi_dec_neg_normal

    ; This is -32768, set result directly
    mov  ax, -32768
    clc
    jmp  atoi_dec_done

atoi_dec_neg_normal:
    neg  ax
    clc
    jo   atoi_dec_overflow   ; should not happen for valid values, but keep check

atoi_dec_done:
    pop  dx
    pop  bx
    pop  di
    pop  si
    mov  sp, bp
    pop  bp
    ret

atoi_dec_overflow:
    ; Return saturated value based on sign
    cmp  di, 0
    jne  atoi_dec_overflow_neg
    ; Positive overflow → return 32767
    mov  ax, ERROR_OVERFLOW
    stc
    jmp  atoi_dec_done

atoi_dec_overflow_neg:
    ; Negative overflow → return -32768
    ;mov  ax, -32768
    mov  ax, ERROR_OVERFLOW
    stc    
    
    jmp  atoi_dec_done

atoi_dec_invalid_number:
    mov  ax, ERROR_INVALID_NUMBER
    stc
    jmp  atoi_dec_done

; atoi_hex - Convert hexadecimal string to signed 16-bit integer
; Input:
;   [bp+4] = pointer to string
;   [bp+6] = string length (in bytes)
; Output:
;   AX = converted number (on success)
;   CF = 0 on success, 1 on overflow
;   On overflow AX = ERROR_OVERFLOW

atoi_hex:
    push bp
    mov  bp, sp
    push si
    push di
    push bx
    push dx

    mov  si, word ptr [bp+4]   ; pointer to string
    mov  cx, word ptr [bp+6]   ; string length

    xor  ax, ax                ; result = 0
    xor  di, di                ; sign = 0 (0 = positive, 1 = negative)

    ; Empty string is invalid
    test cx, cx
    jz   atoi_hex_invalid_number

    ; Optional leading '-'
    mov  bl, byte ptr [si]
    cmp  bl, '-'
    jne  atoi_hex_no_sign

    inc  di                    ; remember negative sign
    inc  si
    dec  cx

    test cx, cx                ; after sign must be at least one character
    jz   atoi_hex_invalid_number

atoi_hex_no_sign:

    ; Skip optional prefix '0x' or '0X'
    cmp  cx, 2
    jb   atoi_hex_no_prefix

    mov  bl, byte ptr [si]
    cmp  bl, '0'
    jne  atoi_hex_no_prefix

    mov  bl, byte ptr [si+1]
    cmp  bl, 'x'
    je   atoi_hex_prefix_skip
    cmp  bl, 'X'
    jne  atoi_hex_no_prefix

atoi_hex_prefix_skip:
    add  si, 2
    sub  cx, 2

    test cx, cx                ; after '0x' must be at least one hex digit
    jz   atoi_hex_invalid_number

atoi_hex_no_prefix:

atoi_hex_convert_loop:
    mov  bl, byte ptr [si]

    ; Check '0'..'9'
    cmp  bl, '0'
    jb   atoi_hex_invalid_number
    cmp  bl, '9'
    jbe  atoi_hex_digit_0_9

    ; Check 'A'..'F'
    cmp  bl, 'A'
    jb   atoi_hex_invalid_number
    cmp  bl, 'F'
    jbe  atoi_hex_digit_bA_F

    ; Check 'a'..'f'
    cmp  bl, 'a'
    jb   atoi_hex_invalid_number
    cmp  bl, 'f'
    jbe  atoi_hex_digit_a_f

    ; Any other character -> invalid
    jmp  atoi_hex_invalid_number

atoi_hex_digit_0_9:
    sub  bl, '0'
    jmp  atoi_hex_got_digit

atoi_hex_digit_bA_F:
    sub  bl, 'A'
    add  bl, 10
    jmp  atoi_hex_got_digit

atoi_hex_digit_a_f:
    sub  bl, 'a'
    add  bl, 10

atoi_hex_got_digit:
    ; Multiply current result by 16 (shift left by 4 bits)
    mov  dx, ax
    shl  dx, 4

    ; Check overflow before adding new digit
    cmp  di, 0
    je   atoi_hex_check_pos_mul

    ; Negative number: result must not exceed 8000h in absolute value
    cmp  dx, 8000h
    ja   atoi_hex_overflow
    jmp  atoi_hex_add_digit

atoi_hex_check_pos_mul:
    cmp  dx, 7FFFh
    ja   atoi_hex_overflow

atoi_hex_add_digit:
    xor  bh, bh
    add  dx, bx

    ; Check overflow after addition
    cmp  di, 0
    je   atoi_hex_check_pos_add

    cmp  dx, 8000h
    ja   atoi_hex_overflow

    ; Special case: -32768 is allowed only if it's the complete number
    cmp  dx, 8000h
    jne  atoi_hex_store_negative_result
    cmp  cx, 1
    jne  atoi_hex_overflow

atoi_hex_store_negative_result:
    mov  ax, dx
    jmp  atoi_hex_digit_done

atoi_hex_check_pos_add:
    cmp  dx, 7FFFh
    ja   atoi_hex_overflow
    mov  ax, dx

atoi_hex_digit_done:
    inc  si
    dec  cx
    jnz  atoi_hex_convert_loop

    ; Normal completion: all characters processed successfully
atoi_hex_end_convert:
    test di, di
    jz   atoi_hex_done

    ; Apply minus sign (except for -32768 case, which is already correct)
    cmp  ax, 8000h
    je   atoi_hex_done
    neg  ax

atoi_hex_done:
    pop  dx
    pop  bx
    pop  di
    pop  si
    mov  sp, bp
    pop  bp
    clc
    ret

; Return error: invalid hex character or no digits
atoi_hex_invalid_number:
    pop  dx
    pop  bx
    pop  di
    pop  si
    mov  sp, bp
    pop  bp
    mov  ax, ERROR_INVALID_NUMBER
    stc
    ret

; Return error: numeric overflow
atoi_hex_overflow:
    pop  dx
    pop  bx
    pop  di
    pop  si
    mov  sp, bp
    pop  bp
    mov  ax, ERROR_OVERFLOW
    stc
    ret


; error_handler - Output error message by error code
; Input:
;   [bp+4] = error code (one of ERROR_* constants)
; Output: none (program terminates with return code 0xFF)

error_handler:
    push bp
    mov  bp, sp

    push dx

    mov  ax, word ptr [bp+4]        ; AX = error code
    mov  bx, ax
    shl  bx, 1                      ; multiply by 2 (word size)
    mov  dx, word ptr [msg_vec + bx] ; message address

    push dx
    call _putstr                    ; output message
    add sp, 2

    ; Terminate program with error code 0xFF
    mov ax, 4cFFh
    int 21h

handler_end: 
    pop  dx
    mov  sp, bp
    pop  bp
    ret

; parse_expression - Parse string of form "a + b" into result_a, result_b, result_op
; Input:
;   [bp+4] = pointer to expression string
;   [bp+6] = string length (in bytes)
; Output:
;   CF = 0 on success, 1 on error (error code in AX)
;   On success, global variables result_a, result_b, result_op are set

parse_expression:
    push bp
    mov  bp, sp
    sub sp, 2+1+2+2 ; allocate space for local variables:
                     ; [bp-2] (2 bytes) - not used
                     ; [bp-3] (1 byte)  - not used
                     ; [bp-5] (2 bytes) - pointer to start of second operand
                     ; [bp-7] (2 bytes) - flag indicating operator found (0/1)

    mov di, [bp+4]    ; DI = pointer to string
    mov cx, [bp+6]    ; CX = string length

    mov ax, 0
    mov word ptr [bp-7], ax   ; reset operator flag

parse_expression_loop:
    inc di
    cmp byte ptr [di], ' '
    je parse_expression_loop_white_space
    cmp  byte ptr [di], 0Dh
    je parse_expression_loop_end
    loop parse_expression_loop

    parse_expression_loop_white_space:
        ; Found first non-space character – start of first number
        mov ax, word ptr [bp+4]
        mov si, di
        sub di, ax          ; calculate length of first number
        clc
        mov ax, di
        mov di, si

        push ax             ; length of first number
        push [bp+4]         ; pointer to string start (first number)
        call [atoi_ptr]     ; call atoi_dec or atoi_hex via pointer
        jc parse_number_failed
        add sp, 4
        clc

        mov word ptr [result_a], ax

        inc di
        mov al, byte ptr [di]   ; operation character
        
        ; Check operation validity
        cmp al, '+'
        je parse_expression_op_valid
        cmp al, '-'
        je parse_expression_op_valid
        cmp al, '*'
        je parse_expression_op_valid
        cmp al, '/'
        je parse_expression_op_valid
        cmp al, '%'
        je parse_expression_op_valid
        jmp parse_expression_invalid_op
        
    parse_expression_op_valid:
        mov byte ptr [result_op], al ; save operation

        inc di ; skip operation character
        inc di ; skip space after operation
        mov word ptr [bp-5], di      ; remember start of second operand
        dec di

        mov ax, word ptr [bp-7]
        cmp ax, 1
        je parse_expression_invalid_format ; operator already found? should not happen

        mov ax, 1
        mov word ptr [bp-7], ax      ; set operator found flag

    loop parse_expression_loop

    parse_expression_loop_end:
        mov ax, word ptr [bp-7]
        cmp ax, 1
        jne parse_expression_invalid_format ; if operator not found – error

        mov word ptr [bp-7], ax
        mov ax, 1

        mov ax, word ptr [bp-5]      ; start of second operand
        sub di, ax
        clc
        mov ax, word ptr [bp-5]      ; address of second operand start
        
        ; Check that second operand is not empty
        cmp di, 0
        je parse_expression_invalid_second_operand
        
        push di                      ; length of second operand
        push ax                      ; pointer to second operand
        call [atoi_ptr]              ; convert second operand
        jc parse_number_failed
        add sp, 4
        clc

        mov word ptr [result_b], ax
        dec di

    mov  sp, bp
    pop  bp
    xor ax, ax  ; Return 0 on success
    clc
    ret

parse_number_failed:
    add sp, 4
    stc
    mov  sp, bp
    pop  bp
    ret

parse_expression_failed:
    add sp, 4
    mov ax, ERROR_INVALID_EXPRESSION
    stc
    mov  sp, bp
    pop  bp
    ret

parse_expression_invalid_op:
    add sp, 4
    mov ax, ERROR_INVALID_EXPRESSION_OP
    stc
    mov sp, bp
    pop bp
    ret

parse_expression_invalid_second_operand:
    add sp, 4
    mov ax, ERROR_INVALID_EXPRESSION
    stc
    mov sp, bp
    pop bp
    ret

parse_expression_invalid_format:
    mov ax, ERROR_INVALID_EXPRESSION
    stc
    mov sp, bp
    pop bp
    ret


; calculate - Perform arithmetic operation on two 16-bit signed numbers
; Input:
;   [bp+4] = first number (WORD)
;   [bp+6] = second number (WORD)
;   [bp+8] = operation (BYTE: '+', '-', '*', '/', '%')
; Output:
;   For +, -, /, %: result in AX (16 bits), DX = 0
;   For *: result in DX:AX (32 bits)
;   On error: CF=1, AX = error code (ERROR_OVERFLOW or ERROR_DIVIDE_BY_ZERO)

calculate:
    push bp
    mov  bp, sp
    sub  sp, 2                ; reserve local variable (not used)

    mov  ax, word ptr [bp+4]           ; first operand
    mov  bx, word ptr [bp+6]           ; second operand
    mov  cl, byte ptr [bp+8]           ; operator

    cmp  cl, '+'
    je   op_add
    cmp  cl, '-'
    je   op_sub
    cmp  cl, '*'
    je   op_mul
    cmp  cl, '/'
    je   op_div
    cmp  cl, '%'
    je   op_mod
    jmp  invalid_op

op_add:
    add  ax, bx
    jo   overflow_err         ; signed overflow
    xor  dx, dx               ; for 16-bit result DX = 0
    clc
    jmp  done

op_sub:
    sub  ax, bx
    jo   overflow_err
    xor  dx, dx
    clc
    jmp  done

op_mul:
    imul bx                   ; DX:AX = AX * BX (signed 32-bit)
    clc
    jmp  done

op_div:
    test bx, bx
    jz   div_by_zero
    cmp  bx, -1               ; check overflow: dividing -32768 by -1
    jne  do_div
    cmp  ax, -32768
    je   overflow_err
do_div:
    cwd                       ; sign extend AX to DX:AX
    idiv bx                   ; AX = quotient, DX = remainder
    xor  dx, dx               ; for 16-bit result clear DX
    clc
    jmp  done

op_mod:
    test bx, bx
    jz   div_by_zero
    cmp  bx, -1
    jne  do_mod
    cmp  ax, -32768
    je   overflow_err
do_mod:
    cwd
    idiv bx
    mov  ax, dx               ; remainder -> AX
    xor  dx, dx
    clc
    jmp  done

overflow_err:
    mov  ax, ERROR_OVERFLOW
    stc
    jmp  done

div_by_zero:
    mov  ax, ERROR_DIVIDE_BY_ZERO
    stc
    jmp  done

invalid_op:
    mov  ax, ERROR_INVALID_EXPRESSION
    stc

done:
    mov  sp, bp
    pop  bp
    ret

; Program entry point

start:
    mov ax, data_seg
    mov ds, ax

    mov ax, stack_seg 
    mov ss, ax

    mov bp, sp
    sub sp, 4                 ; reserve space for local variables

    ; Query number system for input
    push offset msg_enter_numerical_system
    call _putstr
    add sp, 2

    mov ah, 01h
    int 21h                   ; read single character

    cmp al, 'h'
    je set_hex
    mov word ptr [atoi_ptr], offset atoi_dec   ; default decimal
    r_set_hex:

    mov dl, 0DH
    mov ah, 02h
    int 21h    
    mov dl, 0AH
    int 21h

    ; Query expression
    push offset msg_enter_expression
    call _putstr
    add sp, 2

    ; Read expression string using _getstr
    push 1024                 ; maximum length
    push offset prompt_string
    call _getstr
    add sp, 4                 ; AX = number of bytes read

    ; Parse expression
    push ax
    push offset [prompt_string]
    call parse_expression
    jc failed_parsing_expression
    add sp, 4

    ; Load operands and operation for calculation
    mov ax, word ptr [result_a]
    mov bx, word ptr [result_b]
    mov cl, byte ptr [result_op]
    xor ch, ch

    push cx
    push word ptr [result_b]
    push word ptr [result_a]
    call calculate
    jc failed_to_calculate
    add sp, 6

    mov cl, byte ptr [result_op]
    cmp cl, '*'
    je print_32
    jne print_16

print_32:
    ; Save 32-bit result for decimal and hexadecimal output
    mov word ptr [bp-2], dx
    mov word ptr [bp-4], ax
    push dx
    push ax

    ; Output of decimal representation
    push offset [output_dec_msg]
    call _putstr
    add sp, 2

    pop ax
    pop dx

    push dx
    push ax

    push ax
    push dx
    push offset [formated_string_buffer]
    call itoa_dec32
    add sp, 6

    push offset [formated_string_buffer]
    call _putstr
    add sp, 2

    mov dl, 0DH
    mov ah, 02h
    int 21h    
    mov dl, 0AH
    int 21h

    ; Output of the hexadecimal representation
    push offset [msg_hex]
    call _putstr
    add sp, 2

    pop dx
    pop ax

    push dx          ; the older word
    push ax          ; the younger word
    push offset [formated_string_buffer2]
    call itoa_hex32
    add sp, 6

    push offset [formated_string_buffer2]
    call _putstr
    add sp, 2

    mov dl, 0DH
    mov ah, 02h
    int 21h    
    mov dl, 0AH
    int 21h

    mov sp, bp
    ; program termination with return code 0
    mov ax, 4c00h
    int 21h

print_16:
    push ax

    ; Output of decimal representation
    push offset [output_dec_msg]
    call _putstr
    add sp, 2

    pop  ax
    push ax

    push ax
    push offset [formated_string_buffer]
    call itoa_dec
    add sp, 4

    push offset [formated_string_buffer]
    call _putstr
    add sp, 2

    mov dl, 0DH
    mov ah, 02h
    int 21h    
    mov dl, 0AH
    int 21h

    ;Output of the hexadecimal representation
    pop ax
    push ax
    push offset [formated_string_buffer2]
    call itoa_hex
    add sp, 4

    push offset [msg_hex]
    call _putstr
    add sp, 2

    push offset [formated_string_buffer2]
    call _putstr
    add sp, 2

    mov dl, 0DH
    mov ah, 02h
    int 21h    
    mov dl, 0AH
    int 21h

    mov sp, bp
    ; program termination with return code 0
    mov ax, 4c00h
    int 21h

failed_to_calculate:
    add sp, 4
failed_parsing_expression:
    add sp, 4
    push ax
    call error_handler
    add sp, 2

    mov sp, bp
    ; program termination with return code -1
    mov ax, 4cFFh           
    int 21h

set_hex:
    mov word ptr [atoi_ptr], offset atoi_hex
    jmp r_set_hex

code_seg ends

end start