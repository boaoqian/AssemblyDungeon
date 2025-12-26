; ============================================
; main.asm - SDL2 Square (WASD hold to move)
; ============================================

default rel
section .data
    win_w equ 1080
    win_h equ 720

    renptr dq 0

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
    extern run_game

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

    ;加入游戏
    call run_game

.exit:
    call sdl_helper_quit
    xor eax, eax
    leave
    ret
