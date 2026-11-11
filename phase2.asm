
[org 0x0100]

jmp start

; ---------------- constants ----------------
ROAD_ROW      equ 16          ; dino stands on top of this row
DINO_COL      equ 9
DINO_START_Y  equ 12          ; top row of the 4-row dino
HIT_LEFT      equ 10          ; dino hit-box columns
HIT_RIGHT     equ 13
MAX_CACTI     equ 3
NUM_TYPES     equ 4
NUM_CLOUDS    equ 4
MIN_GAP       equ 40          ; columns between two cacti (min)
LEG_PERIOD    equ 6           ; frames per leg change
CLOUD_PERIOD  equ 18          ; frames per cloud step (slow)
START_PERIOD  equ 4           ; frames per world step (road+cacti)
MIN_PERIOD    equ 2           ; fastest world speed
RAMP_FRAMES   equ 420         ; frames before the game speeds up
CLOUD_WHITE   equ 0F020h      ; white cell
CLOUD_SHADE   equ 07020h      ; light-gray cell (cloud underside)

; ============================================================
;  LOW LEVEL DRAWING (everything draws into the back buffer)
; ============================================================

; PutCell(row, col, cell)   cell: AH = attribute, AL = character
; Clips anything outside the 80x25 screen (col may be negative).
PutCell:
        push bp
        mov bp, sp
        push ax
        push bx
        push di

        mov bx, [bp+6]
        cmp bx, 80
        jae .done               ; unsigned: also rejects negatives
        mov ax, [bp+8]
        cmp ax, 25
        jae .done
        mov di, ax
        shl ax, 6               ; row*64
        shl di, 4               ; row*16
        add di, ax              ; row*80
        add di, bx
        shl di, 1
        add di, backbuf
        mov ax, [bp+4]
        mov [di], ax
.done:
        pop di
        pop bx
        pop ax
        pop bp
        ret 6

; HLine(row, col, count, cell)  - horizontal run of one cell
HLine:
        push bp
        mov bp, sp
        push ax
        push bx
        push cx
        mov cx, [bp+6]
        cmp cx, 0
        jle .done
        mov bx, [bp+8]
.l:
        push word [bp+10]
        push bx
        push word [bp+4]
        call PutCell
        inc bx
        loop .l
.done:
        pop cx
        pop bx
        pop ax
        pop bp
        ret 8

; PrintText(row, col, ptr, attr)  - zero terminated string
PrintText:
        push bp
        mov bp, sp
        push ax
        push bx
        push si
        mov si, [bp+6]
        mov bx, [bp+8]
.l:
        mov al, [si]
        cmp al, 0
        je .done
        mov ah, [bp+4]
        push word [bp+10]
        push bx
        push ax
        call PutCell
        inc si
        inc bx
        jmp .l
.done:
        pop si
        pop bx
        pop ax
        pop bp
        ret 8

; DrawSprite(row, col, ptr)
; Sprite = db width, height, then height rows of width characters.
; Each character is a hex digit = background colour; ' ' = transparent.
DrawSprite:
        push bp
        mov bp, sp
        push ax
        push bx
        push cx
        push dx
        push si
        push di

        mov si, [bp+4]
        mov dl, [si]            ; width
        mov dh, [si+1]          ; height
        add si, 2
        mov bx, [bp+8]          ; current row
.rows:
        mov di, [bp+6]          ; current column
        mov cl, dl
.cols:
        mov al, [si]
        inc si
        cmp al, ' '
        je .next
        cmp al, '9'
        jbe .digit
        sub al, 'A'-10
        jmp .conv
.digit:
        sub al, '0'
.conv:
        shl al, 4
        mov ah, al
        mov al, 20h
        push bx
        push di
        push ax
        call PutCell
.next:
        inc di
        dec cl
        jnz .cols
        inc bx
        dec dh
        jnz .rows

        pop di
        pop si
        pop dx
        pop cx
        pop bx
        pop ax
        pop bp
        ret 6

; Random(max) -> AX in 0..max-1   (16-bit LCG, uses the high byte)
Random:
        push bp
        mov bp, sp
        push cx
        push dx
        mov ax, [seed]
        mov dx, 25173
        mul dx
        add ax, 13849
        mov [seed], ax
        mov al, ah
        xor ah, ah
        xor dx, dx
        mov cx, [bp+4]
        div cx
        mov ax, dx
        pop dx
        pop cx
        pop bp
        ret 2

; ============================================================
;  SCENE PRINTING
; ============================================================

