section .data
    bktexture dq 0
    frame_start dd 0

    bk_path db "assets/bk.png", 0

    debugmsg db "mana: %d", 10, 0
    err_msg db "hit", 10, 0
    key_state dd 0
    mouse_x dd 0
    mouse_y dd 0
    is_esc db 0
    max_mobs dq 5


section .text
    global run_game
    global key_state
    global mouse_x
    global mouse_y
    global is_esc

    extern load_texture
    extern renptr
    extern event_buffer
    extern input_poll

    extern draw_bkg
    extern draw_sprite_anim
    extern init_player
    extern player_step
    extern bullets_step_all
    extern get_active_bullets_num
    extern get_player_life
    extern ui_draw_all
    extern ui_get_state
    extern get_player_mana
    extern ui_set_state
    extern ui_get_state

    extern mobs_step_all
    extern get_active_mobs_num
    extern check_player_mob_collisions
    extern check_mob_bullet_collisions
    extern check_player_drop_collisions
    extern ui_init
    extern ui_handle_mouse
    extern map_init
    extern map_step
    extern map_get_bktexture
    extern map_get_clear_flag

    extern gen_drop
    extern drops_step_all


    extern SDL_Delay
    extern SDL_GetTicks
    extern SDL_SetRenderDrawColor
    extern SDL_RenderClear
    extern SDL_RenderFillRect
    extern SDL_RenderPresent
    extern printf

run_game:
    push rbp
    mov rbp, rsp
.init_game:
    mov [max_mobs], 5
    call init_player
    call ui_init
    mov rdi, [max_mobs]          ; 例：本关总共最多生成60只怪（你想要多少改这里）
    call map_init

    ;test
    ; mov rdi, 200
    ; mov rsi, 200
    ; call gen_drop
    
.loop:
    call SDL_GetTicks
    mov dword [frame_start], eax   ;帧始时间

    ;event loop
    lea rdi, event_buffer
    lea rsi, [key_state] ;key bitmask
    lea rdx, [mouse_x]; mouse_x
    lea rcx, [mouse_y]; mouse_y
    call input_poll
    mov byte [is_esc], al

    ; 清屏（黑）total_limit
    mov rdi, [renptr]
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    mov r8d, 255
    call SDL_SetRenderDrawColor

    mov rdi, [renptr]
    call SDL_RenderClear

    ; 画背景
    call map_get_bktexture
    mov rsi, rax
    mov rdi, [renptr]
    call draw_bkg
    call ui_get_state
    test eax, eax
    jnz .present
    
;更新
    call map_get_clear_flag
    cmp eax, 1
    je .next_level

    call drops_step_all
    call map_step
    call player_step
    cmp rax, 0
    jnz .exit
    call get_active_bullets_num
    cmp rax, 0
    jz .no_bullet
    call bullets_step_all
    .no_bullet:
    call get_active_mobs_num
    cmp rax, 0
    jz .present
    call mobs_step_all

.present:
    call ui_handle_mouse
    cmp eax, 2
    je .exit
    cmp eax, 1
    je .bt1
.after_bt1:
    call ui_draw_all

    ;检查玩家和怪物的碰撞
    call check_player_mob_collisions
    call check_mob_bullet_collisions
    call check_player_drop_collisions
    ;更新画面
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
.next_level:
    mov rdi, 2
    call ui_set_state 
    jmp .present

.bt1:
    call ui_get_state
    cmp eax, 1
    jne .sp
    mov rdi, 0
    call ui_set_state
    jmp .after_bt1
    .sp:
    cmp eax, 2
    je .init_new_level
    mov [max_mobs], 5
    call init_player
    call ui_init
    mov rdi, [max_mobs]        ; 例：本关总共最多生成60只怪（你想要多少改这里）
    call map_init
    jmp .nosleep
    
    .init_new_level:
    add qword [max_mobs], 5
    call ui_init
    mov rdi, [max_mobs]          ; 例：本关总共最多生成60只怪（你想要多少改这里）
    call map_init
    jmp .nosleep

