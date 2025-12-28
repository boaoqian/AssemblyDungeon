section .data
    heart_path db "assets/heart.png", 0
    empty_heart_path db "assets/emptyheart.png", 0
    heart_texture dq 0
    emptyheart_texture dq 0

    mana_path db "assets/mana.png", 0
    empty_mana_path db "assets/emptymana.png", 0
    mana_texture dq 0
    emptymana_texture dq 0


 ;===== 贴图路径（你按自己素材改）=====
    pause_btn_path     db "assets/ui/btn_pause.png", 0       ; 游戏中“暂停”按钮
    resume_btn_path    db "assets/ui/btn_resume.png", 0      ; 暂停界面“继续”
    quit_btn_path      db "assets/ui/btn_quit.png", 0        ; （可选）退出
    pause_panel_path   db "assets/ui/pause_panel.png", 0     ; 暂停面板背景（可选）
    dead_panel_path db "assets/ui/dead_panel.png", 0
    next_level_panel_path db "assets/ui/next_panel.png", 0

    debugmsg db "debug: %d", 10, 0

    ; ===== 贴图句柄 =====
    tex_pause_btn    dq 0
    tex_resume_btn   dq 0
    tex_quit_btn     dq 0
    tex_pause_panel  dq 0
    tex_dead_panel   dq 0
    tex_next_level_panel dq 0

    ; ===== UI矩形（用“图片真实宽高”更好，但你当前 draw_texture 会自动查询尺寸:contentReference[oaicite:4]{index=4}）
    ; 这里我们只需要：按钮摆放位置 + 你按钮图片的宽高（用于点击检测）
    ; !!! 下面宽高你要按你的按钮图片实际像素改 !!!
    %define PAUSE_BTN_X   win_w-100
    %define PAUSE_BTN_Y   0
    %define PAUSE_BTN_W   96
    %define PAUSE_BTN_H   96

    %define PANEL_X       250
    %define PANEL_Y       140

    %define RESUME_X      550
    %define RESUME_Y      250
    %define RESUME_W      192
    %define RESUME_H      96

    %define QUIT_X        320
    %define QUIT_Y        250
    %define QUIT_W        192
    %define QUIT_H        96


section .bss
    ui_state  resd 1   ; 0=无覆盖层 1=暂停 2=死亡 3=下一关


section .text

%define LIFE_START_X    20        ; 起始x（按你需要改）
%define LIFE_START_Y    20        ; 起始y（按你需要改）
%define LIFE_BAR_WIDTH  300       ; 整条血条占用宽度（按你需要改）
%define HEART_MIN_SPACING 10      ; spacing下限，避免太挤（按你需要改）
%define POINTS_PER_HEART 10

%define MANA_START_X    600        ; 起始x（按你需要改）
%define MANA_START_Y    20        ; 起始y（按你需要改）
%define MANA_BAR_WIDTH  300       ; 整条血条占用宽度（按你需要改）
%define MANA_MIN_SPACING 1      ; spacing下限，避免太挤（按你需要改）

global draw_life_bar
global init_life_bar
global show_life_info

global draw_mana_bar
global init_mana_bar
global show_mana_info


global ui_get_state
global ui_set_state



global ui_init
global ui_draw_game_ui
global ui_draw_pause_ui
global ui_handle_mouse

extern printf
extern draw_texture
extern renptr
extern load_texture
extern get_player_life
extern get_player_max_life
extern get_player_max_mana
extern get_player_mana

extern mouse_x
extern mouse_y

extern win_h
extern win_w



ui_init:
sub rsp, 8
    call init_life_bar
    call init_mana_bar  
    call ui_init_overlay
add rsp, 8
    ret

;--------------------------------------------
; draw_life_bar(renderer=rdi, heart_tex=rsi, life=edx, max_life=ecx, r8=empty_heart_tex)
; life/max_life: 生命点数
; 每10点生命画一个heart
; spacing = LIFE_BAR_WIDTH / (max_life/10)
; 依赖：extern draw_texture(renderer, tex, x, y)
; ---------------------------------------------------------

init_life_bar:
    sub rsp, 8
    mov rdi, [renptr]
    mov rsi, heart_path
    call load_texture
    mov [heart_texture], rax
    mov rdi, [renptr]
    mov rsi, empty_heart_path
    call load_texture
    mov [emptyheart_texture], rax
    add rsp, 8
    ret

init_mana_bar:
    sub rsp, 8
    mov rdi, [renptr]
    mov rsi, mana_path
    call load_texture
    mov [mana_texture], rax
    mov rdi, [renptr]
    mov rsi, empty_mana_path
    call load_texture
    mov [emptymana_texture], rax
    add rsp, 8
    ret