; Sky, road edge line and dirt in the back buffer.
PrintBackground:
        push ax
        push cx
        push di
        push es
        push ds
        pop es
        mov di, backbuf
        cld
        mov ax, 0B020h          ; sky: light cyan
        mov cx, 16*80
        rep stosw
        mov ax, 060DFh          ; road edge: black upper half block
        mov cx, 80
        rep stosw
        mov ax, 06020h          ; dirt: brown
        mov cx, 8*80
        rep stosw
        pop es
        pop di
        pop cx
        pop ax
        ret

PrintSun:
        push word 2
        push word 6
        push word sunSprite
        call DrawSprite
        ret

; PrintCloud(row, col, width): three-row dome, white with a gray base
PrintCloud:
        push bp
        mov bp, sp
        push ax

        push word [bp+8]        ; top row
        mov ax, [bp+6]
        add ax, 2
        push ax
        mov ax, [bp+4]
        sub ax, 4
        push ax
        push word CLOUD_WHITE
        call HLine

        mov ax, [bp+8]          ; middle row
        inc ax
        push ax
        mov ax, [bp+6]
        inc ax
        push ax
        mov ax, [bp+4]
        sub ax, 2
        push ax
        push word CLOUD_WHITE
        call HLine

        mov ax, [bp+8]          ; base row (shaded)
        add ax, 2
        push ax
        push word [bp+6]
        push word [bp+4]
        push word CLOUD_SHADE
        call HLine

        pop ax
        pop bp
        ret 6

; Calls PrintCloud once per cloud (different size and position each).
PrintClouds:
        push ax
        push bx
        push si
        xor bx, bx
.l:
        mov si, bx
        shl si, 1
        xor ax, ax
        mov al, [cloudRow+bx]
        push ax
        push word [cloudCol+si]
        mov al, [cloudW+bx]
        push ax
        call PrintCloud
        inc bx
        cmp bx, NUM_CLOUDS
        jb .l
        pop si
        pop bx
        pop ax
        ret

; DrawGroundRow(row, pattern, offset) - 16-char scrolling pebble row
DrawGroundRow:
        push bp
        mov bp, sp
        push ax
        push bx
        push dx
        push si
        push di
        mov si, [bp+6]
        mov dx, [bp+4]
        xor bx, bx
.l:
        mov di, bx
        add di, dx
        and di, 15
        and di, 15
        add di, si              ; pattern base + index
        mov al, [di]
        cmp al, ' '
        je .n
        mov ah, 6Eh             ; yellow on brown
        push word [bp+8]
        push bx
        push ax
        call PutCell
.n:
        inc bx
        cmp bx, 80
        jb .l
        pop di
        pop si
        pop dx
        pop bx
        pop ax
        pop bp
        ret 6

; Ground texture; lower rows are "closer" so they scroll faster.
PrintRoad:
        push ax
        push word 17
        push word pat1
        push word [roadOff]
        call DrawGroundRow
        push word 19
        push word pat2
        push word [roadOff]
        call DrawGroundRow
        mov ax, [roadOff]
        shl ax, 1
        push word 21
        push word pat3
        push ax
        call DrawGroundRow
        mov ax, [roadOff]
        shl ax, 2
        push word 23
        push word pat1
        push ax
        call DrawGroundRow
        pop ax
        ret

PrintCacti:
        push ax
        push bx
        push si
        push di
        xor bx, bx
.l:
        cmp byte [cactOn+bx], 0
        je .n
        mov al, [cactType+bx]
        xor ah, ah
        mov di, ax
        shl di, 1
        mov di, [cactTable+di]  ; sprite pointer
        mov al, [di+1]          ; height
        xor ah, ah
        mov si, ROAD_ROW
        sub si, ax              ; top row = road - height
        push si
        mov si, bx
        shl si, 1
        push word [cactX+si]
        push di
        call DrawSprite
.n:
        inc bx
        cmp bx, MAX_CACTI
        jb .l
        pop di
        pop si
        pop bx
        pop ax
        ret

PrintDino:
        push ax
        mov ax, dinoA
        cmp byte [dead], 0
        jne .dead
        cmp byte [legFrame], 0
        je .draw
        mov ax, dinoB
        jmp .draw
.dead:
        mov ax, dinoDead
.draw:
        push word [dinoY]
        push word DINO_COL
        push ax
        call DrawSprite
        pop ax
        ret

; Static score panel, top right (value does not move in Phase II).
PrintScore:
        push bx
        xor bx, bx
