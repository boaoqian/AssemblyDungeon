; ============================================
; main.asm - SDL2 Square (WASD hold to move)
; ============================================

default rel
section .data
    win_w equ 1080
    win_h equ 720

    renptr dq 0
    bktexture dq 0

    debugmsg db "DEBUG: %d %d", 10, 0
    bk_path db "assets/bk.png", 0
    title db "SDL2 Square - WASD to move, ESC to quit", 0

section .bss
    global event_buffer
    event_buffer: resb 56

section .text
    global main
    global win_h
    global win_w
    global renptr

    extern sdl_helper_init
    extern sdl_helper_quit
    extern sdl_helper_get_renderer
    extern input_poll
    extern init_img
    extern load_texture
    extern draw_texture
    extern draw_bkg
    extern draw_sprite_anim
    extern init_player
    extern player_step
    extern show_player

    extern printf

    extern SDL_SetRenderDrawColor
    extern SDL_RenderClear
    extern SDL_RenderFillRect
    extern SDL_RenderPresent
    extern SDL_PollEvent
    extern SDL_Delay


main:
    push rbp
    mov rbp, rsp
    sub rsp, 16               ; 16字节对齐

    ; 初始化 SDL
    lea rdi, [title]
    mov esi, win_w
    mov edx, win_h
    call sdl_helper_init
    test eax, eax
    jnz .exit

    ; 获取渲染器
    call sdl_helper_get_renderer
    mov [renptr], rax           ; renderer (qword)
    ;初始化img
    call init_img
    ;初始化
    call init_player

    ; 加载背景
    mov rdi, [renptr]
    mov rsi, bk_path
    call load_texture
    mov [bktexture], rax

; -------------------------
; 游戏主循环
; -------------------------
.game_loop:
    ; 清屏（黑）
    mov rdi, [renptr]
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    mov r8d, 255
    call SDL_SetRenderDrawColor

    mov rdi, [renptr]
    call SDL_RenderClear

    ; 方块颜色（红）
    ; mov rdi, [renptr]
    ; mov esi, 255
    ; xor edx, edx
    ; xor ecx, ecx
    ; mov r8d, 255
    ; call SDL_SetRenderDrawColor

    ; ; SDL_Rect 放在 [rbp-40 .. rbp-24]
    ; mov eax, [rbp-16]
    ; mov [rbp-40], eax               ; rect.x
    ; mov eax, [rbp-12]
    ; mov [rbp-36], eax               ; rect.y
    ; mov dword [rbp-32], square_size ; rect.w
    ; mov dword [rbp-28], square_size ; rect.h

    ; ; 画方块
    ; mov rdi, [renptr]
    ; lea rsi, [rbp-40]
    ; call SDL_RenderFillRect

    ;;画背景
    mov rdi, [renptr]
    mov rsi, [bktexture]
    call draw_bkg
    ; ;; 画图片
    ; mov rdi, [renptr]
    ; mov rsi, [rsp+0]
    ; mov edx, [rbp-16]
    ; mov ecx, [rbp-12]
    ; call draw_texture
    ; call player_step
    call show_player

    .present:
    mov rdi, [renptr]
    call SDL_RenderPresent

    ; 60 FPS 左右
    mov edi, 16
    call SDL_Delay

    jmp .game_loop

.exit:
    call sdl_helper_quit
    xor eax, eax
    leave
    ret
