#!/usr/bin/env python3
"""사용 가능한 시뮬레이터 중 가장 최신 iOS의 iPhone UDID를 표준 출력으로 내보낸다.

CI 러너 이미지가 갱신되면 시뮬레이터 이름(`iPhone 15` 등)이 바뀌어 destination이 깨지므로,
이름 대신 이 스크립트로 UDID를 찾아서 넘긴다.
"""

import json
import re
import subprocess
import sys

RUNTIME_PATTERN = re.compile(r"iOS-(\d+)-(\d+)")


def latest_iphone(devices):
    """{런타임: [기기]} 딕셔너리에서 (버전, udid, 이름) 중 iOS 버전이 가장 높은 iPhone을 고른다."""
    best = None
    for runtime, entries in devices.items():
        match = RUNTIME_PATTERN.search(runtime)
        if not match:
            continue
        version = (int(match.group(1)), int(match.group(2)))
        for device in entries:
            if not device.get("isAvailable"):
                continue
            if not device.get("name", "").startswith("iPhone"):
                continue
            if best is None or version > best[0]:
                best = (version, device["udid"], device["name"])
    return best


def available_devices():
    result = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)["devices"]


def main():
    best = latest_iphone(available_devices())
    if best is None:
        sys.exit("사용 가능한 iPhone 시뮬레이터가 없습니다.")

    (major, minor), udid, name = best
    # 사람이 읽을 정보는 stderr로, UDID만 stdout으로 내보내 셸에서 그대로 받을 수 있게 한다.
    print(f"선택된 시뮬레이터: {name} (iOS {major}.{minor}) {udid}", file=sys.stderr)
    print(udid)


if __name__ == "__main__":
    main()
