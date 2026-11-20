<?php
// English texts. Values may contain the small amount of HTML used below (<code>, <strong>); they are written by us, never by visitors.
return [
    'html_lang' => 'en',
    'og_locale' => 'en_US',
    'title'     => 'DorothyOS — a tablet-first Linux for the Xiaomi Pad 6',
    'desc'      => 'DorothyOS turns the Xiaomi Pad 6 into a tablet that behaves like one: an iPad-style home screen, touch control center, start menu and Settings on KDE Plasma 6. Open source, reproducible, flashable.',
    'skip'      => 'Skip to content',
    'nav' => ['features' => 'Features', 'look' => 'Look', 'get' => 'Get it', 'install' => 'Install', 'status' => 'Status', 'source' => 'Source', 'github' => 'GitHub'],
    'lang_label' => 'Language',

    'hero' => [
        'eyebrow' => 'Xiaomi Pad 6 (pipa) · release candidate',
        'title'   => 'A tablet-first Linux for the Xiaomi Pad 6.',
        'lead'    => 'An iPad-style home screen, a touch control center, a start menu and a Settings app — on KDE Plasma 6 and a normal, upgradeable Linux. Open source, reproducible, flashable.',
        'cta1'    => 'Get the images',
        'cta2'    => 'What is inside',
        'cta3'    => 'View on GitHub',
        'warn_rc' => '<strong>Verified on one Tianma tablet only.</strong> The images are built and checked offline; the Tianma image booted and ran on one tablet, CSOT has not been tried. The first flash is a test. Back up first.',
        'warn_ok' => 'Tested on real tablets — see the status below.',
        'mock_caption' => 'A real screenshot from the reference tablet — the default home screen.',
        'mock_alt'     => 'The DorothyOS home screen on a Xiaomi Pad 6 (screenshot)',
    ],

    'features' => [
        'kicker' => 'What you get',
        'title'  => 'It behaves like a tablet.',
        'lead'   => 'Everything is a script, a QML widget or a package recipe — the images are built from them with one command.',
        'items'  => [
            ['home',     'Home screen',        'Pages, folders and edit mode on long-press. Tile icons, and your wallpaper is never darkened.'],
            ['dock',     'Dock and status bar', 'A small floating dock with the DorothyOS start button, and a transparent status bar out of the way.'],
            ['start',    'Start menu',         'Pinned and recent apps, all apps by category or A–Z, search and session buttons — everything Kickoff does, sized for fingers.'],
            ['control',  'Control center',     'Wi-Fi, Bluetooth, brightness, volume, Do Not Disturb and rotation lock. Swipe down from the top edge.'],
            ['settings', 'Settings',           'A sidebar app for Wi-Fi, Bluetooth, display, sound, battery, appearance and more — linking to the full KDE modules for anything deeper.'],
            ['display',  'Display that fits',  '250 % scale, landscape and auto-rotate by default — also at the login screen and in the first-boot wizard.'],
            ['camera',   'Camera',             'The rear camera through libcamera. The Camera tile offers the best available app the first time you use it.'],
            ['private',  'Private from the first boot', 'No default user, no default password, ssh off, root locked. You create your own account in the first-boot wizard.'],
            ['updates',  'Real updates',       'A normal package-managed system: <code>apk upgrade</code> or Discover. No re-flashing for every update.'],
        ],
    ],

    'screens' => [
        'kicker' => 'On the tablet',
        'title'  => 'Real screens, from a real Pad 6.',
        'lead'   => 'Screenshots from the reference Xiaomi Pad 6 (Tianma panel) running release-candidate software.',
        'items'  => [
            'start'    => ['DorothyOS Start.', 'Pinned and recent apps, all apps by category, search and the session buttons.'],
            'cc'       => ['Control center.', 'Swipe down from the top edge: radios, brightness, volume, focus and rotation lock.'],
            'settings' => ['DorothyOS Settings.', 'One list for the everyday settings; deeper pages open the full KDE modules.'],
            'splash'   => ['Boot splash.', 'The ring with a turning arc, also shown when the tablet restarts or shuts down.'],
        ],
        'note_title' => 'About these pictures',
        'note'   => 'The boot splash cannot be screenshotted, so that picture is rendered from the theme files with the same layout the boot script uses. In the control center image the Wi-Fi network name was removed.',
    ],
    'look' => [
        'kicker' => 'Look',
        'title'  => 'Dark, quiet, orange.',
        'lead'   => 'The ring mark, one orange accent (<code>#e85d00</code>), a ring boot splash and eight original wallpapers. The wallpapers are free to use (CC0) — tap one to download it in full size, 2880 × 1800.',
        'dl'     => 'Download',
        'names'  => ['charcoal' => 'Charcoal', 'dusk' => 'Dusk', 'emberhigh' => 'Ember High', 'emberlow' => 'Ember Low', 'embermid' => 'Ember Mid', 'paperring' => 'Paper Ring', 'ringnight' => 'Ring Night', 'sand' => 'Sand'],
    ],

    'get' => [
        'kicker' => 'Get it',
        'title'  => 'Two images — one for each display panel.',
        'lead'   => 'Both are built from the same sources; only the device tree that drives the screen differs. <strong>Do not guess your panel:</strong> <code>flash/detect-panel.sh</code> tells you while the tablet still runs Android.',
        'panel'  => 'panel',
        'tianma' => 'Tianma',
        'csot'   => 'CSOT',
        'file'   => 'File',
        'soon'   => 'Available with the first public release',
        'open'   => 'Open the release page',
        'note'   => 'Every release ships a checksum file, and the flash script checks it. The images are split into parts below 2 GiB and compressed with zstd; the release explains how to put them back together.',
        'danger' => '<strong>Flashing erases the tablet.</strong> You do it at your own risk — read the limitations first.',
    ],

    'install' => [
        'kicker' => 'Install',
        'title'  => 'Four steps.',
        'steps'  => [
            ['Unlock the bootloader and back up', 'Xiaomi’s official process — it wipes the tablet. Keep a backup so that you can go back to Android.'],
            ['Find your panel', 'Run <code>flash/detect-panel.sh</code> while Android still runs. Tianma or CSOT — the answer decides the image.'],
            ['Flash', 'The script checks the device, the checksum and the panel, shows you the plan and asks you to type <code>ERASE</code>.'],
            ['First boot', 'KDE Plasma Setup creates <strong>your</strong> account. After the first login the tablet-first setup runs once.'],
        ],
        'code'   => './flash/flash.sh --panel tianma \\
    --image dorothyos-%s-tianma.sparse.img \\
    --uboot u-boot-xiaomi-pipa.img',
        'copy'   => 'Copy', 'copied' => 'Copied',
        'uboot'  => 'The U-Boot image comes from the community project and is not included. The docs say where to get it and how to return to Android.',
    ],

    'status' => [
        'kicker' => 'Honest status',
        'title'  => 'What has been checked — and what has not.',
        'lead_rc' => 'This is release candidate 1. It has been built and validated offline. The Tianma image has been flashed to one tablet and went through setup to the home screen; the CSOT image has not been on any hardware yet.',
        'lead_ok' => 'Hardware reports have been received; the table in the validation document lists them.',
        'ok_title' => 'Checked offline, both images',
        'ok' => [
            'No account, password, ssh key, Wi-Fi profile or device identifier inside the image; root is locked and ssh is off.',
            'The boot entry names the right device tree for the panel, and that file is on the boot partition.',
            'Branding is in place, including the boot-splash theme inside the initramfs.',
            'File systems are clean; the touch-UI packages are installed and pass their syntax checks.',
            'The build refuses to finish if any of this is wrong.',
        ],
        'todo_title' => 'Not verified yet',
        'todo' => [
            'That the CSOT image boots, or anything else about the CSOT panel.',
            'The Tianma image on more than one tablet and more than one run.',
            'The shutdown splash, and how the boot splash looks.',
            'Touch behaviour of the start menu and the Settings app.',
            'Package upgrades after installation.',
        ],
        'next_title' => 'Upcoming changes',
        'next' => [
            'UI changes and improvements — keep refining the interface: fewer scripted workarounds, more first-class Plasma components, touch behaviour that feels like part of the system, and smarter use of the sensors that already work (automatic brightness, orientation).',
            'Sound quality issues and calibration — look into the known sound-quality problems and calibrate the audio output (levels, tuning) for this tablet.',
            'Camera quality — a proper tuning profile for the rear sensor (colour, white balance, noise), then autofocus and the front camera once the kernel can describe them.',
        ],
        'report' => 'Flashed one? Tell us how it went — a report from a real tablet is the most valuable thing right now.',
        'report_cta' => 'Send a report',
    ],

    'source' => [
        'kicker' => 'Open source',
        'title'  => 'Everything is in the repository.',
        'lead'   => 'Scripts, widgets and package recipes — build the images yourself, then check them. Needs Docker that can run privileged arm64 containers (an Apple Silicon Mac or an ARM64 Linux machine) and about 25 GB of free disk.',
        'code'   => './build/build.sh both      # both images
./tests/validate.sh        # offline checks of those images
sh tests/audit.sh          # secrets, personal data, licences',
        'lic_title' => 'Licences',
        'lic' => [['Code', 'MIT'], ['Wallpapers', 'CC0 1.0'], ['Logo, wordmark, icon, boot splash', 'CC BY 4.0']],
        'repo'   => 'Repository',
        'repo_soon' => 'The repository will be published with the first public release.',
    ],

    'footer' => [
        'tag'    => 'A tablet-first Linux for the Xiaomi Pad 6.',
        'indep'  => 'DorothyOS is an independent project, not affiliated with or endorsed by the projects or companies it names.',
        'credits' => 'Credits and licences',
        'credits_intro' => 'DorothyOS stands on the work of many open-source communities. Thank you.',
        'credits_items' => [
            ['postmarketOS and Alpine Linux', 'the base system, the device packages, the firmware packaging and the build tool'],
            ['The pipa mainline-Linux community', 'Linux and U-Boot for the Xiaomi Pad 6'],
            ['KDE and Qt', 'Plasma, Frameworks, Plasma Setup and the apps'],
            ['Mesa, libcamera, PipeWire, systemd, NetworkManager, BlueZ, Flatpak and Flathub', 'graphics, camera, audio, services, networking and app delivery'],
            ['Mozilla Firefox, VLC, GNOME Snapshot, COSMIC Camera', 'apps the image ships or offers'],
        ],
        'credits_more' => 'Every package, with its version and licence, is listed next to each image. Names such as postmarketOS, Alpine Linux, KDE, Qt, Xiaomi, Firefox and Flathub belong to their owners.',
        'top'    => 'Back to top',
    ],
];
