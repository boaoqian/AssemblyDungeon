;=========================================================
; mob.asm  (NASM, x86-64 System V ABI)
;  - 参考你给的 bullet.asm 结构：对象池 + 逐个 step + 动画绘制
;  - 这里假设 mob 是个 64x64 精灵图（按行是 state，按列是 anim）
;  - state: 0=left 1=down 2=right 3=up  （你也可以自己改映射）
;
; 导出：
;   set_mob(rdi=hp, rsi=speed)
;   gen_mob(rdi=x, rsi=y)
;   mobs_step_all()
;   get_all_mobs_data() -> rax = &mobs
;   get_active_mobs_num() -> eax = count
;
; 依赖外部：
;   load_texture(renderer, path) -> rax=texture
;   draw_sprite_anim(renderer, texture, x, y, w, h, frame_index, columns)
;   renptr, win_w, win_h
;=========================================================

default rel

section .data
align 16
;; constants
mob_size          equ 82
half_mob_size     equ mob_size/2
mob_columns       equ 8                 ; 每行 4 帧动画
anim_fps          equ 60//8             ; 每 6 帧切一次动画

;; 屏幕边界（留一点边距，可自行调整）
pos_top           equ half_mob_size+10
pos_bottom        equ win_h-half_mob_size-10
pos_left          equ half_mob_size+10
pos_right         equ win_w-half_mob_size-10

MAX_MOBS          equ 32

;; Mob struct layout (offsets)
M_ACTIVE  equ 0      ; db  0/1
M_STATE   equ 1      ; db
M_ANIM    equ 2      ; db
M_TIMER   equ 3      ; db
M_PAD     equ 4      ; padding -> align to 8
M_X       equ 8      ; dq
M_Y       equ 16     ; dq
M_HP      equ 24     ; dq
M_SIZE    equ 32     ; total bytes per mob (aligned to 8)

;; 用于复用旧式 step 的临时变量（和你 bullet.asm 类似）
posx         dq 0
posy         dq 0
player_x     dq 0
player_y     dq 0
hp_tmp       dq 0
state        db 0
anim_counter db 0
timer        db 0

;; pool
mobs: times MAX_MOBS*M_SIZE db 0

;; default config
default_hp    dq 0
default_speed dq 0
atteck_speed  dq 0

mob_texture dq 0

;; texture path
img_path db "assets/mod/slimer.png", 0

section .text
global set_mob
global gen_mob
global mobs_step_all
global get_all_mobs_data
global get_active_mobs_num

extern load_texture
extern draw_sprite_anim
extern get_player_pos
extern renptr
extern win_h     ; value
extern win_w     ; value


;-----------------------------------------
; set_mob(rdi=hp, rsi=speed)
;-----------------------------------------
set_mob:
    mov [default_hp], rdi
    mov [atteck_speed], rsi
    ret


;-----------------------------------------
; internal: ensure texture loaded once
; clobbers: rax, rdi, rsi
;-----------------------------------------
ensure_mob_texture:
    sub rsp, 8                    ; align for call (SysV)
    mov rax, [mob_texture]
    test rax, rax
    jne .done
    mov rdi, [renptr]
    mov rsi, img_path
    call load_texture
    mov [mob_texture], rax
    mov qword [default_speed], 2
.done:
    add rsp, 8
    ret

;-----------------------------------------
; gen_mob(rdi=x, rsi=y)
; 找到空位并初始化
;-----------------------------------------
gen_mob:
    push r12
    sub rsp, 16
    mov [rsp], rdi
    mov [rsp+8], rsi
    call ensure_mob_texture
    mov rdi, [rsp]
    mov rsi, [rsp+8]

    ; --- 找空位 ---
    lea r9, [mobs]
    mov r12, MAX_MOBS

.find:
    cmp byte [r9 + M_ACTIVE], 0
    je .init
    add r9, M_SIZE
    dec r12
    jnz .find

    add rsp, 16
    pop r12
    ret                 ; 没空位直接放弃

.init:
    mov byte [r9 + M_ACTIVE], 1
    mov byte [r9 + M_ANIM],   0
    mov byte [r9 + M_TIMER],  0

    mov [r9 + M_X], rdi
    mov [r9 + M_Y], rsi

    mov rax, [default_hp]
    mov [r9 + M_HP], rax

    add rsp, 16
    pop r12
    ret


;-----------------------------------------
; show_mob: 使用临时变量 posx/posy/state/anim_counter 绘制
;-----------------------------------------
show_mob:
    ; draw_sprite_anim(renderer, texture, x, y, w, h, frame_index, columns)
    ; 额外参数 frame_index, columns 放到栈上传给被调函数（和你 bullet.asm 一样）
    sub rsp, 24

    mov rdi, [renptr]
    mov rsi, [mob_texture]

    mov rdx, [posx]
    sub rdx, half_mob_size
    mov rcx, [posy]
    sub rcx, half_mob_size

    mov r8d, mob_size
    mov r9d, mob_size

    ; frame_index = state*columns + anim
    movzx rax, byte [state]
    mov r10, mob_columns
    imul rax, r10
    movzx r10, byte [anim_counter]
    add rax, r10

    mov [rsp+0], rax
    mov qword [rsp+8], mob_columns
    call draw_sprite_anim

    add rsp, 24
    ret


;-----------------------------------------
; mob_step:
;  - 根据 state 移动
;  - 出屏则返回 eax=1（死/删除）
;  - 否则更新动画并绘制，返回 eax=0
;-----------------------------------------
mob_step:
    push rbp
    mov rbp, rsp
    sub rsp, 32
    
    call face_to_player
    call close_to_player

