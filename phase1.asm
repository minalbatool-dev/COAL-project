[org 0x0100]

jmp start

; Print a character at row/column.
; Parameters: [bp+8] = row, [bp+6] = column, [bp+4] = character
printchar:
        push bp
        mov bp, sp
        push ax
        push dx
        push di
        push es

        mov ax, 0xb800
        mov es, ax
        mov ax, 80
        mul word [bp+8]
        add ax, [bp+6]
        shl ax, 1
        mov di, ax
        mov al, [bp+4]
        mov ah, 70h             ; black character on light-gray background
        mov [es:di], ax

        pop es
        pop di
        pop dx
        pop ax
        pop bp
        ret 6

; Clear the 80x25 text screen to light gray.
clrscr:
        push ax
        push cx
        push di
        push es
        mov ax, 0xb800
        mov es, ax
        xor di, di
        mov ax, 7020h            ; light-gray background, blank character
        mov cx, 2000
        cld
        rep stosw
        pop es
        pop di
        pop cx
        pop ax
        ret

; Print road and small ground marks.
PrintRoad:
        push bx
        push cx
        mov bx, 5
        mov cx, 70
.road:
        push word 16
        push bx
        push word '-'
        call printchar
        inc bx
        loop .road

        mov bx, 7
        mov cx, 14
.marks:
        push word 17
        push bx
        push word '.'
        call printchar
        add bx, 5
        loop .marks
        pop cx
        pop bx
        ret

; Cloud shape: dots above a curved, underlined base.
; Parameters: [bp+8] = row, [bp+6] = column, [bp+4] = width
PrintCloud:
        push bp
        mov bp, sp
        push ax
        push bx
        push cx

        mov ax, [bp+8]
        mov bx, [bp+6]
        inc bx
        mov cx, [bp+4]
        sub cx, 2
.top:
        push ax
        push bx
        push word '.'
        call printchar
        inc bx
        loop .top

        mov ax, [bp+8]
        inc ax
        mov bx, [bp+6]
        push ax
        push bx
        push word '('
        call printchar

        inc bx
        mov cx, [bp+4]
        sub cx, 2
.middle:
        push ax
        push bx
        push word '_'
        call printchar
        inc bx
        loop .middle

        mov ax, [bp+8]
        inc ax
        mov bx, [bp+6]
        add bx, [bp+4]
        dec bx
        push ax
        push bx
        push word ')'
        call printchar

        pop cx
        pop bx
        pop ax
        pop bp
        ret 6

; Clouds keep the same shape and sit at different heights.
PrintClouds:
        push word 4
        push word 15
        push word 8
        call PrintCloud

        push word 7
        push word 43
        push word 9
        call PrintCloud

        push word 4
        push word 64
        push word 7
        call PrintCloud
        ret

; Fill one text-cell square with a black background.
; Parameters: [bp+6] = row, [bp+4] = column
; The cell contains a space; no block glyph or sprite is used.
PrintSquare:
        push bp
        mov bp, sp
        push ax
        push di
        push es

        mov ax, 0xb800
        mov es, ax
        mov ax, 80
        mul word [bp+6]
        add ax, [bp+4]
        shl ax, 1
        mov di, ax
        mov ax, 0720h            ; blank cell with black background
        mov [es:di], ax

        pop es
        pop di
        pop ax
        pop bp
        ret 4

; Build a compact dino from filled text cells; feet are on row 15,
; directly above the road on row 16.
PrintDino:
        ; Head
        push word 13
        push word 9
        call PrintSquare

        ; Body
        push word 14
        push word 9
        call PrintSquare
        push word 14
        push word 10
        call PrintSquare

        ; Feet
        push word 15
        push word 9
        call PrintSquare
        push word 15
        push word 11
        call PrintSquare

        ; Eye and snout
        push word 13
        push word 10
        push word 'o'
        call printchar
        push word 13
        push word 11
        push word '>'
        call printchar
        ret

; Print SCORE and the initial five-digit score.
PrintScore:
        push ax
        push bx
        push cx
        push si

        mov si, scorelabel
        mov bx, 68
        mov cx, 5
.label:
        push word 7
        push bx
        xor ax, ax
        mov al, [si]
        push ax
        call printchar
        inc si
        inc bx
        loop .label

        mov si, scorevalue
        mov bx, 68
        mov cx, 5
.digit:
        push word 8
        push bx
        xor ax, ax
        mov al, [si]
        push ax
        call printchar
        inc si
        inc bx
        loop .digit

        pop si
        pop cx
        pop bx
        pop ax
        ret

scorelabel db 'SCORE'
scorevalue db '00000'

start:
        call clrscr
        call PrintClouds
        call PrintRoad
        call PrintDino
        call PrintScore
        mov ax, 0x4c00
        int 0x21