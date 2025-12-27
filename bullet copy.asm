section .data
align 16
;;constants
sprite_size equ 64
half_sprite_size equ sprite_size/2
sprite_columns equ 4
pos_top equ half_sprite_size+10
pos_bottom equ win_h-half_sprite_size-10
pos_left equ half_sprite_size+10
pos_right equ win_w-half_sprite_size-10
anim_fps equ 60/10

;; global variables
hurt dq 0
posx dq 0
posy dq 0
move_speed dq 0
state db 0

bullet_texture dq 0
anim_counter db 0
timer db 0

;; text data
img_path db "assets/bullet/PurpleEffectandBullet.png", 0
i1msg db "#1", 10, 0
i2msg db "#2", 10, 0
i3msg db "#3", 10, 0
i4msg db "#4", 10, 0
i5msg db "#5", 10, 0



section .text
    global gen_bullet
    global bullet_step 
    global show_bullet
    global set_bullet

    extern load_texture
    extern draw_sprite_anim
    extern printf

    extern have_bullet
    extern renptr
    extern win_h
    extern win_w

;rdi = hurt, rsi = speed
set_bullet:
    sub rsp, 8 
    mov [hurt], rdi
    mov [move_speed], rsi
    add rsp, 8
    ret

;rdi = x, rsi = y, cl = state
gen_bullet:
    sub rsp, 8              ; 保证 call 前对齐
    mov byte [have_bullet], 1
    mov [posx], rdi
    mov [posy], rsi
    ;modify state
    cmp cl, 0
    jne .no0
    mov cl, 3
    jmp .dones
    .no0:
    cmp cl, 1
    jne .no1
    mov cl, 0
    jmp .dones
    .no1:
    cmp cl, 2
    jne .no2
    mov cl, 1
    jmp .dones
    .no2:
    mov cl, 2
    .dones:
    mov [state], cl
    mov byte [anim_counter], 0
    mov byte [timer], 0
    mov rdi, [renptr]
    mov rsi, img_path
    call load_texture
    mov [bullet_texture], rax
    add rsp, 8
    ret


show_bullet:
    sub rsp, 24                     ; 给 [rsp] [rsp+8] 留空间，并保持对齐
    mov rdi, [renptr]
    mov rsi, [bullet_texture]
    mov rdx, [posx]
    sub rdx, half_sprite_size
    mov rcx, [posy]
    sub rcx, half_sprite_size
    mov r8d, sprite_size
    mov r9d, sprite_size

    movzx rax, byte [state]
    mov r10, sprite_columns
    imul rax, r10
    movzx r10, byte [anim_counter]
    add rax, r10

    mov [rsp+0], rax
    mov qword [rsp+8], sprite_columns
    call draw_sprite_anim
    add rsp, 24
    ret


bullet_step:
    push rbp
    mov rbp, rsp
    sub rsp, 16

    ; --- 根据 state 移动 ---
    movzx eax, byte [state]
    cmp eax, 3
    je .move_up
    cmp eax, 0
    je .move_left
    cmp eax, 1
    je .move_down
    cmp eax, 2
    je .move_right
    jmp .after_move             ; 其它值：不动

.move_up:
    mov rax, [posy]
    sub rax, [move_speed]
    mov [posy], rax
    jmp .after_move

.move_left:
    mov rax, [posx]
    sub rax, [move_speed]
    mov [posx], rax
    jmp .after_move

.move_down:
    mov rax, [posy]
    add rax, [move_speed]
    mov [posy], rax
    jmp .after_move

.move_right:
    mov rax, [posx]
    add rax, [move_speed]
    mov [posx], rax
    jmp .after_move

.after_move:

    ; --- 出屏检测：出屏就返回 1（你可用它删除子弹）---
    ; posx < 0 或 posx > win_w 或 posy < 0 或 posy > win_h
    mov rax, [posx]
    test rax, rax
    jl .dead
    mov rdx, win_w
    cmp rax, rdx
    jg .dead

    mov rax, [posy]
    test rax, rax
    jl .dead
    mov rdx, win_h
    cmp rax, rdx
    jg .dead

    ; --- 动画更新（和你 player 的写法一致）---
    cmp byte [timer], anim_fps
    jl .no_update_anim
    mov byte [timer], 0
    add byte [anim_counter], 1
    cmp byte [anim_counter], sprite_columns
    jl .no_update_anim
    mov byte [anim_counter], 0
.no_update_anim:
    add byte [timer], 1
    ; --- 画子弹 ---

    call show_bullet

    xor eax, eax                ; rax = 0 (alive)
    add rsp, 16
    pop rbp
    ret

.dead:

    mov byte [have_bullet], 0
    mov eax, 1                  ; rax = 1 (dead/outside)
    add rsp, 16
    pop rbp
    ret






