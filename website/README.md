# DorothyOS landing page

The one-page site for **https://dorothy.gr/dorothyos/** — `index.php` plus assets, English and Greek.
This repository does **not** deploy it; you upload the folder.

## Deploy

1. Upload the **`dorothyos/`** folder so that it answers at `https://dorothy.gr/dorothyos/` (the PHP page is `index.php`; Apache needs nothing else —
   `.htaccess` adds caching, compression and blocks `config.php` / `lang/` when the modules are available). PHP 7.4 or newer (written for 7.4+, tested with 8.5).
2. Open `https://dorothy.gr/dorothyos/` and `https://dorothy.gr/dorothyos/?lang=el`.
3. Nothing else: no database, no cookies, no external fonts/scripts/requests (the page sends a strict Content-Security-Policy), so no cookie banner is needed.

## Edit

* **`dorothyos/config.php`** — version, image version, `status` (`rc` shows the "not verified on hardware" notices, `verified` switches them off) and the three repository URLs.
  While `repo_url`, `releases_url` and `issues_url` are empty **no GitHub link appears anywhere** and the download cards say "Available with the first public release".
  After the repository is published, fill them in — that is the whole change.
* **`dorothyos/lang/en.php`, `lang/el.php`** — every visible text. Add a language: copy `en.php` to `xx.php` and add it to `langs` in `config.php`.
  Language: `?lang=xx`, otherwise the browser's `Accept-Language`, otherwise `default_lang`.
* **`dorothyos/assets/css/site.css`**, `assets/js/site.js` — own code; the JS only adds the copy buttons and the header line (the page works without it).

## Screenshots

`dorothyos/assets/img/screens/`: `start-menu.jpg`, `control-center.jpg` and `settings.jpg` are **real screenshots** taken on the reference Xiaomi Pad 6 (Tianma panel,
release-candidate software); the Wi-Fi name in the control center picture was removed.
`home.jpg` / `home-1000.jpg` (the hero) is a real screenshot of the **default** home-screen layout on the RingNight wallpaper, so it shows nothing private. It sits in a plain dark Pad 6 frame drawn in CSS (`.device`, no gray rim).
`boot-splash.png` is **rendered** from the Plymouth theme files by `tools/make-assets.py` (a splash cannot be screenshotted). To replace a picture, overwrite the file
with the same aspect ratio or adjust the sizes in `index.php`; a photograph of the real splash would be a good replacement once someone has one.

## Regenerate the images

```bash
python3 website/tools/make-assets.py     # needs Pillow; reads branding/logo/dist and the wallpaper packages, writes dorothyos/assets/img
```

## Test locally

```bash
php -S 127.0.0.1:8765 -t website/dorothyos
```

(The page is cacheable for 5 minutes; use `?lang=en&t=1` to bypass your browser cache while editing.)

## Notes

* The hero shows a **real screenshot** inside a CSS-drawn tablet frame (the caption on the page says so); the frame is decoration only.
* The licence line (code MIT, wallpapers CC0, logo and boot splash CC BY 4.0) repeats `THIRD_PARTY.md` — change both together.
* The footer carries the quiet credits (`CREDITS.md` in short form); keep the "independent project, not affiliated" sentence.
