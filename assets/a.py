# python3
from PIL import Image
import sys
import os

def resize_and_center_crop(input_path, output_path, scale=4):
    """
    将图片放大 scale 倍，然后从中心裁剪出原始尺寸大小的图片。
    
    参数:
        input_path (str): 输入图片路径
        output_path (str): 输出图片路径
        scale (float): 放大倍数，默认为 2
    """
    with Image.open(input_path) as img:
        original_width, original_height = img.size
        # corp = img.crop((0,0,64*6,original_height))
        # new_resized = img.resize((int(64*6 * scale), int(original_height * scale)), Image.Resampling.NEAREST)
        # new_resized = img.resize((original_width, 82), Image.Resampling.NEAREST)
        new_resized = img.resize((int(original_width * scale), int(original_height * scale)), Image.Resampling.NEAREST)







        # 保存结果
        new_resized.save(output_path)
        print(f"处理完成：{input_path} -> {output_path}")

if __name__ == "__main__":

    input_file = sys.argv[1]

    if not os.path.exists(input_file):
        print(f"错误：输入文件 {input_file} 不存在。")
        sys.exit(1)

    resize_and_center_crop(input_file, input_file+"2x.png", scale=2)