draw_mana_bar:
    ; 保存跨调用要保留的寄存器
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 24              ; 保持16字节对齐（SysV：call前rsp%16==0）[rsp]=space

    mov  r12, rdi            ; renderer
    mov  r13, rsi            ; heart_tex
    mov  r14d, edx           ; life_points
    mov  r15d, ecx           ; max_life_points
    mov  [rsp+8], r8

    ; -------- 计算 cur_hearts = life / 10 --------
    mov  eax, r14d
    xor  edx, edx
    mov  ecx, POINTS_PER_HEART
    div  ecx                 ; EAX=cur_hearts, EDX=rem
    mov  r14d, eax           ; r14d = cur_hearts


    ; -------- 计算 max_hearts = max_life / 10 --------
    mov  eax, r15d
    xor  edx, edx
    mov  ecx, POINTS_PER_HEART
    div  ecx                 ; EAX=max_hearts
    mov  r15d, eax           ; r15d = max_hearts
    mov [rsp+16], r15d ;max_heart

    ; 防止 max_hearts = 0 导致除0
    test r15d, r15d
    jnz  .calc_spacing
    mov  r15d, 1             ; 至少按1个心算
    mov [rsp+16], r15d ;max_heart


.calc_spacing:

    ; -------- spacing = LIFE_BAR_WIDTH / max_hearts --------
    mov  eax, MANA_BAR_WIDTH
    xor  edx, edx
    mov  ecx, r15d
    div  ecx                 ; EAX = spacing
    mov  r8d, eax            ; r8d = spacing

    ; spacing 下限保护，避免宽度太小导致 spacing=0
    cmp  r8d, MANA_MIN_SPACING
    jge  .loop_init
    mov  r8d, MANA_MIN_SPACING
    
.loop_init:
    mov [rsp], r8d ; 保存 spacing
    xor  r15d, r15d            ; i = 0

.loop:
    ; cur_x = LIFE_START_X + i * spacing
    mov r10d, [rsp]
    imul r10d, r15d
    add  r10d, MANA_START_X

    cmp  r15d, r14d
    jge  .draw_empty
    ; draw_texture(renderer, heart_tex, cur_x, start_y)
    mov  rdi, r12
    mov  rsi, r13
    mov  edx, r10d
    mov  ecx, MANA_START_Y
    call draw_texture
    jmp .enddraw
.draw_empty:
    ; draw_texture(renderer, heart_tex, cur_x, start_y)
    cmp  r15d, [rsp+16]
    jge  .done
    mov  rdi, r12
    mov  rsi, [rsp+8]
    mov  edx, r10d
    mov  ecx, MANA_START_Y
    call draw_texture
.enddraw:
    inc  r15d
    cmp  r15d, [rsp+16]           ; i < cur_hearts ?
    jl   .loop

.done:
    add  rsp, 24
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    ret

draw_life_bar:
    ; 保存跨调用要保留的寄存器
    push r12
    push r13
    push r14
    push r15
    sub  rsp, 24              ; 保持16字节对齐（SysV：call前rsp%16==0）[rsp]=space

    mov  r12, rdi            ; renderer
    mov  r13, rsi            ; heart_tex
    mov  r14d, edx           ; life_points
    mov  r15d, ecx           ; max_life_points
    mov  [rsp+8], r8

    ; -------- 计算 cur_hearts = life / 10 --------
    mov  eax, r14d
    xor  edx, edx
    mov  ecx, POINTS_PER_HEART
    div  ecx                 ; EAX=cur_hearts, EDX=rem
    mov  r14d, eax           ; r14d = cur_hearts


    ; -------- 计算 max_hearts = max_life / 10 --------
    mov  eax, r15d
    xor  edx, edx
    mov  ecx, POINTS_PER_HEART
    div  ecx                 ; EAX=max_hearts
    mov  r15d, eax           ; r15d = max_hearts
    mov [rsp+16], r15d ;max_heart

    ; 防止 max_hearts = 0 导致除0
    test r15d, r15d
    jnz  .calc_spacing
    mov  r15d, 1             ; 至少按1个心算
    mov [rsp+16], r15d ;max_heart


.calc_spacing:

    ; -------- spacing = LIFE_BAR_WIDTH / max_hearts --------
    mov  eax, LIFE_BAR_WIDTH
    xor  edx, edx
    mov  ecx, r15d
    div  ecx                 ; EAX = spacing
    mov  r8d, eax            ; r8d = spacing

    ; spacing 下限保护，避免宽度太小导致 spacing=0
    cmp  r8d, HEART_MIN_SPACING
    jge  .loop_init
    mov  r8d, HEART_MIN_SPACING
    
