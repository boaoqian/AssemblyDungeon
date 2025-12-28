; =========================
; map.asm  (NASM x86_64)
; =========================

section .data
    bk_path         db "assets/bk.png", 0
    bktexture       dq 0

    ; 随机数（xorshift32）
    rng_state       dd 2463534242

    ; 波次与生成控制
    total_limit     dd 0        ; 总共允许生成的怪物数量上限
    total_spawned   dd 0        ; 已经生成过的怪物总数
    wave_to_spawn   dd 0        ; 当前波：还需要生成多少只
    clear_flag      db 0        ; 1=通关
    next_wave_tick  dd 0        ; 到这个时间(ms)才允许开下一波
    wave_delay_ms   dd 1000     ; 1秒延迟



    ; 屏幕范围（按你项目实际分辨率调）
    x_min           dd 80
    x_max           dd 920
    y_min           dd 120
    y_max           dd 640

section .text
    global map_init
    global map_step
    global map_get_bktexture
    global map_get_clear_flag
    global rand_u32

    extern load_texture
    extern SDL_GetTicks

    extern set_mob
    extern gen_mob
    extern clear_mobs
    extern get_active_mobs_num

    extern renptr

; -------------------------
; u32 rand_u32()
; eax <- random
; -------------------------
rand_u32:
    mov eax, dword [rng_state]
    mov ecx, eax
    shl ecx, 13
    xor eax, ecx
    mov ecx, eax
    shr ecx, 17
    xor eax, ecx
    mov ecx, eax
    shl ecx, 5
    xor eax, ecx
    mov dword [rng_state], eax
    ret

; -------------------------
; i32 rand_range(min, max)  (inclusive)
; in: edi=min, esi=max
; out: eax
; -------------------------
rand_range:
    sub rsp, 8

    ; if max <= min => return min
    mov eax, esi
    cmp eax, edi
    jg .ok
    mov eax, edi

    add rsp, 8
    ret
.ok:
    add rsp, 8
    push rbx
    mov ebx, esi
    sub ebx, edi        ; ebx = (max-min)
    inc ebx             ; ebx = range = (max-min+1)

    call rand_u32
    xor edx, edx
    div ebx             ; eax/ebx => quotient eax, remainder edx
    mov eax, edx
    add eax, edi        ; + min
    pop rbx
    ret

; -------------------------
; void map_start_next_wave()
; 规则：每波随机 3~8，只要不超过剩余额度
; 若剩余额度为0 => clear_flag=1
; -------------------------
map_start_next_wave:
    sub rsp, 8

    ; remaining = total_limit - total_spawned
    mov eax, dword [total_limit]
    sub eax, dword [total_spawned]
    cmp eax, 0
    jg .has_remaining
    mov byte [clear_flag], 1
    mov dword [wave_to_spawn], 0
    add rsp, 8
    ret

.has_remaining:
    ; wave_size = rand_range(3, 8)
    mov edi, 2
    mov esi, 5
    call rand_range
    ; cap to remaining
    mov ecx, eax                    ; ecx = wave_size
    mov eax, dword [total_limit]
    sub eax, dword [total_spawned]  ; eax = remaining
    cmp ecx, eax
    jle .use_wave
    mov ecx, eax
.use_wave:
    mov dword [wave_to_spawn], ecx

    ; 给这波设置一个怪物模板（你也可以改成随机模板）
    ; set_mob(a,b) 参数按你项目定义来，这里沿用你 game.asm 里出现的组合:contentReference[oaicite:1]{index=1}
    ; 让波次奇偶切换两种参数，效果上更像“不同怪”
    ; wave_to_spawn 不适合当 wave_id，所以这里用 total_spawned 的奇偶做个简单切换
    mov eax, dword [total_spawned]
    test eax, 1
    jz .tpl0
.tpl1:
    mov rdi, 10
    mov rsi, 8
    call set_mob
    jmp .retf
.tpl0:
    mov rdi, 5
    mov rsi, 12
    call set_mob

.retf:
    add rsp, 8
    ret

; -------------------------
; void map_init(total_limit)
; in: rdi = renderer, esi = 总怪物上限
; -------------------------
map_init:
    sub rsp, 8
    ; 保存总数上限
    mov dword [total_limit], edi
    mov dword [total_spawned], 0
    mov dword [wave_to_spawn], 0
    mov byte  [clear_flag], 0
    call clear_mobs
    ; seed rng = SDL_GetTicks()
    call SDL_GetTicks
    mov dword [rng_state], eax

    ; load background texture
    ; load_texture(renderer, path) -> rax = texture
    mov rdi, [renptr]
    mov rsi, bk_path
    call load_texture
    mov [bktexture], rax

    ; start first wave
    call map_start_next_wave
    add rsp, 8
    ret

; -------------------------
; void map_step()
; 每帧调用：决定是否生成一只怪、是否开下一波、是否通关
; -------------------------
map_step:
    sub rsp, 8

    cmp byte [clear_flag], 1
    je .ret

    call get_active_mobs_num
    mov ecx, eax

    ; 场上没怪 && 本波刷完 => 进入“等待1秒再开下一波”
    cmp ecx, 0
    jne .maybe_spawn
    cmp dword [wave_to_spawn], 0
    jne .maybe_spawn

    ; 如果还没设置 next_wave_tick，就设置为 now+1000
    call SDL_GetTicks
    mov edx, dword [next_wave_tick]
    cmp edx, 0
    jne .check_wave_time

    mov edx, eax
    add edx, dword [wave_delay_ms]
    mov dword [next_wave_tick], edx
    jmp .ret

.check_wave_time:
    ; now >= next_wave_tick ? 开下一波 : 继续等
    cmp eax, edx
    jb .ret

    mov dword [next_wave_tick], 0
    call map_start_next_wave
    jmp .ret

.maybe_spawn:
    ; 只要场上还有怪 或 本波还在刷，就不应该保留“等待下一波”的计时
    mov dword [next_wave_tick], 0

    mov eax, dword [wave_to_spawn]
    cmp eax, 0
    jle .ret

    ; 随机 x
    mov edi, dword [x_min]
    mov esi, dword [x_max]
    call rand_range
    mov edi, eax

    ; 随机 y
    mov edi, dword [y_min]
    mov esi, dword [y_max]
    call rand_range
    mov esi, eax

    call gen_mob
    dec dword [wave_to_spawn]
    inc dword [total_spawned]

.ret:
    add rsp, 8
    ret


; -------------------------
; texture getter
; -------------------------
map_get_bktexture:
    mov rax, [bktexture]
    ret

map_get_clear_flag:
    movzx eax, byte [clear_flag]
    ret
