#!/usr/bin/env python3
"""ちんすこうメーカー のアイコンを生成（レインボー縁 + ちんすこう）"""
from PIL import Image, ImageDraw
import math, os

SIZES = {'mdpi':48,'hdpi':72,'xhdpi':96,'xxhdpi':144,'xxxhdpi':192}
SS = 4                      # スーパーサンプリング倍率
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'app', 'res')

def conic(t):
    """t: 0..1 -> RGB (レインボー環)"""
    stops = [(0,(255,0,77)),(.16,(255,138,0)),(.33,(255,230,0)),(.5,(37,255,100)),
             (.66,(0,229,255)),(.83,(77,91,255)),(1,(196,0,255))]
    for i in range(len(stops)-1):
        a, ca = stops[i]; b, cb = stops[i+1]
        if a <= t <= b:
            k = (t-a)/(b-a)
            return tuple(int(ca[j]+(cb[j]-ca[j])*k) for j in range(3))
    return stops[0][1]

def make(size):
    S = size*SS
    img = Image.new('RGBA',(S,S),(0,0,0,0))
    d = ImageDraw.Draw(img)
    m = S*0.02                     # 余白
    # 背景（角丸の紫）
    d.rounded_rectangle([m,m,S-m,S-m], radius=S*0.24, fill=(26,7,51,255))
    # レインボー環を1°ずつ描く
    layers = 26
    for i in range(360):
        t = i/360.0
        col = conic(t)
        a0 = math.radians(i-0.6); a1 = math.radians(i+1.2)
        for L in range(layers):
            r = (S/2-m) - (S*0.055)*(L/layers)
            box = [S/2-r, S/2-r, S/2+r, S/2+r]
            d.pieslice(box, math.degrees(a0), math.degrees(a1), fill=col+(255,))
            break
    # 内側をくり抜いて環にする
    pad = S*0.105
    d.rounded_rectangle([m+pad,m+pad,S-m-pad,S-m-pad], radius=S*0.17, fill=(26,7,51,255))
    # ちんすこう（クッキー）
    cw, ch = S*0.52, S*0.34
    x0, y0 = (S-cw)/2, (S-ch)/2 + S*0.01
    d.rounded_rectangle([x0,y0,x0+cw,y0+ch], radius=S*0.055, fill=(240,206,142,255),
                        outline=(196,140,60,255), width=max(1,int(S*0.012)))
    d.rounded_rectangle([x0+S*0.03,y0+S*0.03,x0+cw-S*0.03,y0+ch*0.42], radius=S*0.03,
                        fill=(253,240,214,190))
    # クッキーの斑点
    for (fx,fy,fr) in [(0.22,0.34,0.035),(0.5,0.6,0.032),(0.74,0.3,0.032),(0.34,0.72,0.03)]:
        cx, cy = x0+cw*fx, y0+ch*fy
        rr = S*fr
        d.ellipse([cx-rr,cy-rr,cx+rr,cy+rr], fill=(158,106,44,255))
    return img.resize((size,size), Image.LANCZOS)

for dpi, size in SIZES.items():
    d = os.path.join(OUT, 'mipmap-%s' % dpi)
    os.makedirs(d, exist_ok=True)
    make(size).save(os.path.join(d,'ic_launcher.png'))
    print('wrote', os.path.join(d,'ic_launcher.png'), size)
