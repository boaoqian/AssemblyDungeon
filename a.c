#include <stdio.h>
#include <SDL2/SDL_image.h>


int main(int argc, char* argv[]) {
    int flags = IMG_INIT_PNG | IMG_INIT_JPG;
    if ((IMG_Init(flags) & flags) != flags) {
        printf("IMG_Init Error: %s\n", IMG_GetError());
        return 1;
    }
    SDL_QueryTexture

    IMG_Quit();
    return 0;
}
