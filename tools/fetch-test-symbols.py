#!/usr/bin/env python3
"""Fetch the Business Central test framework symbol apps into the test project.

The test app depends on Microsoft's `Library Assert` and `Any`, which do not
ship with the AL extension. Without them `tools/build.sh` cannot compile the
test app, and no AL test file is checked by the compiler at all.

They live inside the BC platform artifact, which is 1.4 GB. This pulls only the
five .app entries we need out of that zip over HTTP range requests — about 3 MB
transferred — so it is cheap enough to run on any machine that needs it.

Run once per checkout:

    tools/fetch-test-symbols.py "PTE PrintVis External Imposition.Test/.alpackages"
"""
import io
import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _range_zip import HttpRangeFile, BASE

WANTED = [
    "Applications/TestFramework/TestLibraries/Assert/Microsoft_Library Assert.app",
    "Applications/TestFramework/TestLibraries/Any/Microsoft_Any.app",
    "Applications/TestFramework/TestRunner/Microsoft_Test Runner.app",
    "Applications/TestFramework/TestLibraries/Variable Storage/Microsoft_Library Variable Storage.app",
    "Applications/TestFramework/TestLibraries/permissions mock/Microsoft_Permissions Mock.app",
]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    dest = sys.argv[1]
    raw = HttpRangeFile(f"{BASE}/platform")
    z = zipfile.ZipFile(io.BufferedReader(raw, buffer_size=1 << 20))
    os.makedirs(dest, exist_ok=True)
    for name in WANTED:
        data = z.read(name)
        out = os.path.join(dest, os.path.basename(name))
        with open(out, "wb") as f:
            f.write(data)
        print(f"{os.path.basename(name):48s} {len(data):>8,} bytes")
    print(f"\ntransferred {raw.fetched/1e6:.1f} MB of a 1364 MB artifact")


if __name__ == "__main__":
    main()
