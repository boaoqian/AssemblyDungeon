; ============================================
; sdl_helper.asm - 保存这部分到 sdl_helper.asm
; ============================================

section .data
    sdl_window dq 0
    sdl_renderer dq 0

section .text
    global sdl_helper_init
    global sdl_helper_quit
    global sdl_helper_get_renderer
    global sdl_helper_get_window
    
    extern SDL_Init
    extern SDL_CreateWindow
    extern SDL_CreateRenderer
    extern SDL_DestroyRenderer
    extern SDL_DestroyWindow
    extern SDL_Quit

sdl_helper_init:
    push rbp
    mov rbp, rsp
    sub rsp, 32            ; 对齐栈并预留空间
    
    mov [rbp-8], rdi       ; 保存标题
    mov [rbp-12], esi      ; 保存宽度
    mov [rbp-16], edx      ; 保存高度
    
    ; SDL_Init(SDL_INIT_VIDEO)
    mov edi, 0x20
    call SDL_Init
    test eax, eax
    js .fail
    
    ; SDL_CreateWindow
    mov rdi, [rbp-8]       ; 标题
    mov esi, 100           ; x
    mov edx, 100           ; y
    mov ecx, [rbp-12]      ; 宽度
    mov r8d, [rbp-16]      ; 高度
    xor r9d, r9d           ; flags
    call SDL_CreateWindow
    test rax, rax
    jz .fail
    mov [sdl_window], rax
    
    ; SDL_CreateRenderer
    mov rdi, rax
    mov esi, -1
    mov edx, 2
    call SDL_CreateRenderer
    test rax, rax
    jz .cleanup_window
    mov [sdl_renderer], rax
    
    xor eax, eax           ; 成功返回 0
    jmp .done
    
.cleanup_window:
    mov rdi, [sdl_window]
    call SDL_DestroyWindow
    
.fail:
    mov eax, -1            ; 失败返回 -1
    
.done:
    leave
    ret

sdl_helper_quit:
    push rbp
    mov rbp, rsp
    
    ; 销毁渲染器
    mov rdi, [sdl_renderer]
    test rdi, rdi
    jz .skip_renderer
    call SDL_DestroyRenderer
    mov qword [sdl_renderer], 0
    
.skip_renderer:
    ; 销毁窗口
    mov rdi, [sdl_window]
    test rdi, rdi
    jz .skip_window
    call SDL_DestroyWindow
    mov qword [sdl_window], 0
    
.skip_window:
    ; 退出 SDL
    call SDL_Quit
    
    pop rbp
    ret

sdl_helper_get_renderer:
    mov rax, [sdl_renderer]
    ret

sdl_helper_get_window:
    mov rax, [sdl_window]
    ret

