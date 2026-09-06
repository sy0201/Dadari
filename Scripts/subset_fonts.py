#!/usr/bin/env python3
"""고운바탕(Gowun Batang)을 앱에서 실제로 쓰는 글자만 남기고 서브셋한다.

전체 한글을 담은 원본은 8MB짜리 두 벌이라 앱 번들에 그대로 넣기엔 과하다.
목업(ui-mockup.html)에서 고운바탕을 쓰는 곳은 워드마크와 월 레이블, 큰 숫자뿐이라
필요한 글자만 남기면 수십 KB로 줄어든다.

고운바탕으로 표시할 문구를 새로 추가하면 GLYPH_TEXT에 그 글자를 넣고 다시 돌려야 한다.
빠뜨리면 그 글자만 시스템 폰트로 대체돼 톤이 어긋난다.

사용법:
    python3 Scripts/subset_fonts.py <원본_디렉터리> <출력_디렉터리>

원본은 https://fonts.google.com/specimen/Gowun+Batang (OFL-1.1)에서 받는다.
"""

import subprocess
import sys
from pathlib import Path

# 고운바탕으로 그리는 문구에 등장하는 글자를 모두 적는다.
GLYPH_TEXT = "".join([
    "다달이",                      # 워드마크
    "년월일",                      # 월 레이블: 2026년 8월
    "일월화수목금토",              # 요일
    "주기차생리예정",              # 상태 문구에 쓰일 수 있는 글자
    "0123456789",
    "D-+·~ .,()",
])


def subset(source: Path, destination: Path) -> None:
    subprocess.run(
        [
            sys.executable, "-m", "fontTools.subset", str(source),
            f"--text={GLYPH_TEXT}",
            f"--output-file={destination}",
            "--layout-features=*",
            "--no-hinting",
            "--desubroutinize",
            "--name-IDs=*",
        ],
        check=True,
    )


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)

    source_dir = Path(sys.argv[1])
    output_dir = Path(sys.argv[2])
    output_dir.mkdir(parents=True, exist_ok=True)

    for name in ["GowunBatang-Regular.ttf", "GowunBatang-Bold.ttf"]:
        source = source_dir / name
        if not source.exists():
            sys.exit(f"원본을 찾을 수 없다: {source}")
        destination = output_dir / name
        subset(source, destination)
        before = source.stat().st_size
        after = destination.stat().st_size
        print(f"{name}: {before / 1024 / 1024:.1f}MB -> {after / 1024:.0f}KB")


if __name__ == "__main__":
    main()
