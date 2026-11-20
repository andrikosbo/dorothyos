#!/usr/bin/env python3
"""unsparse.py SPARSE.img RAW.img — converts an Android sparse image (what `fastboot flash` takes) back to a raw disk image.

A minimal, dependency-free replacement for `simg2img`, so that the validation of a release image needs nothing but Python 3.
Output is written sparsely (DONT_CARE chunks become holes)."""
import os
import struct
import sys

SPARSE_MAGIC = 0xED26FF3A
CHUNK_RAW, CHUNK_FILL, CHUNK_DONT_CARE, CHUNK_CRC32 = 0xCAC1, 0xCAC2, 0xCAC3, 0xCAC4


def main(src, dst):
    with open(src, "rb") as f, open(dst, "wb") as out:
        hdr = f.read(28)
        magic, major, minor, hdr_sz, chunk_hdr_sz, blk_sz, total_blks, total_chunks, _crc = struct.unpack("<IHHHHIIII", hdr)
        if magic != SPARSE_MAGIC or major != 1:
            sys.exit(f"{src}: not an Android sparse image")
        f.seek(hdr_sz)
        pos_blk = 0
        for _ in range(total_chunks):
            ch = f.read(chunk_hdr_sz)
            ctype, _rsv, chunk_blks, total_sz = struct.unpack("<HHII", ch[:12])
            data_sz = total_sz - chunk_hdr_sz
            if ctype == CHUNK_RAW:
                if data_sz != chunk_blks * blk_sz:
                    sys.exit("corrupt RAW chunk")
                out.seek(pos_blk * blk_sz)
                left = data_sz
                while left:
                    buf = f.read(min(left, 8 << 20))
                    if not buf:
                        sys.exit("truncated sparse image")
                    out.write(buf)
                    left -= len(buf)
            elif ctype == CHUNK_FILL:
                (val,) = struct.unpack("<I", f.read(4))
                if val:
                    out.seek(pos_blk * blk_sz)
                    out.write(struct.pack("<I", val) * (chunk_blks * blk_sz // 4))
            elif ctype == CHUNK_DONT_CARE:
                pass
            elif ctype == CHUNK_CRC32:
                f.read(4)
            else:
                sys.exit(f"unknown chunk type {ctype:#x}")
            pos_blk += chunk_blks if ctype != CHUNK_CRC32 else 0
        if pos_blk != total_blks:
            sys.exit(f"block count mismatch ({pos_blk} != {total_blks})")
        out.truncate(total_blks * blk_sz)
    print(f"{dst}: {total_blks * blk_sz} bytes ({total_blks} blocks of {blk_sz})")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
