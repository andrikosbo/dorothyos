## What does this change, and why?

<!-- One topic per pull request. Link the issue if there is one. -->

## How was it tested?

<!-- Hardware (which panel: Tianma / CSOT) or offscreen / offline? What did you not test? -->

## Checklist

- [ ] `sh tests/audit.sh` passes (no personal data, no secrets, no stray placeholders)
- [ ] shell scripts pass `sh -n` (or `bash -n`); phase scripts stay idempotent and have an `undo`
- [ ] anything under `overlay/`, `build/` or `flash/` that changes the image: images rebuilt and `./tests/validate.sh` run, or said why not
- [ ] documentation and `CHANGELOG.md` updated where behaviour changed
- [ ] no third-party brand artwork, photos you do not own, or proprietary binaries added (`THIRD_PARTY.md` lists licences)
