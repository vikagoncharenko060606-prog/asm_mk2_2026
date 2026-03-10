.8086

stack_seg segment para stack 'stack'
    db 256 dup(?)
stack_seg ends

data_seg segment para 'data'
    msg db 'hello, world!', 0dh, 0ah, '$'
    index equ 7
data_seg ends

code_seg segment para 'code'
    assume cs:code_seg, ds:data_seg, ss:stack_seg

start:

    ; initialize ds to point to our data segment
    mov ax, data_seg
    mov ds, ax

    lea bx, [msg + index]
    mov byte ptr [bx], '*'
    mov dl, [bx+1]

    ; display the message using dos function 9
    mov dx, offset msg      
    mov ah, 9
    int 21h

    ; terminate program with return code 0
    mov ax, 4c00h           
    int 21h

code_seg ends

end start
