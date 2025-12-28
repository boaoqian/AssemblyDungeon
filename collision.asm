;=========================================================
; collision.asm  (NASM, x86-64 System V ABI)
; 玩家 vs mobs 碰撞检测：圆形碰撞（距离平方）
;=========================================================

default rel

section .data
; 这些数值要和 player.asm / mob.asm 的精灵尺寸一致
player_sprite_size equ 128
mob_size          equ 32

half_player       equ player_sprite_size/2
half_mob          equ mob_size/2
radius_sum        equ (half_player + half_mob)
radius_sum_sq     equ (radius_sum * radius_sum)

; ===== drops =====
MAX_DROPS equ 64

; drop 图块 48x48（和 drop.asm 默认一致）
drop_size      equ 48
half_drop      equ drop_size/2

; player_size 在你 collision.asm 里已经有 player_sprite_size equ 128
; 半径和：玩家半径 + 掉落物半径
radius_sum_drop    equ (half_player + half_drop)
radius_sum_drop_sq equ (radius_sum_drop * radius_sum_drop)

; Drop struct layout（要和 drop.asm 一致）
D_ACTIVE equ 0
D_TYPE   equ 1
D_ANIM   equ 2
D_TIMER  equ 3
D_X      equ 8
D_Y      equ 16
D_SIZE   equ 24

heal_per_pick db 10   ; 捡到一次加多少血（你想改就改）

;; Mob struct layout (offsets)
M_ACTIVE  equ 0      ; db  0/1
M_STATE   equ 1      ; db
M_ANIM    equ 2      ; db
M_TIMER   equ 3      ; db
M_PAD     equ 4      ; padding -> align to 8
M_X       equ 8      ; dq
M_Y       equ 16     ; dq
M_HP      equ 24     ; dq
M_SKILL_CD_TIMER equ 32
M_ATK_VX   equ 40     ; dq (double) 方向x（单位向量）
M_ATK_VY   equ 48     ; dq (double) 方向y
M_SIZE     equ 56     ;

; --- bullet struct layout (from bullet.asm) ---
B_ACTIVE  equ 0
B_X       equ 8
B_Y       equ 16
B_SIZE    equ 24

MAX_BULLETS             equ 64
MAX_MOBS             equ 32

bullet_damage dq 10      ; 每颗子弹对 mob 的伤害（你可改）
                          ; 如果你想用 bullet.asm 的 default_hurt，
                          ; 建议额外导出一个 get_bullet_hurt() 再在这里 call

damage_per_hit db 10               ; 每次碰撞扣多少血（你可改）

section .text
global check_player_mob_collisions
global check_mob_bullet_collisions
global check_player_drop_collisions

extern get_all_drops_data
extern get_player_max_mana
extern set_player_max_mana
extern get_player_pos
extern hurt_player
extern get_all_mobs_data
extern get_all_bullets_data
extern get_bullet_hurt
extern set_player_pos
;---------------------------------------------------------
; void check_player_mob_collisions()
;  - 遍历 mobs，若碰撞则 hurt_player(damage)
;---------------------------------------------------------
check_player_mob_collisions:
    push rbp
    mov rbp, rsp
    sub rsp, 32                    ; 放玩家坐标临时变量 + 对齐

    ; 取玩家坐标到 [rsp+0]=x, [rsp+8]=y
    lea rdi, [rsp+0]
    lea rsi, [rsp+8]
    call get_player_pos

    ; rbx = mobs 指针
    call get_all_mobs_data
    mov rbx, rax

    mov ecx, MAX_MOBS

.loop:
    cmp byte [rbx + M_ACTIVE], 0
    je .next

    ; dx = mob_x - player_x
    mov rax, [rbx + M_X]
    sub rax, [rsp+0]               ; rax = dx
    mov [rsp+16], rax

    ; dy = mob_y - player_y
    mov rdx, [rbx + M_Y]
    add rdx, 20; 减mob空高度
    sub rdx, [rsp+8]               ; rdx = dy
    mov [rsp+24], rdx

    ; dist2 = dx*dx + dy*dy   (用 64-bit)
    imul rax, rax                  ; dx^2
    add rax, 2000
    imul rdx, rdx                  ; dy^2
    add rax, rdx                   ; rax = dist2

    ; if dist2 <= radius_sum_sq => hit
    cmp rax, radius_sum_sq
    ja  .next
    ;击退
    mov rdi, [rsp+0]
    mov rsi, [rsp+8]
    sub rdi, [rsp+16]
    sub rsi, [rsp+24]
    call set_player_pos
    ; 碰到了：扣血（hurt_player 内部自带无敌时间判定）
    movzx edi, byte [damage_per_hit]
    call hurt_player


