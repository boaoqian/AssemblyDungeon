; ============================================
; main.asm - SDL2 Square (WASD hold to move)
; ============================================

default rel
section .data
    win_w equ 1080
    win_h equ 720

    renptr dq 0

    debugmsg db "DEBUG: %d %d", 10, 0
    bk_path db "assets/main.png", 0
    title db "Dungeon", 0
    key_state dd 0
    mouse_x dd 0
    mouse_y dd 0
    is_esc db 0
    bktexture dq 0


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
    extern load_texture
    extern draw_bkg
    extern SDL_Delay
    extern SDL_GetTicks
    extern SDL_SetRenderDrawColor
    extern SDL_RenderClear
    extern SDL_RenderFillRect
    extern SDL_RenderPresent

    extern printf

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
    mov rdi, [renptr]
    mov rsi, bk_path
    call load_texture
    mov [bktexture], rax
    
.loop:
    lea rdi, event_buffer
    lea rsi, [key_state] ;key bitmask
    lea rdx, [mouse_x]; mouse_x
    lea rcx, [mouse_y]; mouse_y
    call input_poll
    mov byte [is_esc], al
    test al, al
    jnz .exit
    cmp dword [mouse_x], 0
    jge ._game
    ; 清屏（黑）total_limit
    mov rdi, [renptr]
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    mov r8d, 255
    call SDL_SetRenderDrawColor

    mov rdi, [renptr]
    call SDL_RenderClear
    ; 绘制背景
    ;renderer=rdi, texture=rsi
    mov rdi, [renptr]
    mov rsi, [bktexture]
    call draw_bkg
    mov rdi, [renptr]
    call SDL_RenderPresent    
    mov rdi, 10
    call SDL_Delay
    jmp .loop

._game:
    ;加入游戏
    call run_game
    jmp .loop

.exit:
    call sdl_helper_quit
    xor eax, eax
    leave
    ret