.panel:
        push bx
        push word 68
        push word 9
        push word 0F020h
        call HLine
        inc bx
        cmp bx, 4
        jb .panel
        push word 1
        push word 70
        push word scorelabel
        push word 0F8h
        call PrintText
        push word 2
        push word 70
        push word scorevalue
        push word 0F0h
        call PrintText
        pop bx
        ret

DrawFrame:
        call PrintBackground
        call PrintSun
        call PrintClouds
        call PrintRoad
        call PrintCacti
        call PrintDino
        call PrintScore
        ret

; ============================================================
;  GAME LOGIC
; ============================================================

; Moves clouds left; a cloud that leaves re-enters on the right
; with a new random height.
MoveClouds:
        push ax
        push bx
        push si
        xor bx, bx
.l:
        mov si, bx
        shl si, 1
        dec word [cloudCol+si]
        xor ax, ax
        mov al, [cloudW+bx]
        add ax, [cloudCol+si]
        cmp ax, 0
        jg .n
        push word 20
        call Random
        add ax, 80
        mov [cloudCol+si], ax
        push word 7
        call Random
        add ax, 2
        mov [cloudRow+bx], al
.n:
        inc bx
        cmp bx, NUM_CLOUDS
        jb .l
        pop si
        pop bx
        pop ax
        ret

ScrollRoad:
        inc word [roadOff]
        ret

MoveCacti:
        push ax
        push bx
        push si
        push di
        xor bx, bx
.l:
        cmp byte [cactOn+bx], 0
        je .n
        mov si, bx
        shl si, 1
        dec word [cactX+si]
        mov al, [cactType+bx]
        xor ah, ah
        mov di, ax
        shl di, 1
        mov di, [cactTable+di]
        mov al, [di]            ; width
        xor ah, ah
        add ax, [cactX+si]
        cmp ax, 0
        jg .n
        mov byte [cactOn+bx], 0 ; fully off the left edge
.n:
        inc bx
        cmp bx, MAX_CACTI
        jb .l
        pop di
        pop si
        pop bx
        pop ax
        ret

; Counts the gap down; when it hits zero a random cactus enters
; at the right edge and a new random gap is chosen.
SpawnCactus:
        push ax
        push bx
        push si
        dec word [spawnGap]
        jnz .done
        xor bx, bx
.find:
        cmp byte [cactOn+bx], 0
        je .found
        inc bx
        cmp bx, MAX_CACTI
        jb .find
        mov word [spawnGap], 5  ; no free slot, retry shortly
        jmp .done
.found:
        mov byte [cactOn+bx], 1
        mov si, bx
        shl si, 1
        mov word [cactX+si], 80
        push word NUM_TYPES
        call Random
        mov [cactType+bx], al
        push word 40
        call Random
        add ax, MIN_GAP
        mov [spawnGap], ax
.done:
        pop si
        pop bx
        pop ax
        ret

; Returns AX = 1 if the dino touches any cactus, else 0.
CheckCollision:
        push bx
        push cx
        push dx
        push si
        push di
        xor bx, bx
.l:
        cmp byte [cactOn+bx], 0
        je .n
        mov si, bx
        shl si, 1
        mov dx, [cactX+si]
        cmp dx, HIT_RIGHT
        jg .n                   ; cactus still to the right of dino
        mov al, [cactType+bx]
        xor ah, ah
        mov di, ax
        shl di, 1
        mov di, [cactTable+di]
        mov al, [di]            ; width
        xor ah, ah
        add ax, dx
        cmp ax, HIT_LEFT+1
        jl .n                   ; cactus already behind dino
        mov al, [di+1]          ; height
        xor ah, ah
        mov cx, ROAD_ROW
        sub cx, ax              ; cactus top row
        mov ax, [dinoY]
        add ax, 3               ; dino feet row
        cmp ax, cx
        jl .n                   ; dino is above the cactus
        mov ax, 1
        jmp .out
.n:
        inc bx
        cmp bx, MAX_CACTI
        jb .l
        xor ax, ax
.out:
        pop di
        pop si
        pop dx
        pop cx
        pop bx
        ret

; One game step: every animation has its own frame period.
UpdateGame:
        push ax
        inc byte [legCnt]
        cmp byte [legCnt], LEG_PERIOD
        jb .noleg
        mov byte [legCnt], 0
        xor byte [legFrame], 1  ; dino runs
.noleg:
        inc byte [cloudCnt]
        cmp byte [cloudCnt], CLOUD_PERIOD
        jb .nocloud
        mov byte [cloudCnt], 0
        call MoveClouds
