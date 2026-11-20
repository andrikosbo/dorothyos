#!/usr/bin/env python3
"""make-source-tarball.py SRC_DIR LICENSE OUT.tar.gz PKGNAME-PKGVER — deterministic source tarball for the APKBUILD.
Sorted entries, uid/gid 0, mtime 0, modes normalised (755 for executables / directories, 644 otherwise): the same
tree always gives the same bytes, so the checksum in the APKBUILD is reproducible."""
import gzip, io, os, sys, tarfile

src, lic, out, top = sys.argv[1:5]
entries = []
for root, dirs, files in os.walk(src):
    dirs.sort()
    for f in sorted(files):
        p = os.path.join(root, f)
        entries.append((os.path.relpath(p, src), p))
entries.append(("LICENSE", lic))
entries.sort()
buf = io.BytesIO()
with tarfile.open(fileobj=buf, mode="w", format=tarfile.PAX_FORMAT) as tf:
    seen = set()
    for rel, p in entries:
        parts = rel.split(os.sep)
        for i in range(1, len(parts)):
            d = "/".join([top] + parts[:i])
            if d not in seen:
                seen.add(d)
                ti = tarfile.TarInfo(d); ti.type = tarfile.DIRTYPE; ti.mode = 0o755
                tf.addfile(ti)
        ti = tarfile.TarInfo("/".join([top] + parts))
        data = open(p, "rb").read()
        ti.size = len(data)
        ti.mode = 0o755 if os.access(p, os.X_OK) else 0o644
        tf.addfile(ti, io.BytesIO(data))
with open(out, "wb") as fh:
    with gzip.GzipFile(fileobj=fh, mode="wb", mtime=0, compresslevel=9) as gz:
        gz.write(buf.getvalue())
print(out)
