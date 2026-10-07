from PIL import Image
import os

im = Image.open('shots/yabai_raw.png').convert('RGB')
print('元画像:', im.size)


def mosaic(img, box, f=16):
    x0, y0, x1, y1 = box
    x0 = max(0, x0); y0 = max(0, y0)
    x1 = min(img.width, x1); y1 = min(img.height, y1)
    r = img.crop((x0, y0, x1, y1))
    small = r.resize((max(1, (x1 - x0) // f), max(1, (y1 - y0) // f)), Image.BILINEAR)
    img.paste(small.resize((x1 - x0, y1 - y0), Image.NEAREST), (x0, y0))


# 当たり3マスは文字が読めないよう粗く（ブロック大）、メッセージ行は細かく伏せる
mosaic(im, (69, 885, 681, 1305), 64)
mosaic(im, (225, 1806, 945, 1899), 22)

im = im.resize((im.width // 2, im.height // 2), Image.LANCZOS)
im.save('docs/screenshot-yabai.png', optimize=True)
print('docs/screenshot-yabai.png:', im.size, os.path.getsize('docs/screenshot-yabai.png') // 1024, 'KB')
