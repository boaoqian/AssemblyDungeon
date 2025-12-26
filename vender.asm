section .text
global init_img
global load_texture
global draw_texture
global draw_bkg
global draw_sprite_anim

extern SDL_QueryTexture
extern SDL_RenderCopy
extern IMG_Init
extern IMG_LoadTexture
extern printf

%define IMG_INIT_PNG 0x00000002

init_img:
    sub rsp, 8                 ; 让接下来的 call 前 rsp 16B 对齐
    mov edi, IMG_INIT_PNG
    call IMG_Init
    and eax, IMG_INIT_PNG
    jne .ok

    lea rdi, [ err_msg]
    xor eax, eax               ; variadic: AL=0
    call printf
    mov eax, -1

.ok:
    add rsp, 8
    ret


; SDL_Texture* load_texture(SDL_Renderer* rdi, char* rsi)
load_texture:
    sub rsp, 8
    call IMG_LoadTexture
    test rax, rax
    jnz .ok

    lea rdi, [load_fail]
    xor eax, eax               ; variadic: AL=0
    call printf
    xor rax, rax               ; return NULL

.ok:
    add rsp, 8
    ret


; rdi = SDL_Texture*
get_texture_size:
    sub rsp, 8
    xor esi, esi               ; format = NULL  (rsi!)
    xor edx, edx               ; access = NULL  (rdx)
    lea rcx, [ rect_tmp+8]  ; &w (rcx)
    lea r8,  [ rect_tmp+12] ; &h (r8)
    call SDL_QueryTexture
    add rsp, 8
    ret


; draw_texture(renderer=rdi, texture=rsi, x=rdx, y=rcx)
draw_texture:
    sub rsp, 8                 ; 对齐用（因为下面会 push 两次）

    mov dword [ rect_tmp+0], edx   ; x
    mov dword [ rect_tmp+4], ecx   ; y

    push rdi                    ; save renderer
    push rsi                    ; save texture
    ; 现在对齐仍然正确（sub 8 + push16）

    mov rdi, rsi                ; rdi=texture
    call get_texture_size

    pop rsi                     ; texture
    pop rdi                     ; renderer

    xor edx, edx                ; srcRect = NULL
    lea rcx, [rect_tmp]     ; dstRect = &rect_tmp
    call SDL_RenderCopy

    add rsp, 8
    ret

; 绘制背景
;renderer=rdi, texture=rsi
draw_bkg:
    sub rsp, 8
    xor rdx, rdx
    xor ecx, ecx
    call draw_texture
    add rsp, 8
    ret


; ------------------------------------------------------------
; draw_sprite_anim(renderer=rdi, texture=rsi, x=rdx, y=rcx,
;                  frame_w=r8d, frame_h=r9d,
;                  frame_index (7th arg) on stack,
;                  columns     (8th arg) on stack)
;
; SDL_RenderCopy(renderer, texture, &srcRect, &dstRect)
; srcRect:
;   col = frame_index % columns
;   row = frame_index / columns
;   x = col * frame_w
;   y = row * frame_h
;   w = frame_w
;   h = frame_h
; dstRect:
;   x = x, y = y, w = frame_w, h = frame_h
; ------------------------------------------------------------
draw_sprite_anim:
    sub rsp, 8                  ; 对齐：SysV 进入时 RSP%16=8，sub 8 -> 0 对齐

    ; --- dstRect = {x,y,frame_w,frame_h}
    mov dword [rect_tmp+0], edx     ; dst.x = x
    mov dword [rect_tmp+4], ecx     ; dst.y = y
    mov dword [rect_tmp+8], r8d     ; dst.w = frame_w
    mov dword [rect_tmp+12], r9d    ; dst.h = frame_h

    ; --- 取栈上传入的 frame_index 和 columns
    mov eax, dword [rsp+16]     ; frame_index（sub rsp,8 后：原 [rsp+8] -> [rsp+16]）
    mov ecx, dword [rsp+24]     ; columns     （sub rsp,8 后：原 [rsp+16] -> [rsp+24]）

    ; --- 计算 row/col:  EAX=quot(row), EDX=rem(col)
    xor edx, edx
    div ecx                     ; unsigned: (EDX:EAX)/ECX

    ; --- src.x = col * frame_w
    imul edx, r8d               ; EDX = col * frame_w
    mov dword [ rect_src_tmp+0], edx

    ; --- src.y = row * frame_h
    imul eax, r9d               ; EAX = row * frame_h
    mov dword [ rect_src_tmp+4], eax

    ; --- src.w/h
    mov dword [ rect_src_tmp+8],  r8d
    mov dword [ rect_src_tmp+12], r9d

    ; --- 调 SDL_RenderCopy(renderer, texture, &src, &dst)
    lea rdx, [rect_src_tmp] ; srcRect = &rect_src_tmp
    lea rcx, [rect_tmp]     ; dstRect = &rect_tmp
    call SDL_RenderCopy

    add rsp, 8
    ret



section .data
err_msg   db "IMG_Init failed", 10, 0
load_fail db "IMG_LoadTexture failed", 10, 0


section .bss
align 16

rect_tmp:       resd 4          ; dst SDL_Rect: x,y,w,h (int32)
rect_src_tmp:   resd 4          ; src SDL_Rect: x,y,w,h (int32)