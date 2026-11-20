# Camera on the Xiaomi Pad 6

Result of the camera investigation (reference tablet, kernel 7.2.4-pipa, libcamera 0.7.2/0.8.0, PipeWire 1.6) and what this
directory ships. Status: **not verified on a second device**; the live checks below were done on the reference tablet only.

## What is a driver issue and what is an app issue

| Layer | Finding | Fixable here? |
|---|---|---|
| Kernel (`qcom-camss`, `ov13b10`) | The rear 13 MP OV13B10 probes and streams (`/dev/media0`, libcamera "simple" pipeline + software ISP on the GPU). The mainline `ov13b10` driver does not report the pixel-array crop rectangles ("The sensor kernel driver needs to be fixed" in libcamera's log), so libcamera falls back to defaults. | Only with a kernel patch (not done) |
| Device tree | **No front camera** (8 MP) and **no focus actuator** are described in the mainline device tree, so there is no front camera and the focus is fixed. | No (kernel/DT work) |
| libcamera | No tuning file `ov13b10.yaml` (falls back to `uncalibrated.yaml`: grey-world white balance, no colour matrix) and no entry in the sensor properties database. Black level is estimated automatically ("Auto-set black level"), so no lifted blacks; a hand-made tuning file was therefore **not** added. Colours look muted, more so in dim light. | Needs a proper calibration (colour chart); not invented here |
| App | The PipeWire node carries `api.libcamera.rotation = 270`. **GNOME Snapshot 51.0 never reads it** nor the screen rotation, so the picture is not turned when the tablet is rotated. | **Yes — fixed by using another app** |

## The fix

`io.github.cosmic_utils.camera` ("Camera", Flathub, GPL-3.0): talks to libcamera directly, reads the sensor `Rotation`, and follows the
compositor's output transform (`wl_output` transform), GPU preview. Verified live on the reference tablet:

* viewfinder upright in landscape; after rotating the screen to portrait the picture turned with it (as expected for a tablet that
  did not move) and the UI re-laid itself out;
* `camera list` → "Back Camera", 3840×2400 / 4096×2160 / 3840×2160 @ 30 fps; `camera photo` saves a 3840×2400 JPEG;
* the headless `camera photo` writes EXIF orientation 6 although the pixels were already upright for the landscape position; it does not
  know the tablet position. **Photos taken from the app's own shutter were not tested** (touch cannot be injected) — see "Checks to try".

Known small issues of that app: only one process can use the camera at a time (close Snapshot first); "GPU upload took longer than
frame period" warnings in the journal; it needs Vulkan/GL (present: Mesa freedreno/turnip).

## Files

| File | Purpose |
|---|---|
| `pipa-camera` | launcher: starts the app; if it is not installed asks (kdialog) before downloading ~170 MB, falls back to Snapshot |
| `pipa-camera-setup` | `install` / `remove` / `status` for the Flatpak (user level, Flathub) — never run automatically |
| `pipa-camera.desktop` | the "Camera" menu entry (`Exec=/usr/share/dorothyos-tablet/camera/pipa-camera`) |
| `pipa-camera-live.sh` | `apply [TILE_DIR]` / `undo`: swaps the Snapshot home-grid tile for the Camera app on an existing tablet |

## Checks to try (they need the tablet to be moved)

1. Open Camera, hold the tablet landscape, then turn it 90° and 180° (auto-rotate on): the picture must stay upright each time.
2. Take one photo in landscape and one in portrait with the shutter button, open both in Gwenview/Firefox: they must be upright. If
   not, tell us which; the EXIF handling of the app is the suspect.
3. Colours are expected to be muted indoors (no tuning file).
