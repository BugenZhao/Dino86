;
; Created by Bugen Zhao on 2020/4/1.
;

        cpu 8086
%ifdef BOOTSECTOR
        org 0x7c00
%else
        org 0x0100
%endif
        jmp init

TITLE:  db "Dino86 by Bugen"
DEAD:   db "GAME OVER"
height: db 20, 18, 17, 16, 15, 15, 14, 15, 15, 16, 17, 18, 20

VRAM:   equ 0xb800
cd:     equ 0x0fa2
score:  equ 0x0fa4
jstate: equ 0x0fa6

drawdino:                       ; Draw dino if ax=1, clear if ax=0
        push ax                 ; Save arg
        mov bx, height
        mov di, [jstate]
        mov al, [cs:bx+di]      ; Get height by jstate
        mov ah, 0
        mov bx, 0xa0
        mul bx
        add ax, 10
        mov di, ax              ; Get new dino pos
        pop ax                  ; Restore arg
        test ax, ax
        jz .clear
 .draw:
        mov ax, [di+0xa0]       ; What are under our dino's feet? Save it!
        mov word [di], 0x0fdb
        mov word [di-0x2], 0x0f00|'\'
        mov word [di-0xa0+2], 0x0f00|0xdc
        mov word [di+0xa0], 0x0f00|0xba
        ret
 .clear:
        mov ax, 0x0700|' '
        mov word [di], ax
        mov word [di-0x2], ax
        mov word [di-0xa0+2], ax
        mov word [di+0xa0], ax
        ret


dispscore:
        inc word [score]
        mov ax, [score]         ; Store score in ax
        mov di, 0xa0*2-4        ; Where to show: row 2, col -2
        std                     ; Set dflag
 .sloop:
        mov dx, 0
        mov cx, 10
        div cx                  ; q in ax, r in dx
        push ax                 ; Save quotient
        mov ax, dx
        add ax, 0x0700|'0'
        stosw                   ; Show and dec di by 2
        pop ax
        cmp ax, 0
        je .return
        jmp .sloop
 .return:
        cld                     ; Clear dflag
        ret


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
        dec word [cd]           ; CD--
        cmp ax, 0
        jge .scrret             ; CD >= 0 -> Cactus is too close!
        in al, 0x40
        and ax, 0x0007          ; Generate a random 'MODE' in [0,7]
        cmp al, 0x4
        jl .scrret              ; 0,1,2,3 -> Do not draw
        mov di, 0xa0*22-8
        cmp al, 0x6
        mov ax, 0x0200|0xdb     ; Cache block char
        jl .drawcactusB         ; 4,5 -> MODE B
                                ; 6,7 -> MODE A
 .drawcactusA:                  ; MODE A
        mov word [di], ax
        sub di, 0xa0
        mov word [di], ax
        mov word [di-0x2], 0x0200|0xd4
        mov word [di+0x2], 0x0200|0xbe
        sub di, 0xa0
        mov word [di], ax
        jmp .addcd
 .drawcactusB:                  ; MODE B
        mov word [di], ax
        mov word [di+0x2], ax
        mov word [di-0x2], 0x0200|0xc8
        sub di, 0xa0
        mov word [di], ax
        mov word [di+0x2], ax
        mov word [di+0x4], 0x0200|0xbc
        jmp .addcd
 .addcd:
        in al, 0x40
        and ax, 0x000f
        mov bx, [score]
        cmp bx, 1000
        jg .veryhard
        cmp bx, 500
        jg .hard
        add al, 0x8
 .hard:
        add al, 0x4
 .veryhard:
        add al, 0x4
        mov [cd], ax
 .scrret:
        ret


init:
        mov ax, 0x2             ; Set text mode and clear
        int 0x10
        mov ah, 0x1
        mov cx, 0x2607          ; Set invisible cursor
        int 0x10
        cld                     ; Clear dflag
        mov ax, VRAM
        mov ds, ax
        mov es, ax              ; Set ds,es to vram
        mov word [cd], 80
        mov word [score], 0
        mov word [jstate], 0

initscenery:
        mov cx, 80              ; Do not show cactus at the beginning
 .isloop:
        push cx
        call scroll             ; Show scenery
        pop cx
        loop .isloop
 .dino:
        mov ax, 1
        call drawdino           ; Draw dino

title:
        mov di, 0x00e2          ; Center of row 1
        mov si, TITLE
        mov cx, 15              ; Loop count = TITLE.len
        mov ah, 0x0f            ; Title color
 .tloop:
        mov al, byte [cs:si]    ; Get title char
        stosw                   ; Move ax to ds:si
        inc si
        call tick               ; Wait some ticks
        loop .tloop
        
ready:
        mov ah, 0x1             ; Check if key pressed
        int 0x16
        pushf
        xor ax, ax              ; Wait for a key
        int 0x16
        popf
        jnz ready               ; No key pressed -> not ready

game:
        mov ah, 0x1
        int 0x16
        jz .nokey               ; No key pressed
        xor ax, ax
        int 0x16
        cmp al, 0x1b            ; Escape?
        je quit                 ; Escape -> restart  
 .key:                          ; Some key pressed
        mov ax, [jstate]
        jmp .incjstate
 .nokey:                        ; No key pressed
        mov ax, [jstate]
        cmp ax, 0x0             ; Are we jumping?
        je .gaming              ; No, pass
 .incjstate:
        inc ax
        cmp ax, 13              ; Have we jumped down to ground?
        jl .gaming
 .ground:
        mov ax, 0x0             ; Restore jstate to zero
 
 .gaming:
        push ax                 ; Save current jstate
        call tick
        mov ax, 0
        call drawdino           ; Clear old dino
        call scroll
        pop ax                  ; Restore new jstate
        mov [jstate], ax
        mov ax, 1
        call drawdino           ; Draw new dino
        cmp al, ' '
        jne dead                ; OUCH! CACTUS!
        call dispscore          ; Display score
        jmp game

dead:
        mov di, 0xa0*12+0x00e8  ; Center of row 13
        mov si, DEAD
        mov cx, 9               ; Loop count = DEAD.len
        mov ah, 0x0c            ; DEAD color
 .tloop:
        mov al, byte [cs:si]    ; Get DEAD char
        stosw                   ; Move ax to ds:si
        inc si
        call tick               ; Wait some ticks
        loop .tloop
 .wait:
        mov cx, 128
 .wloop:
        call tick
        loop .wloop

quit:
%ifdef BOOTSECTOR
        mov ax, 0x3
        out 0x92, ax            ; Reboot
%else
        int 20h
%endif


bootable:
        times 510-($-$$) db  0
        dw 0xaa55