.loop_init:
    mov [rsp], r8d ; 保存 spacing
    xor  r15d, r15d            ; i = 0

.loop:
    ; cur_x = LIFE_START_X + i * spacing
    mov r10d, [rsp]
    imul r10d, r15d
    add  r10d, LIFE_START_X

    cmp  r15d, r14d
    jge  .draw_empty
    ; draw_texture(renderer, heart_tex, cur_x, start_y)
    mov  rdi, r12
    mov  rsi, r13
    mov  edx, r10d
    mov  ecx, LIFE_START_Y
    call draw_texture
    jmp .enddraw
.draw_empty:
    ; draw_texture(renderer, heart_tex, cur_x, start_y)
    cmp  r15d, [rsp+16]
    jge  .done
    mov  rdi, r12
    mov  rsi, [rsp+8]
    mov  edx, r10d
    mov  ecx, LIFE_START_Y
    call draw_texture
.enddraw:
    inc  r15d
    cmp  r15d, [rsp+16]           ; i < cur_hearts ?
    jl   .loop

.done:
    add  rsp, 24
    pop  r15
    pop  r14
    pop  r13
    pop  r12
    ret


show_life_info:
    sub rsp, 8
    call get_player_max_life
    mov ecx, eax
    call get_player_life
    mov edx, eax
    mov rdi, [renptr]
    mov rsi, [heart_texture]
    mov r8, [emptyheart_texture]
    call draw_life_bar
    add rsp, 8
    ret

show_mana_info:
    sub rsp, 8
    call get_player_max_mana
    mov ecx, eax
    call get_player_mana
    mov edx, eax
    mov rdi, [renptr]
    mov rsi, [mana_texture]
    mov r8, [emptymana_texture]
    call draw_mana_bar
    add rsp, 8
    ret

; ------------------------------------------------------------
; void ui_init_overlay()
; 加载UI贴图
; ------------------------------------------------------------
ui_init_overlay:
    sub rsp, 8

    mov rdi, [renptr]
    mov rsi, pause_btn_path
    call load_texture
    mov [tex_pause_btn], rax

    mov rdi, [renptr]
    mov rsi, resume_btn_path
    call load_texture
    mov [tex_resume_btn], rax

    mov rdi, [renptr]
    mov rsi, quit_btn_path
    call load_texture
    mov [tex_quit_btn], rax

    mov rdi, [renptr]
    mov rsi, pause_panel_path
    call load_texture
    mov [tex_pause_panel], rax

    mov rdi, [renptr]
    mov rsi, dead_panel_path
    call load_texture
    mov [tex_dead_panel], rax

    mov rdi, [renptr]
    mov rsi, next_level_panel_path
    call load_texture
    mov [tex_next_level_panel], rax


    mov dword [ui_state], 0

    add rsp, 8
    ret

ui_get_state:
    mov eax, dword [ui_state]
    ret

ui_set_state:
    ; edi = state
    mov dword [ui_state], edi
    ret

ui_draw_game_ui:
    sub rsp, 8
    mov eax, dword [ui_state]
    test eax, eax
    jnz .paused 
    call ui_draw_paused_bt
    jmp .done
    .paused:
    call ui_draw_pause_ui
    .done:
    add rsp, 8
    ret

global ui_draw_all

ui_draw_all:
    sub rsp, 8

    ; 运行中UI：例如你原来的暂停按钮
    call ui_draw_paused_bt
    call show_life_info
    call show_mana_info
    ; 覆盖层
    mov eax, dword [ui_state]
    test eax, eax
    jz .done
    call ui_draw_overlay   ; 里面根据 ui_state 分发

.done:
    add rsp, 8
    ret


ui_draw_overlay:
    sub rsp, 8
    mov eax, dword [ui_state]

    cmp eax, 1
    je .draw_pause
    cmp eax, 2
    je .draw_gameover
    cmp eax, 3
    je .draw_next
    jmp .done

.draw_pause:
    ; 面板（可选）
    mov rdi, [renptr]
    mov rsi, [tex_pause_panel]
    mov edx, PANEL_X
    mov ecx, PANEL_Y
    call draw_texture

    ; Resume
    mov rdi, [renptr]
    mov rsi, [tex_resume_btn]
    mov edx, RESUME_X
    mov ecx, RESUME_Y
    call draw_texture

    ; Quit（可选）
    mov rdi, [renptr]
    mov rsi, [tex_quit_btn]
    mov edx, QUIT_X
    mov ecx, QUIT_Y
    call draw_texture
    jmp .done

