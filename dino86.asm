        cpu 8086
        org 0x7c00
        jmp init

VRAM:   equ 0xb800
cd:     equ 0x0fa2

tick:
        push ax
        push bx
        push cx
        push dx
        mov ah, 0x0             ; Read clock tick into dx:bx
        int 0x1a
.again:
        push dx                 ; Save dx
        mov ah, 0x0             ; Read again
        int 0x1a
        pop bx
        cmp bx, dx              ; Changed?
        je .again               ; Nope, tick again
        pop dx
        pop cx
        pop bx
        pop ax
        ret


scroll:
        mov di, 0xa0*2          ; Row 3, col 1
        mov si, 0xa0*2+2        ; Row 3, col 2
 .scrrow:
        mov cx, 79
        repz movsw              ; Loop: mov words from ds:si to es:di
        cmp di, 0xa0*22
        mov ax, 0x0f00|' '      ; Prepare to clear col 80
        jl .fillblank
 .fillblock:
        mov ax, 0x0700|0xdb     ; Prepare to fill a block
 .fillblank:   
        stosw                   ; Fill blank or block, add di by 2
        add si, 0x2             
        cmp si, 0xa0*25+2       ; All 25 rows scrolled?
        jnz .scrrow
 .testcactus:
        mov ax, [cd]
        dec ax
        mov [cd], ax            ; CD--
        cmp ax, 0
        jge .scrret             ; CD >= 0 -> Cactus is too close!
        in al, 0x40
        and ax, 0x0007          ; Generate a random 'MODE' in [0,7]
        cmp al, 0x4
        jl .scrret              ; 0,1,2,3 -> Do not draw
        mov di, 0xa0*22-8
        cmp al, 0x6
        jl .drawcactusB         ; 4,5 -> MODE B
                                ; 6,7 -> MODE A
 .drawcactusA:                  ; MODE A
        mov word [di], 0x0200|0xdb
        sub di, 0xa0
        mov word [di], 0x0200|0xdb
        mov word [di-0x2], 0x0200|0xd4
        mov word [di+0x2], 0x0200|0xbe
        sub di, 0xa0
        mov word [di], 0x0200|0xdb
        jmp .addcd
 .drawcactusB:                  ; MODE B
        mov word [di], 0x0200|0xdb
        mov word [di+0x2], 0x0200|0xdb
        mov word [di-0x2], 0x0200|0xc8
        sub di, 0xa0
        mov word [di], 0x0200|0xdb
        mov word [di+0x2], 0x0200|0xdb
        mov word [di+0x4], 0x0200|0xbe
        jmp .addcd
 .addcd:
        in al, 0x40
        and ax, 0x000f
        or ax, 0x10             ; Generate a random cd in [16,32)
        mov [cd], ax
 .scrret:
        ret


init:
        mov ax, 0x2             ; Set text mode
        int 0x10
        mov ah, 0x1
        mov cx, 0x2607          ; Set invisible cursor
        int 0x10
        cld                     ; Clear dflag
        mov ax, VRAM
        mov ds, ax
        mov es, ax              ; Set ds,es to vram
        mov word [cd], 80

initscenery:
        mov cx, 80
 .isloop:
        push cx
        call scroll
        pop cx
        loop .isloop

title:
        mov di, 0x00e2          ; Center of row 1
        mov si, TITLE
        mov cx, 16              ; Loop count = TITLE.len
        mov ah, 0x0f            ; Title color
 .tloop:
        mov al, byte [cs:si]    ; Get title char
        stosw                   ; Move ax to ds:si
        inc si
        call tick
        call tick
        call tick
        loop .tloop
        
s:
        call tick
        call scroll
        jmp s

spin:
        hlt
        jmp spin



TITLE:  db "Dino 86 by Bugen"

bootable:
        times 510-($-$$) db  0
        dw 0xaa55