.next:
    add rbx, M_SIZE
    dec ecx
    jnz .loop

    add rsp, 32
    pop rbp
    ret

check_mob_bullet_collisions:
    push r12
    push r13
    push r14
    push r15
    push rbp
    
    mov rbp, rsp
    sub rsp, 8                 ; 简单对齐（SysV call 需要 16 对齐）

    call get_bullet_hurt
    mov [bullet_damage], rax

    ; r12 = mobs base
    call get_all_mobs_data
    mov r12, rax

    ; r13 = bullets base
    call get_all_bullets_data
    mov r13, rax

    xor r14d, r14d             ; mob index = 0

.mob_loop:
    cmp r14d, MAX_MOBS
    jge .done

    ; mob_ptr = r12 + r14*M_SIZE
    mov rbx, r12
    mov eax, r14d
    imul rax, M_SIZE
    add rbx, rax

    cmp byte [rbx + M_ACTIVE], 0
    je .next_mob

    xor r15d, r15d             ; bullet index = 0

.bul_loop:
    cmp r15d, MAX_BULLETS
    jge .next_mob

    ; bul_ptr = r13 + r15*B_SIZE
    mov r8, r13
    mov eax, r15d
    imul rax, B_SIZE
    add r8, rax

    cmp byte [r8 + B_ACTIVE], 0
    je .next_bul

    ; dx = bul_x - mob_x
    mov rax, [r8 + B_X]
    sub rax, [rbx + M_X]       ; rax = dx

    ; dy = bul_y - mob_y
    mov rdx, [rbx + M_Y]
    add rdx, 20; 减mob空高度
    sub rdx, [r8 + B_Y]      ; rdx = dy


    ; dist2 = dx*dx + dy*dy  (64-bit)
    imul rax, rax              ; dx^2
    imul rdx, rdx              ; dy^2
    add rax, 2000
    add rdx, 2000
    add rax, rdx               ; rax = dist2

    ; hit ?
    cmp rax, radius_sum_sq
    ja  .next_bul

    ;-------------------------
    ; 命中处理：
    ; 1) 子弹失活
    ;-------------------------
    mov byte [r8 + B_ACTIVE], 0

    ;-------------------------
    ; 2) mob 扣血
    ;-------------------------
    mov rax, [rbx + M_HP]
    sub rax, [bullet_damage]
    mov [rbx + M_HP], rax

    ; hp <= 0 => kill mob
    test rax, rax
    jg .next_bul
    mov byte [rbx + M_ACTIVE], 0
    jmp .next_mob              ; mob 都死了就不用继续测它的子弹了

.next_bul:
    inc r15d
    jmp .bul_loop

.next_mob:
    inc r14d
    jmp .mob_loop

.done:
    add rsp, 8
    pop rbp
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    ret

;---------------------------------------------------------
; void check_player_drop_collisions()
;  - 遍历 drops，若碰撞则：
;      1) heal_player(heal_per_pick)
;      2) drop 失活（消失）
;---------------------------------------------------------
check_player_drop_collisions:
    push rbp
    mov rbp, rsp
    sub rsp, 32                    ; [0]=px [8]=py [16]=dx [24]=dy

    ; 取玩家坐标到 [rsp+0]=x, [rsp+8]=y
    lea rdi, [rsp+0]
    lea rsi, [rsp+8]
    call get_player_pos

    ; rbx = drops base
    call get_all_drops_data
    mov rbx, rax

    mov ecx, MAX_DROPS

.loop:
    cmp byte [rbx + D_ACTIVE], 0
    je .next

    ; dx = drop_x - player_x
    mov rax, [rbx + D_X]
    sub rax, [rsp+0]
    mov [rsp+16], rax

    ; dy = drop_y - player_y
    mov rdx, [rbx + D_Y]
    sub rdx, [rsp+8]
    mov [rsp+24], rdx

    ; dist2 = dx*dx + dy*dy
    imul rax, rax
    imul rdx, rdx
    add rax, rdx

    ; hit ?
    cmp rax, radius_sum_drop_sq
    ja .next

    ; 1) drop 消失
    mov byte [rbx + D_ACTIVE], 0

    call get_player_max_mana
    add rax, 100
    mov rdi, rax
    call set_player_max_mana

.next:
    add rbx, D_SIZE
    dec ecx
    jnz .loop

    add rsp, 32
    pop rbp
    ret