.nocloud:
        inc byte [worldCnt]
        mov al, [worldCnt]
        cmp al, [worldPeriod]
        jb .noworld
        mov byte [worldCnt], 0
        call ScrollRoad
        call MoveCacti
        call SpawnCactus
.noworld:
        inc word [rampCnt]
        cmp word [rampCnt], RAMP_FRAMES
        jb .done
        mov word [rampCnt], 0
        cmp byte [worldPeriod], MIN_PERIOD
        jbe .done
        dec byte [worldPeriod]  ; game gets faster
.done:
        pop ax
        ret

; ============================================================
;  SCREEN / SYSTEM
; ============================================================

; Wait for the start of the next vertical retrace.
WaitVSync:
        push ax
        push dx
        mov dx, 3DAh
.w1:
        in al, dx
        test al, 8
        jnz .w1
.w2:
        in al, dx
        test al, 8
        jz .w2
        pop dx
        pop ax
        ret

; Copy the finished frame to video memory.
Present:
        push ax
        push cx
        push si
        push di
        push es
        mov ax, 0B800h
        mov es, ax
        xor di, di
        mov si, backbuf
        mov cx, 2000
        cld
        rep movsw
        pop es
        pop di
        pop si
        pop cx
        pop ax
        ret

InitVideo:
        mov ax, 0003h           ; 80x25 text, clear screen
        int 10h
        mov ax, 1003h           ; blink off -> 16 background colours
        mov bl, 0
        int 10h
        mov ah, 1               ; hide cursor
        mov cx, 2000h
        int 10h
        ret

InitGame:
        xor ah, ah              ; BIOS tick count seeds the random numbers
        int 1Ah
        mov [seed], dx
        ret

RunGame:
.loop:
        call UpdateGame
        call CheckCollision
        cmp ax, 1
        je .over
        call DrawFrame
        call WaitVSync
        call Present
        jmp .loop
.over:
        ret

; Show the crashed dino for about a second and a half.
ShowCrash:
        push cx
        mov byte [dead], 1
        call DrawFrame
        call WaitVSync
        call Present
        mov cx, 100
.wait:
        call WaitVSync
        loop .wait
        pop cx
        ret

ExitGame:
        mov ax, 1003h           ; blink back on
        mov bl, 1
        int 10h
        mov ax, 0003h           ; clean text screen
        int 10h
        mov ax, 4C00h
        int 21h

; ============================================================
;  DATA
; ============================================================
seed        dw 0
legFrame    db 0
legCnt      db 0
cloudCnt    db 0
worldCnt    db 0
worldPeriod db START_PERIOD
rampCnt     dw 0
roadOff     dw 0
spawnGap    dw 25
dead        db 0
dinoY       dw DINO_START_Y

cactX       times MAX_CACTI dw 0
cactType    times MAX_CACTI db 0
cactOn      times MAX_CACTI db 0

cloudRow    db 4, 7, 3, 9
cloudCol    dw 15, 43, 64, 75
cloudW      db 8, 9, 7, 6

scorelabel  db 'SCORE', 0
scorevalue  db '00000', 0

; 16-character ground patterns
pat1        db '.     ,     -   '
pat2        db '  -   .   ,     '
pat3        db '   .  ,    -  . '

cactTable   dw cact0, cact1, cact2, cact3

; sprites: hex digit = background colour (0 black, 2 green, 4 red,
; E yellow, F white), space = transparent
dinoA       db 6, 4
            db '   0F0'
            db '0  000'
            db '00000 '
            db ' 0    '
dinoB       db 6, 4
            db '   0F0'
            db '0  000'
            db '00000 '
            db '   0  '
dinoDead    db 6, 4
            db '   040'
            db '0  000'
            db '00000 '
            db ' 0 0  '

sunSprite   db 5, 3
            db ' EEE '
            db 'EEEEE'
            db ' EEE '

cact0       db 3, 3
            db ' 2 '
            db '222'
            db ' 2 '
cact1       db 5, 4
            db '  2  '
            db '2 2 2'
            db '22222'
            db '  2  '
cact2       db 7, 3
            db ' 2   2 '
            db '222 222'
            db ' 2   2 '
cact3       db 5, 5
            db '  2  '
            db '2 2 2'
            db '2 2 2'
            db '22222'
            db '  2  '

; ============================================================
;  MAIN - just a sequence of calls
; ============================================================
start:
        call InitVideo
        call InitGame
        call RunGame
        call ShowCrash
        call ExitGame

section .bss
backbuf     resb 4000