.after_move:
    ; --- X 边界钳制 ---
    mov rax, [posx]
    cmp rax, pos_left
    jge .x_check_right
    mov qword [posx], pos_left
    jmp .y_check

.x_check_right:
    cmp rax, pos_right
    jle .y_check
    mov qword [posx], pos_right

.y_check:
    ; --- Y 边界钳制 ---
    mov rax, [posy]
    cmp rax, pos_top
    jge .y_check_bottom
    mov qword [posy], pos_top
    jmp .anim

.y_check_bottom:
    cmp rax, pos_bottom
    jle .anim
    mov qword [posy], pos_bottom

.anim:
    ; --- 动画更新 ---
    cmp byte [timer], anim_fps
    jl .no_update_anim
    mov byte [timer], 0
    add byte [anim_counter], 1
    cmp byte [anim_counter], mob_columns
    jl .no_update_anim
    mov byte [anim_counter], 0
.no_update_anim:
    add byte [timer], 1

    ; --- 绘制 ---
    call show_mob
    xor eax, eax          ; alive

    add rsp, 32
    pop rbp
    ret


    ; =====================================================
    ; move: pos += normalize(player - pos) * atteck_speed
    ; 用 double 计算方向向量，最后转回 int 写回 posx/posy
    ; =====================================================

close_to_player:
    ; dx = player_x - posx  (int64)
    mov rax, [player_x]
    sub rax, [posx]                 ; rax = dx

    ; dy = player_y - posy
    mov rdx, [player_y]
    sub rdx, [posy]                 ; rdx = dy

    ; xmm0 = (double)dx
    cvtsi2sd xmm0, rax

    ; xmm1 = (double)dy
    cvtsi2sd xmm1, rdx

    ; len = sqrt(dx*dx + dy*dy)
    movapd xmm2, xmm0               ; xmm2 = dx
    mulsd  xmm2, xmm2               ; dx^2
    movapd xmm3, xmm1               ; xmm3 = dy
    mulsd  xmm3, xmm3               ; dy^2
    addsd  xmm2, xmm3               ; dx^2 + dy^2
    sqrtsd xmm2, xmm2               ; len

    ; if len <= 0.0 -> 不移动（避免除0）
    xorpd  xmm7, xmm7               ; xmm7 = 0.0
    comisd xmm2, xmm7
    jbe .after_move                 ; len <= 0

    ; speed_d = (double)atteck_speed
    mov rax, [default_speed]
    cvtsi2sd xmm4, rax              ; xmm4 = speed

    ; vx = dx / len * speed
    movapd xmm5, xmm0               ; xmm5 = dx
    divsd  xmm5, xmm2               ; dx/len
    mulsd  xmm5, xmm4               ; vx

    ; vy = dy / len * speed
    movapd xmm6, xmm1               ; xmm6 = dy
    divsd  xmm6, xmm2               ; dy/len
    mulsd  xmm6, xmm4               ; vy

    ; posx += (int)vx
    cvttsd2si rax, xmm5
    add [posx], rax

    ; posy += (int)vy
    cvttsd2si rax, xmm6
    add [posy], rax
.after_move:
    ret


face_to_player:
    mov rax, [player_x]
    cmp rax, [posx]
    jl .if1
    mov byte [state], 0
    jmp .done
    .if1:
    mov byte [state], 3
.done:
    ret


;-----------------------------------------
; mobs_step_all:
;  - 遍历对象池
;  - pool -> temp -> mob_step -> temp -> pool
;  - 死了就清 active
;-----------------------------------------
mobs_step_all:
    sub rsp, 8
    push r12
    push r13

    mov rdi, player_x
    mov rsi, player_y
    call get_player_pos

    lea r9, [mobs]
    mov r13, MAX_MOBS

.loop:
    cmp byte [r9 + M_ACTIVE], 0
    je .next
    ; pool -> temp
    mov rax, [r9 + M_X]
    mov [posx], rax
    mov rax, [r9 + M_Y]
    mov [posy], rax
    mov rax, [r9 + M_HP]
    mov [hp_tmp], rax
    mov al, [r9 + M_ANIM]
    mov [anim_counter], al
    mov al, [r9 + M_TIMER]
    mov [timer], al

    mov r12, r9
    call mob_step
    mov r9, r12

    ;temp->pool
    mov rax, [posx]
    mov [r9 + M_X], rax
    mov rax, [posy]
    mov [r9 + M_Y], rax

    cmp eax, 1
    je .kill

    ; temp -> pool
    mov rax, [posx]
    mov [r9 + M_X], rax
    mov rax, [posy]
    mov [r9 + M_Y], rax
    mov rax, [hp_tmp]
    mov [r9 + M_HP], rax
    mov al, [anim_counter]
    mov [r9 + M_ANIM], al
    mov al, [timer]
    mov [r9 + M_TIMER], al

    jmp .next

.kill:
    mov byte [r9 + M_ACTIVE], 0

.next:
    add r9, M_SIZE
    dec r13
    jnz .loop

    pop r13
    pop r12
    add rsp, 8
    ret


;-----------------------------------------
; get_all_mobs_data() -> &mobs
;-----------------------------------------
get_all_mobs_data:
    lea rax, [mobs]
    ret

;-----------------------------------------
; get_active_mobs_num() -> eax
;-----------------------------------------
get_active_mobs_num:
    xor eax, eax
    lea r8, [mobs]
    mov ecx, MAX_MOBS

.loop2:
    cmp byte [r8 + M_ACTIVE], 0
    je .next2
    inc eax
.next2:
    add r8, M_SIZE
    dec ecx
    jnz .loop2
    ret
