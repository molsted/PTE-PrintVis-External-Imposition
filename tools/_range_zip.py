#!/usr/bin/env python3
"""Pull individual .app files out of a Business Central artifact zip over HTTP
range requests, so we transfer megabytes instead of the full 1.4 GB archive.

zipfile drives the seeking; we only serve the byte ranges it asks for.
"""
import io
import sys
import zipfile
import urllib.request

BASE = "https://bcartifacts-exdbf9fwegejdqak.b02.azurefd.net/sandbox/28.0.46665.51904"


class HttpRangeFile(io.RawIOBase):
    def __init__(self, url):
        self.url = url
        self.pos = 0
        req = urllib.request.Request(url, method="HEAD")
        with urllib.request.urlopen(req, timeout=120) as r:
            self.size = int(r.headers["Content-Length"])
        self.fetched = 0

    def readable(self):
        return True

    def seekable(self):
        return True

    def seek(self, offset, whence=io.SEEK_SET):
        if whence == io.SEEK_SET:
            self.pos = offset
        elif whence == io.SEEK_CUR:
            self.pos += offset
        else:
            self.pos = self.size + offset
        return self.pos

    def tell(self):
        return self.pos

    def read(self, n=-1):
        if n is None or n < 0:
            n = self.size - self.pos
        if n == 0 or self.pos >= self.size:
            return b""
        end = min(self.pos + n, self.size) - 1
        req = urllib.request.Request(
            self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        with urllib.request.urlopen(req, timeout=300) as r:
            data = r.read()
        self.fetched += len(data)
        self.pos += len(data)
        return data

    def readinto(self, b):
        # BufferedReader drives this, not read(); RawIOBase's default readinto
        # is not provided here, so wire it to the range fetch explicitly.
        data = self.read(len(b))
        b[:len(data)] = data
        return len(data)


def main():
    which = sys.argv[1] if len(sys.argv) > 1 else "platform"
    pattern = sys.argv[2] if len(sys.argv) > 2 else "assert"
    url = f"{BASE}/{which}"
    raw = HttpRangeFile(url)
    buffered = io.BufferedReader(raw, buffer_size=1 << 20)
    z = zipfile.ZipFile(buffered)
    names = z.namelist()
    print(f"{which}: {len(names)} entries, {raw.fetched/1e6:.1f} MB fetched to read the index")
    hits = [n for n in names if pattern.lower() in n.lower() and n.lower().endswith(".app")]
    for n in hits[:40]:
        print("  ", n, z.getinfo(n).file_size)
    print(f"  ({len(hits)} matches)")


if __name__ == "__main__":
    main()
