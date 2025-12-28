section .data
align 16
;;constants
player_sprite_size equ 128
half_player_sprite_size equ player_sprite_size/2
sprite_columns equ 9
dead_sprite_columns equ 6
pos_top equ half_player_sprite_size-10
pos_bottom equ win_h-half_player_sprite_size-100
pos_left equ half_player_sprite_size+20
pos_right equ win_w-half_player_sprite_size-50
anim_fps equ 60/10
dead_anim_fps equ 60/5

;; global variables
is_dead db 0
life dq 100
max_life dq 100
mana        dq 100        ; 当前法力
max_mana    dq 100        ; 最大法力
mana_timer  db 0          ; 用于每秒恢复

posx dq 0
posy dq 0
move_speed dq 0
state db 0
weapon_cooldown db 0
hurt_cooldown db 20
hurt_timer db 0

anim_counter db 0
timer db 0
weapon_timer db 0

player_texture dq 0
dead_texture dq 0

;; text data
img_path db "assets/player/walk.png", 0
dead_img db "assets/player/hurt.png", 0

debugmsg db "DEBUG: %d", 10, 0
iimsg db "##########", 10, 0

section .text
    global init_player
    global player_step 
    global show_player

    global get_player_pos
    global set_player_pos
    global get_player_life
    global set_player_life
    global hurt_player
    global get_player_max_life
    global set_player_max_life

    extern load_texture
    extern draw_sprite_anim
    extern input_poll
    extern gen_bullet
    extern bullet_step 
    extern show_bullet
    extern set_bullet
    extern ui_get_state
    extern ui_set_state
    extern printf

    extern renptr
    extern win_h
    extern win_w
    extern key_state
    extern mouse_x
    extern mouse_y
    extern is_esc


; 键状态 bitmask
%define KEY_W 1
%define KEY_S 2
%define KEY_A 4
%define KEY_D 8
%define KEY_ENTER 16


init_player:
    sub rsp, 8
    ;load texture 
    mov rdi, [renptr]
    mov rsi, img_path
    call load_texture
    mov [player_texture], rax

    mov rdi, [renptr]
    mov rsi, dead_img
    call load_texture
    mov [dead_texture], rax

    ;;init value
    mov qword [posx], 500
    mov qword [posy], 350
    mov rax, [max_life]
    mov qword [life], rax
    mov rax, [max_mana]
    mov [mana], rax
    mov byte [mana_timer], 0
    mov byte [state], 2
    mov byte [anim_counter], 0
    mov byte [timer], 0
    mov qword [move_speed], 5
    mov byte [weapon_cooldown], 10
    mov byte [hurt_timer], 0
    mov byte [is_dead], 0
    add rsp, 8
    ret

show_player:
    sub rsp, 24                     ; 保持 call 前 rsp % 16 == 8
    mov rdi, [renptr]
    mov rsi, [player_texture]
    mov rdx, [posx]
    sub rdx, half_player_sprite_size       
    mov rcx, [posy]
    sub rcx, half_player_sprite_size
    mov r8d, player_sprite_size
    mov r9d, player_sprite_size
    movzx rax, byte [state]         ; 零扩展字节到 64 位
    mov r10, sprite_columns
    imul rax, r10
    movzx r10, byte [anim_counter]
    add rax, r10
    mov [rsp+0], rax                ; frame_index
    mov qword [rsp+8], sprite_columns  ; columns (64-bit!)
    
    mov al, byte [is_dead]
    cmp al, 0
    jz .alive
    mov rsi, [dead_texture]
    movzx r10, byte [anim_counter]
    mov [rsp+0], r10
    mov qword [rsp+8], dead_sprite_columns  ; columns (64-bit!)
    .alive:
    call draw_sprite_anim
    add rsp, 24
    ret

player_step:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov al, [state]; old state
    mov [rsp+12], al

    movzx eax, byte [is_esc]
    test eax, eax
    jz .noesc
    jmp .exit

.noesc:
    movzx eax, byte [is_dead]
    cmp eax, 0
    jz .alive
    jmp .show_dead_anim
.alive
    ; ---------- mana regen ----------
    inc byte [mana_timer]
    cmp byte [mana_timer], 60
    jl .no_mana_regen
    mov byte [mana_timer], 0

    mov rax, [mana]
    add rax, 10
    cmp rax, [max_mana]
    jle .mana_ok
    mov rax, [max_mana]
.mana_ok:
    mov [mana], rax
.no_mana_regen:
    ;update pos
    mov ecx, [key_state]          ; keys bitmask
    ; W：向上
    test ecx, KEY_W
    jz .no_w
    mov rax, [posy]          ; y
    sub rax, [move_speed]
    cmp rax, pos_top
    jl .no_w
    mov [posy] , rax
    mov byte [state], 0
.no_w:
    ; S：向下
    test ecx, KEY_S
    jz .no_s
    mov rax, [posy] 
    add rax, [move_speed]
    cmp rax, pos_bottom
    jg .no_s
    mov [posy] , rax
    mov byte [state], 2
