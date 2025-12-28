# 地牢冒险（Dungeon Adventure）- NASM x64 + SDL2

一个使用 **NASM（x86_64 汇编）** 编写的地牢冒险小游戏，基于 **SDL2** 与 **SDL2_image** 进行窗口、渲染与资源加载。

---

## 运行环境

已验证环境（开发/测试）：

- OS: **Ubuntu 24.04.3 LTS x86_64**
- 架构：**x64（x86_64）**
- GCC: **13.3.0 (Ubuntu 13.3.0-6ubuntu2~24.04)**
- NASM: **3.01** (compiled on Nov 14 2025)
- 链接参数：`-lSDL2 -lSDL2_image`

---

## 功能简介

- 角色移动 / 基础碰撞

- 地牢地图（格子/房间/走廊）

- 敌人或陷阱（基础 AI）

- 资源加载（PNG 等，依赖 SDL2_image）

- 键盘输入控制、简单 UI

  
  
![截图 2025-12-28 19-10-06](./assets/截图 2025-12-28 19-10-06.png)


---

## 依赖安装

### 1) 安装编译工具与 NASM

```bash
sudo apt update
sudo apt install -y build-essential nasm pkg-config
~~~

### 2) 安装 SDL2 与 SDL2_image 开发库

```bash
sudo apt install -y libsdl2-dev libsdl2-image-dev
```

> 如果你运行时缺少动态库，一般安装对应的运行库即可；但开发编译推荐直接安装 `*-dev`。

------

## 编译与运行

### 使用 Makefile（推荐）

```bash
make
./build/dungeon
```

### 手动编译（你自己看着编译）

> 下面是常见做法：先用 `nasm` 产出 ELF64 目标文件，再用 `gcc` 负责链接 SDL2。

```bash
mkdir -p build

nasm -f elf64 -g -F dwarf -o build/main.o src/main.asm

gcc -o build/dungeon build/main.o \
  $(pkg-config --cflags --libs sdl2 SDL2_image)
```

如果你希望显式写库参数，也可以：

```bash
gcc -o build/dungeon build/main.o -lSDL2 -lSDL2_image
```

------

## 运行注意事项

- 运行时确保资源路径正确（例如从项目根目录运行）：

  ```bash
  目录下要有assets
  ```

------

## 开发说明

- 架构：x86_64 System V ABI（Linux）
- 渲染：SDL2 Renderer / Texture
- 图片：SDL2_image（PNG/JPG 等）

------

## License

**The MIT License**

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY  CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,  TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE  SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
