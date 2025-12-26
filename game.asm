section .data
    bktexture dq 0
    frame_start dd 0

    bk_path db "assets/bk.png", 0


section .text
    global run_game

    extern load_texture
    extern renptr

    extern draw_bkg
    extern draw_sprite_anim
    extern init_player
    extern player_step
    extern show_player

    extern SDL_Delay
    extern SDL_GetTicks
    extern SDL_SetRenderDrawColor
    extern SDL_RenderClear
    extern SDL_RenderFillRect
    extern SDL_RenderPresent




run_game:
    push rbp
    mov rbp, rsp
.init_game:
    call init_player
        ; 加载背景
    mov rdi, [renptr]
    mov rsi, bk_path
    call load_texture
    mov [bktexture], rax

.loop:
    call SDL_GetTicks
    mov dword [frame_start], eax   ;帧始时间

    ; 清屏（黑）
    mov rdi, [renptr]
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    mov r8d, 255
    call SDL_SetRenderDrawColor

    mov rdi, [renptr]
    call SDL_RenderClear

    ; 画背景
    mov rdi, [renptr]
    mov rsi, [bktexture]
    call draw_bkg
    call player_step
    cmp rax, 0
    jnz .exit

.present:
    mov rdi, [renptr]
    call SDL_RenderPresent
    ;控制帧率
    call SDL_GetTicks
    sub eax, dword [frame_start]   ; elapsed = now - start
    mov ecx, 16                    ; target = 16ms (近似60fps)
    cmp eax, ecx
    jge .nosleep
    sub ecx, eax                   ; sleep = target - elapsed
    mov edi, ecx
    call SDL_Delay
.nosleep:
    jmp .loop  
.exit:
    pop rbp
    ret
    
