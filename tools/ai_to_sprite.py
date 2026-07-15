"""
AI로 생성한 이미지를 가미고치 스프라이트 규격(64x64, MIP 64색 팔레트)으로 변환.

사용법:
    python3 ai_to_sprite.py input.png output.png [--size 32]

- 정사각형으로 중앙 크롭 후 지정 크기로 다운스케일 (기본 64x64)
- RGB 각 채널을 0x00/0x55/0xAA/0xFF 중 가장 가까운 값으로 스냅 (가민 MIP 64색 팔레트)
- 알파 채널이 있으면 투명 영역은 검정(0,0,0)으로 채움 (시계 배경이 항상 검정이라 자연스럽게 섞임)

이미 픽셀아트 스타일인 이미지(PixelLab 등)는 NEAREST 다운스케일을 씀 — BOX(평균)로 하면
경계 픽셀 색이 섞여서 팔레트 스냅 시 의도치 않은 색(보라색 얼룩 등)이 튐.
"""
import sys
import argparse
from PIL import Image

LEVELS = [0x00, 0x55, 0xAA, 0xFF]
NEAR_BLACK_MAX = 80  # 이 값 미만이면 순수 검정으로 강제 (아웃라인 색조 번짐 방지)


def snap_to_level(v):
    return min(LEVELS, key=lambda lv: abs(lv - v))


def snap_rgb(r, g, b):
    # PixelLab 등 AI 생성 아트의 "검정 아웃라인"은 실제로는 순수 (0,0,0)이 아니라
    # 살짝 색조가 낀 어두운 색(예: (53,36,51))인 경우가 많음. 채널별로 따로 스냅하면
    # 채널마다 다른 레벨로 튀어서 보라색/청록색 등 의도치 않은 얼룩이 생김
    # (예: (53,36,51) -> (85,0,85)). 어두운 픽셀은 채도를 무시하고 순수 검정으로 고정.
    if max(r, g, b) < NEAR_BLACK_MAX:
        return (0, 0, 0)
    return (snap_to_level(r), snap_to_level(g), snap_to_level(b))


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
                px_out[x, y] = snap_rgb(r, g, b)

    out.save(output_path)
    print(f"saved {output_path} ({size}x{size}, 64-color snapped)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("--size", type=int, default=64)
    args = parser.parse_args()
    convert(args.input, args.output, args.size)
