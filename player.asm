section .data
align 16
;;constants
sprite_size equ 128
half_sprite_size equ sprite_size/2
sprite_columns equ 9
pos_top equ half_sprite_size+10
pos_bottom equ win_h-half_sprite_size-10
pos_left equ half_sprite_size+10
pos_right equ win_w-half_sprite_size-10
anim_fps equ 60/10

;; global variables
life db 0
posx dq 0
posy dq 0
move_speed dq 0
state db 0
weapon_cooldown db 0

key_state dd 0
player_texture dq 0
anim_counter db 0
timer db 0
weapon_timer db 0

;; text data
img_path db "assets/player/walk.png", 0
debugmsg db "DEBUG: %d", 10, 0
iimsg db "##########", 10, 0

section .text
    global init_player
    global player_step 
    global show_player

    extern load_texture
    extern draw_sprite_anim
    extern input_poll
    extern gen_bullet
    extern bullet_step 
    extern show_bullet
    extern set_bullet
    extern printf

    extern event_buffer
    extern renptr
    extern win_h
    extern win_w


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

    ;;init value
    mov qword [posx], 500
    mov qword [posy], 350
    mov byte [life], 0
    mov byte [state], 2
    mov byte [anim_counter], 0
    mov byte [timer], 0
    mov qword [move_speed], 5

    add rsp, 8
    ret

show_player:
    sub rsp, 24                     ; 保持 call 前 rsp % 16 == 8
    mov rdi, [renptr]
    mov rsi, [player_texture]
    mov rdx, [posx]
    sub rdx, half_sprite_size       
    mov rcx, [posy]
    sub rcx, half_sprite_size
    mov r8d, sprite_size
    mov r9d, sprite_size
    movzx rax, byte [state]         ; 零扩展字节到 64 位
    mov r10, sprite_columns
    imul rax, r10
    movzx r10, byte [anim_counter]
    add rax, r10
    mov [rsp+0], rax                ; frame_index
    mov qword [rsp+8], sprite_columns  ; columns (64-bit!)
    call draw_sprite_anim
    add rsp, 24
    ret

player_step:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    mov al, [state]; old state
    mov [rsp+12], al
    lea rdi, event_buffer
    lea rsi, [key_state] ;key bitmask
    lea rdx, [rsp+0]; mouse_x
    lea rcx, [rsp+4]; mouse_y
    call input_poll
    test eax, eax
    jz .noesc
    jmp .exit

.noesc:
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
    call show_player
    add byte [timer], 1
    jmp .done

.idle_anim:
    mov byte [anim_counter], 0
    call show_player
    mov byte [timer], 1

.done:
    mov ecx, [rsp]
    cmp ecx, -1
    je .no_mouse
    mov rdi, 4
    mov rsi, 10
    call set_bullet
    mov rdi, [posx]
    mov rsi, [posy]
    mov cl, [state]
    call gen_bullet

.no_mouse:
    xor rax, rax
    add rsp, 32
    pop rbp
    ret

.exit:
    ; ESC / Quit: 让 main 来退出
    mov rax, 1
    add rsp, 32
    pop rbp
    ret