.draw_gameover:
    ; 面板（可选）
    mov rdi, [renptr]
    mov rsi, [tex_next_level_panel]
    mov edx, PANEL_X
    mov ecx, PANEL_Y
    call draw_texture

    ; Resume
    mov rdi, [renptr]
    mov rsi, [tex_resume_btn]
    mov edx, RESUME_X
    mov ecx, RESUME_Y
    call draw_texture

    ; Quit（可选）
    mov rdi, [renptr]
    mov rsi, [tex_quit_btn]
    mov edx, QUIT_X
    mov ecx, QUIT_Y
    call draw_texture
    jmp .done

.draw_next:
        ; 面板（可选）
    mov rdi, [renptr]
    mov rsi, [tex_dead_panel]
    mov edx, PANEL_X
    mov ecx, PANEL_Y
    call draw_texture

    ; Resume
    mov rdi, [renptr]
    mov rsi, [tex_resume_btn]
    mov edx, RESUME_X
    mov ecx, RESUME_Y
    call draw_texture

    ; Quit（可选）
    mov rdi, [renptr]
    mov rsi, [tex_quit_btn]
    mov edx, QUIT_X
    mov ecx, QUIT_Y
    call draw_texture
    jmp .done

.done:
    add rsp, 8
    ret



; ------------------------------------------------------------
; void ui_draw_game_ui()
; 运行中：绘制右上角“暂停按钮”
; ------------------------------------------------------------
ui_draw_paused_bt:
    sub rsp, 8
    mov eax, dword [ui_state]
    test eax, eax
    jnz .done          ; 暂停时不画这个（也可以画）

    mov rdi, [renptr]
    mov rsi, [tex_pause_btn]
    mov edx, PAUSE_BTN_X
    mov ecx, PAUSE_BTN_Y
    call draw_texture
.done:
    add rsp, 8
    ret

; ------------------------------------------------------------
; void ui_draw_pause_ui()
; 暂停中：绘制面板 + 继续/退出按钮
; ------------------------------------------------------------
ui_draw_pause_ui:
    sub rsp, 8
    mov eax, dword [ui_state]
    test eax, eax
    jz .done

    ; 面板（可选）
    mov rdi, [renptr]
    mov rsi, [tex_pause_panel]
    mov edx, PANEL_X
    mov ecx, PANEL_Y
    call draw_texture

    ; Resume
    mov rdi, [renptr]
    mov rsi, [tex_resume_btn]
    mov edx, RESUME_X
    mov ecx, RESUME_Y
    call draw_texture

    ; Quit（可选）
    mov rdi, [renptr]
    mov rsi, [tex_quit_btn]
    mov edx, QUIT_X
    mov ecx, QUIT_Y
    call draw_texture

.done:
    add rsp, 8
    ret



; ------------------------------------------------------------
; int ui_handle_mouse()
; 返回：
;   eax=0  无事发生
;   eax=1  点击bt1
;   eax=2  点击了bt2
; ------------------------------------------------------------
ui_handle_mouse:
    ; edi=mx, esi=my
    xor eax, eax

    mov rdi, debugmsg
    mov rsi, [mouse_x]
    call printf

    mov edi, [mouse_x]
    mov esi, [mouse_y]

    ; 没有点击
    cmp edi, -1
    je .ret0
    cmp esi, -1
    je .ret0

    mov ecx, dword [ui_state]
    cmp ecx, 0
    jg .paused_mode

; ========= 运行中：点右上角 Pause 按钮 =========
.running_mode:
    ; if (mx in [X,X+W) && my in [Y,Y+H))
    mov edx, edi
    sub edx, PAUSE_BTN_X
    cmp edx, 0
    jl .ret0
    cmp edx, PAUSE_BTN_W
    jge .ret0

    mov edx, esi
    sub edx, PAUSE_BTN_Y
    cmp edx, 0
    jl .ret0
    cmp edx, PAUSE_BTN_H
    jge .ret0

    mov dword [ui_state], 1
    mov eax, 0
    ret

; ========= 暂停中：点 Resume / Quit =========
.paused_mode:
    ; --- Resume ---
    mov edx, edi
    sub edx, RESUME_X
    cmp edx, 0
    jl .check_quit
    cmp edx, RESUME_W
    jge .check_quit

    mov edx, esi
    sub edx, RESUME_Y
    cmp edx, 0
    jl .check_quit
    cmp edx, RESUME_H
    jge .check_quit

    mov eax, 1
    ret

.check_quit:
    ; --- Quit（可选）---
    mov edx, edi
    sub edx, QUIT_X
    cmp edx, 0
    jl .ret0
    cmp edx, QUIT_W
    jge .ret0

    mov edx, esi
    sub edx, QUIT_Y
    cmp edx, 0
    jl .ret0
    cmp edx, QUIT_H
    jge .ret0

    mov eax, 2
    ret

.ret0:
    xor eax, eax
    ret