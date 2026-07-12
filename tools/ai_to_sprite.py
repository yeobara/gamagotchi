"""
AI로 생성한 이미지를 가미고치 스프라이트 규격(32x32, MIP 64색 팔레트)으로 변환.

사용법:
    python3 ai_to_sprite.py input.png output.png [--size 32]

- 정사각형으로 중앙 크롭 후 지정 크기로 다운스케일 (기본 32x32)
- RGB 각 채널을 0x00/0x55/0xAA/0xFF 중 가장 가까운 값으로 스냅 (가민 MIP 64색 팔레트)
- 알파 채널이 있으면 투명 영역은 검정(0,0,0)으로 채움 (시계 배경이 항상 검정이라 자연스럽게 섞임)

이미 픽셀아트 스타일인 이미지(PixelLab 등)는 NEAREST 다운스케일을 씀 — BOX(평균)로 하면
경계 픽셀 색이 섞여서 팔레트 스냅 시 의도치 않은 색(보라색 얼룩 등)이 튐.
"""
import sys
import argparse
from PIL import Image

LEVELS = [0x00, 0x55, 0xAA, 0xFF]


def snap_to_level(v):
    return min(LEVELS, key=lambda lv: abs(lv - v))


def convert(input_path, output_path, size):
    img = Image.open(input_path).convert("RGBA")

    # 정사각형 중앙 크롭
    w, h = img.size
    side = min(w, h)
    left = (w - side) // 2
    top = (h - side) // 2
    img = img.crop((left, top, left + side, top + side))

    # 다운스케일 (NEAREST -> 경계가 안 섞여서 픽셀아트 원본 색이 그대로 유지됨)
    img = img.resize((size, size), Image.NEAREST)

    out = Image.new("RGB", (size, size), (0, 0, 0))
    px_in = img.load()
    px_out = out.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = px_in[x, y]
            if a < 128:
                px_out[x, y] = (0, 0, 0)  # 투명 -> 검정 배경과 자연스럽게 합쳐짐
            else:
                px_out[x, y] = (snap_to_level(r), snap_to_level(g), snap_to_level(b))

    out.save(output_path)
    print(f"saved {output_path} ({size}x{size}, 64-color snapped)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("--size", type=int, default=32)
    args = parser.parse_args()
    convert(args.input, args.output, args.size)
