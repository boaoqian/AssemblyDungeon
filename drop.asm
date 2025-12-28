;=========================================================
; drop.asm  (NASM, x86-64 System V ABI)
;  - 参考 mob.asm：对象池 + step_all + 动画绘制
;  - 掉落物品不移动：只更新动画（可关）并绘制
;
; 导出：
;   set_drop(rdi=size, rsi=columns)          ; 配置尺寸/列数(动画帧列)
;   gen_drop(rdi=x, rsi=y, rdx=type)         ; 生成一个掉落物（type可用于挑不同图行/不同图）
;   drops_step_all()
;   get_all_drops_data() -> rax = &drops
;   get_active_drops_num() -> eax = count
;   clear_drops()
;
; 依赖外部（与你 mob.asm 一致风格）：
;   load_texture(renderer, path) -> rax=texture
;   draw_sprite_anim(renderer, texture, x, y, w, h, frame_index, columns)
;   renptr, win_w, win_h
;=========================================================

default rel

section .data
align 16

MAX_DROPS        equ 64

; ===== 可配置参数（set_drop 写入）=====
drop_size        dq 48             ; 默认 48x48
drop_half        dq 24
drop_columns     dq 4              ; 一行多少帧（动画列数）
anim_fps         equ 60/8          ; 每 (60/8)=7 帧切一次动画（你也可改）

; ===== Drop struct layout (offsets) =====
D_ACTIVE  equ 0     ; db 0/1
D_TYPE    equ 1     ; db 物品类型（决定用第几行/或以后做不同贴图）
D_ANIM    equ 2     ; db 当前动画帧(列索引)
D_TIMER   equ 3     ; db 动画计时
D_PAD     equ 4     ; padding
D_X       equ 8     ; dq
D_Y       equ 16    ; dq
D_SIZE    equ 24    ; struct size = 24

; ===== 临时变量（按 mob.asm 那种 temp 拷贝做 step）=====
posx         dq 0
posy         dq 0
type_tmp     db 0
anim_counter db 0
timer        db 0

; ===== pool =====
drops: times MAX_DROPS*D_SIZE db 0

; ===== texture =====
drop_texture dq 0
img_path db "assets/mod/drop.png", 0  ; 你换成自己的掉落物贴图
                                      ; 建议贴图排布：按行是 type，按列是 anim

section .text
global set_drop
global gen_drop
global drops_step_all
global get_all_drops_data
global get_active_drops_num
global clear_drops

extern load_texture
extern draw_sprite_anim
extern renptr

;-----------------------------------------
; set_drop(rdi=size, rsi=columns)
;  - size: 物品绘制尺寸（正方形）
;  - columns: 每行动画帧数量
;-----------------------------------------
set_drop:
    mov [drop_size], rdi
    mov rax, rdi
    shr rax, 1
    mov [drop_half], rax
    mov [drop_columns], rsi
    ret

;-----------------------------------------
; internal: ensure texture loaded once
;-----------------------------------------
ensure_drop_texture:
    sub rsp, 8
    mov rax, [drop_texture]
    test rax, rax
    jne .done
    mov rdi, [renptr]
    mov rsi, img_path
    call load_texture
    mov [drop_texture], rax
.done:
    add rsp, 8
    ret

;-----------------------------------------
; gen_drop(rdi=x, rsi=y, rdx=type)
;  - 找空位并初始化
;-----------------------------------------
gen_drop:
    push r12
    sub rsp, 16

    mov [rsp], rdi       ; x
    mov [rsp+8], rsi     ; y
    call ensure_drop_texture
    mov rdi, [rsp]
    mov rsi, [rsp+8]
    ; rdx = type 保持不动

    lea r9, [drops]
    mov r12, MAX_DROPS

.find:
    cmp byte [r9 + D_ACTIVE], 0
    je .init
    add r9, D_SIZE
    dec r12
    jnz .find

    add rsp, 16
    pop r12
    ret                  ; 没空位

.init:
    mov byte [r9 + D_ACTIVE], 1
    mov byte [r9 + D_TYPE], dl
    mov byte [r9 + D_ANIM], 0
    mov byte [r9 + D_TIMER], 0
    mov [r9 + D_X], rdi
    mov [r9 + D_Y], rsi

    add rsp, 16
    pop r12
    ret

;-----------------------------------------
; show_drop: 绘制（不移动）
;  frame_index = type*columns + anim
;-----------------------------------------
show_drop:
    sub rsp, 24

    mov rdi, [renptr]
    mov rsi, [drop_texture]

    mov rdx, [posx]
    mov rax, [drop_half]
    sub rdx, rax

    mov rcx, [posy]
    mov rax, [drop_half]
    sub rcx, rax

    mov r8, [drop_size]
    mov r9, [drop_size]

    ; frame_index = type*columns + anim
    movzx rax, byte [type_tmp]
    mov r10, [drop_columns]
    imul rax, r10
    movzx r10, byte [anim_counter]
    add rax, r10

    mov [rsp+0], rax
    mov rax, [drop_columns]
    mov [rsp+8], rax
    call draw_sprite_anim

    add rsp, 24
    ret

;-----------------------------------------
; drop_step:
;  - 不移动
;  - 更新动画（如果你想静止不闪，注释掉 anim 部分即可）
;-----------------------------------------
drop_step:
    ; --- 动画更新 ---
    cmp byte [timer], anim_fps
    jl .no_update_anim
    mov byte [timer], 0
    add byte [anim_counter], 1
    mov rax, [drop_columns]
    cmp byte [anim_counter], al
    jl .no_update_anim
    mov byte [anim_counter], 0
.no_update_anim:
    add byte [timer], 1

    ; --- 绘制 ---
    call show_drop
    xor eax, eax
    ret

;-----------------------------------------
; drops_step_all:
;  - 遍历对象池：pool -> temp -> drop_step -> temp -> pool
;-----------------------------------------
drops_step_all:
    sub rsp, 8
    push r12
    push r13

    lea r9, [drops]
    mov r13, MAX_DROPS

.loop:
    cmp byte [r9 + D_ACTIVE], 0
    je .next

    ; pool -> temp
    mov rax, [r9 + D_X]
    mov [posx], rax
    mov rax, [r9 + D_Y]
    mov [posy], rax
    mov al, [r9 + D_TYPE]
    mov [type_tmp], al
    mov al, [r9 + D_ANIM]
    mov [anim_counter], al
    mov al, [r9 + D_TIMER]
    mov [timer], al

    mov r12, r9
    call drop_step
    mov r9, r12

    ; temp -> pool
    mov al, [anim_counter]
    mov [r9 + D_ANIM], al
    mov al, [timer]
    mov [r9 + D_TIMER], al

.next:
    add r9, D_SIZE
    dec r13
    jnz .loop

    pop r13
    pop r12
    add rsp, 8
    ret

;-----------------------------------------
; get_all_drops_data() -> &drops
;-----------------------------------------
get_all_drops_data:
    lea rax, [drops]
    ret

;-----------------------------------------
; get_active_drops_num() -> eax
;-----------------------------------------
get_active_drops_num:
    xor eax, eax
    lea r8, [drops]
    mov ecx, MAX_DROPS
.loop2:
    cmp byte [r8 + D_ACTIVE], 0
    je .next2
    inc eax
.next2:
    add r8, D_SIZE
    dec ecx
    jnz .loop2
    ret

;-----------------------------------------
; clear_drops(): 整块清零
;-----------------------------------------
clear_drops:
    lea rdi, [drops]
    xor eax, eax
    mov ecx, (MAX_DROPS*D_SIZE)/8
    rep stosq
    ret