.no_s:
    ; A：向左
    test ecx, KEY_A
    jz .no_a
    mov rax, [posx]           ; x
    sub rax, [move_speed]
    cmp rax, pos_left
    jl .no_a
    mov [posx] , rax
    mov byte [state], 1
.no_a:
    ; D：向右
    test ecx, KEY_D
    jz .no_d
    mov rax, [posx] 
    add rax, [move_speed]
    cmp rax, pos_right
    jg .no_d
    mov [posx] , rax
    mov byte [state], 3
.no_d:
    mov al, [rsp+12]
    cmp al, [state]
    je .no_change_state
    mov byte [anim_counter], 0
.no_change_state:
    or ecx, ecx
    jz .idle_anim
    cmp byte [timer], anim_fps
    jl .no_update_anim
    mov byte [timer], 0
    add byte [anim_counter], 1
    cmp byte [anim_counter], sprite_columns
    jl .no_update_anim
    mov byte [anim_counter], 0
    .no_update_anim:
    add byte [timer], 1
    jmp .check_mouse

.idle_anim:
    mov byte [anim_counter], 0
    mov byte [timer], 1

.check_mouse:
    mov ecx, [mouse_x]
    cmp ecx, -1
    je .check_hurt

    ; ---------- mana check ----------
    mov rax, [mana]
    cmp rax, 10
    jl .check_hurt        ; 法力不足，不射击

    sub rax, 10
    mov [mana], rax

    mov rdi, 4
    mov rsi, 10
    call set_bullet
    mov rdi, [posx]
    mov rsi, [posy]
    movzx cx, byte [state]
    call gen_bullet

.check_hurt:
    movzx eax, byte [hurt_timer]
    cmp eax, 0
    je .l1
    dec byte [hurt_timer]
.l1:
    cmp eax, 0
    je .draw_player
    test eax, 1
    jz .done ;闪烁

.draw_player:
    call show_player
    jmp .done

.show_dead_anim:
    cmp byte [timer], dead_anim_fps
    jl .addl1
    mov byte [timer], 0
    add byte [anim_counter], 1
    cmp byte [anim_counter], dead_sprite_columns
    jl .addl1
    jmp .player_dead
    .addl1:
    add byte [timer], 1
    call show_player

.done:
    xor rax, rax
    add rsp, 32
    pop rbp
    ret

.exit:
    call ui_get_state
    cmp eax, 0
    je .c0
    cmp eax, 1
    je .cc
    cmp eax, 2
    jge .ce
    .c0:
    mov rdi, 1
    call ui_set_state
    jmp .ce
    .cc:
    mov rdi, 0
    call ui_set_state
    .ce:
    xor rax, rax
    add rsp, 32
    pop rbp
    ret

.player_dead:
    mov rdi, 3
    call ui_set_state
    xor rax, rax
    add rsp, 32
    pop rbp
    ret


;rdi rsi 
get_player_pos:
    mov rax, [posx]
    mov [rdi], rax
    mov rax, [posy]
    mov [rsi], rax
    xor rax, rax
    ret

global get_player_mana
global get_player_max_mana
global set_player_max_mana

get_player_mana:
    mov rax, [mana]
    ret

get_player_max_mana:
    mov rax, [max_mana]
    ret

set_player_max_mana:
    mov [max_mana], rdi
    ret

; rdi = x, rsi = y
; void set_player_pos(int64 x, int64 y)
set_player_pos:
    movzx eax, byte [hurt_timer]
    test eax, eax
    jnz .done

    ; ---------- clamp X (rdi) ----------
    cmp rdi, pos_left
    jge .x_ok_low
    mov rdi, pos_left
.x_ok_low:
    cmp rdi, pos_right
    jle .x_ok_high
    mov rdi, pos_right
.x_ok_high:

    ; ---------- clamp Y (rsi) ----------
    cmp rsi, pos_top
    jge .y_ok_low
    mov rsi, pos_top
.y_ok_low:
    cmp rsi, pos_bottom
    jle .y_ok_high
    mov rsi, pos_bottom
.y_ok_high:

    mov [posx], rdi
    mov [posy], rsi

.done:
    ret


; uint8 get_player_life()
; return: al/rax = life (zero-extended)
get_player_life:
    mov rax, [life]
    ret

get_player_max_life:
    mov rax, [max_life]
    ret

set_player_max_life:
    mov [max_life], rdi
    ret

; rdi = new life 
; void set_player_life(uint64 life)
set_player_life:
    mov [life], rdi
    ret

; void hurt(rdi = damage)
hurt_player:
    movzx eax, byte [hurt_timer]
    cmp eax, 0
    je .hurt
    jmp .done
.hurt:
    mov rax, [life]
    cmp rax, rdi
    jg .alive
    mov byte [is_dead], 1
    mov byte [anim_counter], 0
    mov byte [timer], 0

.alive:
    sub rax, rdi
    mov [life], rax
    mov al, [hurt_cooldown]
    mov byte [hurt_timer], al
.done:
    xor rax, rax
    ret





