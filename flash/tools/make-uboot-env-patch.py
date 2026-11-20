#!/usr/bin/env python3
"""Data-only edit of the default environment embedded in the (already verified, already executing) U-Boot image.

Adds `bootpm`: register our blkmap ESP (userdata image partition 1) as an explicit EFI boot entry, make it the only
BootOrder entry, then run `bootefi bootmgr`.  bootcmd and the menu "Boot" entry call `run bootpm`.
No code is changed; the env text is rewritten in place inside its original byte budget.

usage: make-uboot-env-patch.py ORIG_UBOOT_IMG OUT_IMG
"""
import hashlib, struct, subprocess, sys, zlib

ORIG, OUT = sys.argv[1], sys.argv[2]
d = open(ORIG, "rb").read()

# ---- parse Android boot image v0 ------------------------------------------------------------
magic = d[:8]
ksz, kaddr, rsz, raddr, ssz, saddr, taddr, psz, hver, osver = struct.unpack("<IIIIIIIIII", d[8:48])
assert magic == b"ANDROID!" and hver == 0 and rsz == 0 and ssz == 0 and psz == 2048, "unexpected boot image layout"
hdr_page = bytearray(d[:psz])
kernel = d[psz:psz + ksz]
assert len(d) == psz + ((ksz + psz - 1) // psz) * psz, "unexpected trailing data"

# id field: sha1(kernel,size, ramdisk,size, second,size) zero padded to 32 bytes (verify our formula on the original)
def img_id(k, r=b"", s=b""):
    h = hashlib.sha1()
    for blob in (k, r, s):
        h.update(blob)
        h.update(struct.pack("<I", len(blob)))
    return h.digest().ljust(32, b"\0")
assert img_id(kernel) == bytes(hdr_page[576:608]), "id formula does not reproduce the original header id"

# ---- split gzip(u-boot-nodtb) + appended dtb -------------------------------------------------
dobj = zlib.decompressobj(31)
uboot = bytearray(dobj.decompress(kernel))
dtb_tail = dobj.unused_data
assert dtb_tail[:4] == bytes.fromhex("d00dfeed")

# ---- locate + rewrite the env blob -----------------------------------------------------------
START = bytes(uboot).find(b"bootdelay=0\0")
END_MARK = b"button_cmd_0=run menucmd\0"
END = bytes(uboot).find(END_MARK, START) + len(END_MARK)
assert START > 0 and END > START and bytes(uboot).count(b"bootdelay=0") == 1
assert uboot[END] == 0, "expected the terminating NUL right after the env blob"
budget = END + 1 - START  # strings + final NUL
old = bytes(uboot[START:END]).split(b"\0")[:-1]  # list of 'k=v'
old = [x.decode() for x in old]
env = dict(x.split("=", 1) for x in old)
order = [x.split("=", 1)[0] for x in old]

BOOTPM = "if efidebug boot add -b 70 pmOS blkmap 0:1 /EFI/BOOT/BOOTAA64.EFI; then efidebug boot order 70; bootefi bootmgr; fi"
env["bootpm"] = BOOTPM
env["bootcmd"] = "run bootpm;pause;run menucmd"
env["bootmenu_0"] = "Boot=run bootpm;pause"
# drop the two diagnostic-only entries (clocks, bootargs) and renumber so bootmenu_N stays contiguous
keep = [("Enable serial console gadget",), ]
menu_old = [(int(k.split("_")[1]), env[k]) for k in order if k.startswith("bootmenu_")]
drop_titles = ("Dump clocks=", "Dump bootargs=")
menu_new = [v for n, v in sorted(menu_old) if not v.startswith(drop_titles)]
menu_new[0] = env["bootmenu_0"]
for k in [k for k in order if k.startswith("bootmenu_")]:
    del env[k]
new_order = []
for k in order:
    if k == "bootcmd":
        new_order.append("bootpm")
    if k.startswith("bootmenu_"):
        if k == "bootmenu_0":
            for i, v in enumerate(menu_new):
                env["bootmenu_%d" % i] = v
                new_order.append("bootmenu_%d" % i)
        continue
    new_order.append(k)
text = b"".join((k + "=" + env[k]).encode() + b"\0" for k in new_order) + b"\0"
print("env budget %d bytes, new env %d bytes, spare %d" % (budget, len(text), budget - len(text)))
assert len(text) <= budget, "new env does not fit in the original byte budget"
text = text.ljust(budget, b"\0")
assert len(text) == budget
uboot[START:START + budget] = text

# ---- re-pack: gzip(default level, like the builder) + original dtb, header rebuilt -----------
gz = subprocess.run(["gzip", "-n", "-c"], input=bytes(uboot), capture_output=True, check=True).stdout
new_kernel = gz + dtb_tail
hdr = bytearray(hdr_page)
hdr[8:12] = struct.pack("<I", len(new_kernel))
hdr[576:608] = img_id(new_kernel)
pad = (-len(new_kernel)) % psz
open(OUT, "wb").write(bytes(hdr) + new_kernel + b"\0" * pad)
print("wrote", OUT, "kernel_size", len(new_kernel), "file size", psz + len(new_kernel) + pad)
