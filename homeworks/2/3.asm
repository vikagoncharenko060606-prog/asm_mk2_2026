.8086

stack_seg segment para stack 'stack'
    db 256 dup(?)
stack_seg ends

data_seg segment para 'data?'
    string_buffer       db 241                  ; len
                        db 0                    ; input len
                        db 241 dup(?)           ; input buffer
data_seg ends

code_seg segment para 'code'
    assume cs:code_seg, ds:data_seg, ss:stack_seg



start proc

    ; initialize ds to point to our data segment
    mov ax, data_seg
    mov ds, ax

    mov dx, offset string_buffer
    mov ah, 0ah ; buffer input
    int 21h

    mov dl, 0dh   ; carriage return
    mov ah, 02h
    int 21h
    mov dl, 0ah   ; new line
    int 21h

    mov bl, string_buffer+1 ; bx = { bh = ?, bl = size }  
    mov bh, 0                 ; bx = { bh = 0000, bl = size }
    lea si, string_buffer+2 
    add si, bx
    mov byte ptr [si], '$'

    mov dx, offset [string_buffer+2]
    mov ah, 09h
    int 21h

    mov dl, 0dh
    mov ah, 02h
    int 21h
    mov dl, 0ah
    int 21h

    ; terminate program with return code 0
    mov ax, 4c00h           
    int 21h

start endp

code_seg ends

end start
