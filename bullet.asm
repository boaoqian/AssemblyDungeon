section .data
align 16
;;constants
bullet_sprite_size equ 64
half_bullet_sprite_size equ bullet_sprite_size/2
sprite_columns equ 4
pos_top equ half_bullet_sprite_size+20
pos_bottom equ win_h-half_bullet_sprite_size-100
pos_left equ half_bullet_sprite_size+20
pos_right equ win_w-half_bullet_sprite_size-50
anim_fps equ 60/10


MAX_BULLETS        equ 64

;; Bullet struct layout (offsets)
B_ACTIVE  equ 0      ; db
B_STATE   equ 1      ; db
B_ANIM    equ 2      ; db
B_TIMER   equ 3      ; db
B_PAD     equ 4      ; padding -> align to 8
B_X       equ 8      ; dq
B_Y       equ 16     ; dq
B_SIZE    equ 24     ; total bytes per bullet (aligned to 8)

posx dq 0
posy dq 0
state        db 0
anim_counter db 0
timer        db 0


;; pool
bullets: times MAX_BULLETS*B_SIZE db 0


;; default variables
default_hurt dq 0
default_speed dq 0

bullet_texture dq 0

;; text data
img_path db "assets/bullet/PurpleEffectandBullet.png", 0
i1msg db "#1", 10, 0
i2msg db "#2", 10, 0
i3msg db "#3", 10, 0
i4msg db "#4", 10, 0
i5msg db "#5", 10, 0
debug_msg db "debug: %d", 10, 0



section .text
    global gen_bullet
    global bullets_step_all 
    global set_bullet
    global get_all_bullets_data
    global get_active_bullets_num



    extern load_texture
    extern draw_sprite_anim
    extern printf

    extern renptr
    extern win_h ;是值
    extern win_w ;是值

;-----------------------------------------
; set_bullet(rdi=hurt, rsi=speed)
;-----------------------------------------
set_bullet:
    mov [default_hurt], rdi
    mov [default_speed], rsi
    ret

;-----------------------------------------
; internal: ensure texture loaded once
; clobbers: rax, rdi, rsi
;-----------------------------------------
ensure_bullet_texture:
    sub rsp, 8
    mov rax, [bullet_texture]
    test rax, rax
    jne .done
    mov rdi, [renptr]
    mov rsi, img_path
    call load_texture
    mov [bullet_texture], rax
.done:
    add rsp, 8
    ret

;-----------------------------------------
; gen_bullet(rdi=x, rsi=y, cl=state)
; find inactive slot, init fields
;-----------------------------------------
gen_bullet:
    push r12
    sub rsp, 32
    mov [rsp], rdi
    mov [rsp+8], rsi
    mov [rsp+16], cl
    call ensure_bullet_texture
    mov rdi, [rsp]
    mov rsi, [rsp+8]
    mov cl, [rsp+16]

    cmp cl, 0
    jne .no0
    mov cl, 3
    jmp .mapped
.no0:
    cmp cl, 1
    jne .no1
    mov cl, 0
    jmp .mapped
.no1:
    cmp cl, 2
    jne .no2
    mov cl, 1
    jmp .mapped
.no2:
    cmp cl, 3
    jne .no3
    mov cl, 2
    jmp .mapped
.no3
    mov cl, 1
.mapped:
    ; --- 找空位 ---
    lea r9, [bullets]          ; r9 = bullet_ptr
    mov r12, MAX_BULLETS       ; r12 = 剩余可检查数量

.find:
    cmp byte [r9 + B_ACTIVE], 0
    je  .init                  ; 找到空位

    add r9, B_SIZE             ; bullet_ptr++
    dec r12
    jnz .find                  ; 还有就继续找
    add rsp, 32
    pop r12
    ret                         ; 没空位，直接放弃生成

.init:
    mov byte [r9 + B_ACTIVE], 1
    mov byte [r9 + B_STATE], cl
    mov byte [r9 + B_ANIM], 0
    mov byte [r9 + B_TIMER], 0

    mov [r9 + B_X], rdi
    mov [r9 + B_Y], rsi

    add rsp, 32
    pop r12
    ret


show_bullet:
    sub rsp, 24                     ; 给 [rsp] [rsp+8] 留空间，并保持对齐
 
    mov rdi, [renptr]
    mov rsi, [bullet_texture]
    mov rdx, [posx]
    sub rdx, half_bullet_sprite_size
    mov rcx, [posy]
    sub rcx, half_bullet_sprite_size
    mov r8d, bullet_sprite_size
    mov r9d, bullet_sprite_size

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
    sub rsp, 32

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
    sub rax, [default_speed]
    mov [posy], rax
    jmp .after_move

.move_left:
    mov rax, [posx]
    sub rax, [default_speed]
    mov [posx], rax
    jmp .after_move

.move_down:
    mov rax, [posy]
    add rax, [default_speed]
    mov [posy], rax
    jmp .after_move

.move_right:
    mov rax, [posx]
    add rax, [default_speed]
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
    add rsp, 32
    pop rbp
    ret

.dead:
    mov eax, 1                  ; rax = 1 (dead/outside)
    add rsp, 32
    pop rbp
    ret


bullets_step_all:
    sub rsp, 8
    push r12  
    push r13               

    lea r9, [bullets]          ; r9 = bullet_ptr
    mov r13, MAX_BULLETS

.loop:
    cmp byte [r9 + B_ACTIVE], 0
    je .next                   ; inactive -> skip

    ; ---- pool -> temp (给旧 bullet_step 用) ----
    mov rax, [r9 + B_X]
    mov [posx], rax
    mov rax, [r9 + B_Y]
    mov [posy], rax

    mov al, [r9 + B_STATE]
    mov [state], al
    mov al, [r9 + B_ANIM]
    mov [anim_counter], al
    mov al, [r9 + B_TIMER]
    mov [timer], al


    ; 保存指针，call 后恢复
    mov r12, r9
    call bullet_step
    mov r9, r12


    ; ---- 判断是否死了：eax==1 
    cmp eax, 1
    je .kill

    ; ---- temp -> pool（把更新后的状态写回实例）----
    mov rax, [posx]
    mov [r9 + B_X], rax
    mov rax, [posy]
    mov [r9 + B_Y], rax

    mov al, [state]
    mov [r9 + B_STATE], al
    mov al, [anim_counter]
    mov [r9 + B_ANIM], al
    mov al, [timer]
    mov [r9 + B_TIMER], al

    jmp .next

.kill:
    mov byte [r9 + B_ACTIVE], 0

.next:
    add r9, B_SIZE
    dec r13
    jnz .loop

    pop r13
    pop r12
    add rsp, 8
    ret


get_all_bullets_data:
    lea rax, [bullets]
    ret

get_active_bullets_num:
    xor eax, eax                  ; count = 0
    lea r8,  [rel bullets]        ; ptr
    mov ecx, MAX_BULLETS          ; i = 64

.loop:
    cmp byte [r8 + B_ACTIVE], 0
    je .next
    inc eax
.next:
    add r8, B_SIZE
    dec ecx
    jnz .loop
    ret

global get_bullet_hurt
get_bullet_hurt:
    mov rax, [default_hurt]
    ret