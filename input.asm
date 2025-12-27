default rel
section .text
global input_poll
extern SDL_PollEvent

%define KEY_W 1
%define KEY_S 2
%define KEY_A 4
%define KEY_D 8
%define KEY_ENTER 16

%define SDL_QUIT            0x100
%define SDL_KEYDOWN         0x300
%define SDL_KEYUP           0x301
%define SDL_MOUSEMOTION     0x400
%define SDL_MOUSEBUTTONDOWN 0x401

%define SC_ESC 41
%define SC_W   26
%define SC_S   22
%define SC_A   4
%define SC_D   7
%define SC_ENTER 40


%define EV_TYPE_OFF        0
%define EV_SCANCODE_OFF    16
%define EV_MOTION_X_OFF    20
%define EV_MOTION_Y_OFF    24
%define EV_BUTTON_CLICK    18
%define EV_MOTION_STATE    16

; int input_poll(SDL_Event* ev, uint32_t* keys, int* mx, int* my)
; rdi=ev rsi=keys rdx=mx rcx=my
input_poll:
    push rbp
    mov rbp, rsp

    ; 保存参数指针（callee-saved）
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi   ; ev*
    mov r13, rsi   ; keys*
    mov r14, rdx   ; mx*
    mov r15, rcx   ; my*

    xor eax, eax   ; return 0 by default
    ; mov dword [r13], 0
    mov dword [r15], -1
    mov dword [r14], -1

.poll:
    mov rdi, r12           ; SDL_PollEvent(ev)
    call SDL_PollEvent
    test eax, eax
    jz .done

    mov eax, dword [r12 + EV_TYPE_OFF]

    cmp eax, SDL_QUIT
    je .quit

    cmp eax, SDL_KEYDOWN
    je .on_keydown
    cmp eax, SDL_KEYUP
    je .on_keyup

    cmp eax, SDL_MOUSEMOTION
    je .on_mouse
    cmp eax, SDL_MOUSEBUTTONDOWN
    je .on_mousepress
    jmp .poll

.quit:
    mov eax, 1
    jmp .done

.on_keydown:
    mov eax, dword [r12 + EV_SCANCODE_OFF]
    cmp eax, SC_ESC
    je .quit

    mov r8d, dword [r13]
    cmp eax, SC_W
    jne .kd_s
    or r8d, KEY_W
    mov dword [r13], r8d
    jmp .poll
.kd_s:
    cmp eax, SC_S
    jne .kd_a
    or r8d, KEY_S
    mov dword [r13], r8d
    jmp .poll
.kd_a:
    cmp eax, SC_A
    jne .kd_d
    or r8d, KEY_A
    mov dword [r13], r8d
    jmp .poll
.kd_d:
    cmp eax, SC_D
    jne .poll
    or r8d, KEY_D
    mov dword [r13], r8d
    jmp .poll

.on_keyup:
    mov eax, dword [r12 + EV_SCANCODE_OFF]
    mov r8d, dword [r13]
    cmp eax, SC_W
    jne .ku_s
    and r8d, ~KEY_W
    mov dword [r13], r8d
    jmp .poll
.ku_s:
    cmp eax, SC_S
    jne .ku_a
    and r8d, ~KEY_S
    mov dword [r13], r8d
    jmp .poll
.ku_a:
    cmp eax, SC_A
    jne .ku_d
    and r8d, ~KEY_A
    mov dword [r13], r8d
    jmp .poll
.ku_d:
    cmp eax, SC_D
    jne .poll
    and r8d, ~KEY_D
    mov dword [r13], r8d
    jmp .poll
; .ku_enter:
;     cmp eax, SC_ENTER
;     jne .poll
;     and r8d, ~KEY_D
;     mov dword [r13], r8d
;     jmp .poll

.on_mouse:
    xor eax, eax
    mov al, byte [r12 + EV_BUTTON_CLICK]
    cmp al, 1
    je .on_mousepress
    mov al, byte [r12 + EV_MOTION_STATE]
    cmp al, 1
    je .on_mousepress
    mov dword [r14], -1
    mov dword [r15], -1
    jmp .poll

.on_mousepress:
    xor eax, eax
    mov eax, dword [r12 + EV_MOTION_X_OFF]
    mov dword [r14], eax
    mov eax, dword [r12 + EV_MOTION_Y_OFF]
    mov dword [r15], eax
    jmp .poll


.done:
    pop r15
    pop r14
    pop r13
    pop r12
    leave
    ret
