# SDL2 汇编项目 Makefile

# 编译器和工具
NASM = nasm
CC = gcc
RM = rm -f

# 编译选项
NASM_FLAGS = -f elf64
LDFLAGS = -lSDL2 -lSDL2_image -lc -no-pie

# 目标文件
TARGET = Dungeon
OBJS = helper.o main.o input.o vender.o player.o game.o

# 默认目标
all: $(TARGET)

# 链接生成可执行文件
$(TARGET): $(OBJS)
	$(CC) $(OBJS) -o $(TARGET) $(LDFLAGS)
	@echo "编译完成: $(TARGET)"

# 编译汇编文件
%.o: %.asm
	$(NASM) $(NASM_FLAGS) $< -o $@

# 清理编译产物
clean:
	$(RM) $(OBJS) $(TARGET)
	@echo "清理完成"

# 运行程序
run: $(TARGET)
	./$(TARGET)

# 重新编译
rebuild: clean all

# 声明伪目标
.PHONY: all clean run rebuild