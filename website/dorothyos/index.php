<?php
declare(strict_types=1);

/* DorothyOS landing page — https://dorothy.gr/dorothyos/
 * One file, no database, no cookies, no external requests. Texts live in lang/*.php, settings in config.php. */

$cfg = require __DIR__ . '/config.php';

function pick_lang(array $cfg): string
{
    $supported = array_keys($cfg['langs']);
    $asked = $_GET['lang'] ?? null;
    if (is_string($asked) && in_array($asked, $supported, true)) {
        return $asked;
    }
    $found = [];
    foreach (explode(',', (string)($_SERVER['HTTP_ACCEPT_LANGUAGE'] ?? '')) as $i => $part) {
        $bits = explode(';', trim($part));
        $tag = strtolower(substr(trim($bits[0]), 0, 2));
        $q = 1.0;
        foreach (array_slice($bits, 1) as $b) {
            if (preg_match('/^\s*q=([0-9.]+)/', $b, $m)) { $q = (float)$m[1]; }
        }
        if (in_array($tag, $supported, true) && $q > 0) { $found[] = [$q, -$i, $tag]; }
    }
    if ($found) {
        rsort($found);
        return $found[0][2];
    }
    return $cfg['default_lang'];
}

$lang  = pick_lang($cfg);
$T     = require __DIR__ . "/lang/$lang.php";
$forced = isset($_GET['lang']) && is_string($_GET['lang']) && isset($cfg['langs'][$_GET['lang']]);

function e(string $s): string { return htmlspecialchars($s, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }
/** Text by dotted path (trusted markup from lang/*.php). */
function t(string $path): string
{
    global $T;
    $v = $T;
    foreach (explode('.', $path) as $k) { $v = $v[$k] ?? ''; }
    return is_string($v) ? $v : '';
}
function asset(string $p): string
{
    $f = __DIR__ . '/' . $p;
    return e($p) . (is_file($f) ? '?v=' . filemtime($f) : '');
}
function ico(string $name, string $cls = 'ico'): string
{
    return '<svg class="' . $cls . '" viewBox="0 0 24 24" aria-hidden="true" focusable="false"><use href="#i-' . $name . '"/></svg>';
}

$site  = rtrim($cfg['site_url'], '/') . '/';
$canon = $forced ? $site . '?lang=' . $lang : $site;
$rc    = $cfg['status'] !== 'verified';
$walls = ['ringnight' => 'dark', 'dusk' => 'dark', 'emberhigh' => 'dark', 'embermid' => 'dark', 'emberlow' => 'dark', 'charcoal' => 'dark', 'paperring' => 'light', 'sand' => 'light'];

header('Content-Type: text/html; charset=utf-8');
header('Vary: Accept-Language');
header('Cache-Control: public, max-age=300');
header('X-Content-Type-Options: nosniff');
header('Referrer-Policy: strict-origin-when-cross-origin');
header('Permissions-Policy: camera=(), microphone=(), geolocation=()');
header("Content-Security-Policy: default-src 'none'; img-src 'self' data:; style-src 'self'; script-src 'self'; base-uri 'self'; form-action 'none'; frame-ancestors 'none'");

$ld = [
    '@context' => 'https://schema.org',
    '@type' => 'SoftwareApplication',
    'name' => 'DorothyOS',
    'applicationCategory' => 'OperatingSystem',
    'operatingSystem' => 'Linux (Xiaomi Pad 6 “pipa”)',
    'softwareVersion' => $cfg['version'],
    'description' => t('desc'),
    'url' => $site,
    'image' => $site . 'assets/img/og.png',
    'inLanguage' => $lang,
    'isAccessibleForFree' => true,
    'author' => ['@type' => 'Person', 'name' => $cfg['author'], 'url' => $cfg['author_url']],
    'license' => 'https://opensource.org/license/mit',
    'offers' => ['@type' => 'Offer', 'price' => '0', 'priceCurrency' => 'EUR'],
];
?>
<!doctype html>
<html lang="<?= e(t('html_lang')) ?>">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title><?= e(t('title')) ?></title>
<meta name="description" content="<?= e(t('desc')) ?>">
<meta name="author" content="<?= e($cfg['author']) ?>">
<meta name="theme-color" content="#0d0d0f">
<meta name="color-scheme" content="dark">
<link rel="canonical" href="<?= e($canon) ?>">
<link rel="alternate" hreflang="x-default" href="<?= e($site) ?>">
<?php foreach ($cfg['langs'] as $code => $label): ?>
<link rel="alternate" hreflang="<?= e($code) ?>" href="<?= e($site . '?lang=' . $code) ?>">
<?php endforeach; ?>
<meta property="og:type" content="website">
<meta property="og:site_name" content="DorothyOS">
<meta property="og:title" content="<?= e(t('title')) ?>">
<meta property="og:description" content="<?= e(t('desc')) ?>">
<meta property="og:url" content="<?= e($canon) ?>">
<meta property="og:image" content="<?= e($site) ?>assets/img/og.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta property="og:locale" content="<?= e(t('og_locale')) ?>">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" href="<?= asset('assets/img/symbol.svg') ?>" type="image/svg+xml">
<link rel="icon" href="<?= asset('assets/img/favicon.ico') ?>" sizes="48x48">
<link rel="apple-touch-icon" href="<?= asset('assets/img/apple-touch-icon.png') ?>">
<link rel="stylesheet" href="<?= asset('assets/css/site.css') ?>">
<script src="<?= asset('assets/js/site.js') ?>" defer></script>
<script type="application/ld+json"><?= json_encode($ld, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_HEX_TAG) ?></script>
</head>
<body>
<svg class="sprite" width="0" height="0" aria-hidden="true" focusable="false">
  <defs>
    <symbol id="i-home" viewBox="0 0 24 24"><rect x="3.5" y="3.5" width="7" height="7" rx="2"/><rect x="13.5" y="3.5" width="7" height="7" rx="2"/><rect x="3.5" y="13.5" width="7" height="7" rx="2"/><rect x="13.5" y="13.5" width="7" height="7" rx="2"/></symbol>
    <symbol id="i-dock" viewBox="0 0 24 24"><rect x="2.5" y="14" width="19" height="6" rx="3"/><path d="M7.5 17h.01M12 17h.01M16.5 17h.01"/><path d="M8 5h8M10 8.5h4"/></symbol>
    <symbol id="i-start" viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="3.2"/></symbol>
    <symbol id="i-control" viewBox="0 0 24 24"><circle cx="9" cy="7" r="2"/><path d="M4 7h3M11 7h9"/><circle cx="15" cy="12" r="2"/><path d="M4 12h9M17 12h3"/><circle cx="8" cy="17" r="2"/><path d="M4 17h2M10 17h10"/></symbol>
    <symbol id="i-settings" viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="6.6"/><path d="M12 2.8v2.6M12 18.6v2.6M2.8 12h2.6M18.6 12h2.6M5.5 5.5l1.8 1.8M16.7 16.7l1.8 1.8M5.5 18.5l1.8-1.8M16.7 7.3l1.8-1.8"/></symbol>
    <symbol id="i-display" viewBox="0 0 24 24"><rect x="2.5" y="5" width="19" height="14" rx="3"/><path d="M19 12h.01"/><path d="M9 9.5l3-3 3 3M9 14.5l3 3 3-3" opacity=".0"/></symbol>
    <symbol id="i-camera" viewBox="0 0 24 24"><path d="M4 8h3l1.6-2.2h6.8L17 8h3a1 1 0 0 1 1 1v9a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1z"/><circle cx="12" cy="13" r="3.6"/></symbol>
    <symbol id="i-private" viewBox="0 0 24 24"><rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8.2 10.5V8a3.8 3.8 0 0 1 7.6 0v2.5"/><path d="M12 15v2"/></symbol>
    <symbol id="i-updates" viewBox="0 0 24 24"><path d="M4.5 12a7.5 7.5 0 0 1 13-5.1L19.5 9"/><path d="M19.5 4.5V9H15"/><path d="M19.5 12a7.5 7.5 0 0 1-13 5.1L4.5 15"/><path d="M4.5 19.5V15H9"/></symbol>
    <symbol id="i-files" viewBox="0 0 24 24"><path d="M3.5 7.5a2 2 0 0 1 2-2h4l2 2.2h7a2 2 0 0 1 2 2v7.8a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z"/></symbol>
    <symbol id="i-web" viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><path d="M3.5 12h17M12 3.5c2.6 2.4 3.8 5.2 3.8 8.5s-1.2 6.1-3.8 8.5c-2.6-2.4-3.8-5.2-3.8-8.5S9.4 5.9 12 3.5z"/></symbol>
    <symbol id="i-photos" viewBox="0 0 24 24"><rect x="3.5" y="4.5" width="17" height="15" rx="3"/><circle cx="9" cy="10" r="1.6"/><path d="M4 17l5-4.5 3.5 3L15.5 13l5 4.5"/></symbol>
    <symbol id="i-music" viewBox="0 0 24 24"><path d="M9 17.5V6.5l10-2v11"/><circle cx="6.8" cy="17.5" r="2.2"/><circle cx="16.8" cy="15.5" r="2.2"/></symbol>
    <symbol id="i-notes" viewBox="0 0 24 24"><path d="M6.5 3.5h11a1.5 1.5 0 0 1 1.5 1.5v14a1.5 1.5 0 0 1-1.5 1.5h-11A1.5 1.5 0 0 1 5 19V5a1.5 1.5 0 0 1 1.5-1.5z"/><path d="M8.5 8.5h7M8.5 12h7M8.5 15.5h4"/></symbol>
    <symbol id="i-mail" viewBox="0 0 24 24"><rect x="3" y="5.5" width="18" height="13" rx="3"/><path d="M4 8l8 6 8-6"/></symbol>
    <symbol id="i-calendar" viewBox="0 0 24 24"><rect x="3.5" y="5" width="17" height="15.5" rx="3"/><path d="M3.5 10h17M8 3v4M16 3v4"/></symbol>
    <symbol id="i-terminal" viewBox="0 0 24 24"><path d="M6 8.5l4.5 3.5L6 15.5"/><path d="M13 16h5"/></symbol>
    <symbol id="i-clock" viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><path d="M12 7v5l3.2 2"/></symbol>
    <symbol id="i-check" viewBox="0 0 24 24"><path d="M5 12.5l4.2 4.2L19 7"/></symbol>
    <symbol id="i-open" viewBox="0 0 24 24"><circle cx="12" cy="12" r="7.5"/></symbol>
    <symbol id="i-down" viewBox="0 0 24 24"><path d="M12 4.5v11M7.5 11.5l4.5 4.5 4.5-4.5M5 19.5h14"/></symbol>
    <symbol id="i-copy" viewBox="0 0 24 24"><rect x="8.5" y="8.5" width="11" height="11" rx="2.5"/><path d="M15.5 8.5V6.5a2 2 0 0 0-2-2h-7a2 2 0 0 0-2 2v7a2 2 0 0 0 2 2h2"/></symbol>
    <symbol id="i-arrow" viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6"/></symbol>
    <symbol id="i-warn" viewBox="0 0 24 24"><path d="M12 4.2l9 15.6H3z"/><path d="M12 10v4.2M12 17.2h.01"/></symbol>
  </defs>
</svg>

<a class="skip" href="#main"><?= e(t('skip')) ?></a>

<header class="nav" id="top">
  <div class="wrap nav-in">
    <a class="brand" href="<?= e($forced ? '?lang=' . $lang : './') ?>" aria-label="DorothyOS">
      <img class="brand-mark" src="<?= asset('assets/img/symbol-on-dark.svg') ?>" width="34" height="34" alt="">
      <img class="brand-word" src="<?= asset('assets/img/wordmark-on-dark.svg') ?>" width="140" height="30" alt="DorothyOS">
    </a>
    <nav class="links" aria-label="<?= e(t('nav.features')) ?>">
      <a href="#features"><?= e(t('nav.features')) ?></a>
      <a href="#look"><?= e(t('nav.look')) ?></a>
      <a href="#get"><?= e(t('nav.get')) ?></a>
      <a href="#install"><?= e(t('nav.install')) ?></a>
      <a href="#status"><?= e(t('nav.status')) ?></a>
      <a href="#source"><?= e(t('nav.source')) ?></a>
    </nav>
    <div class="nav-end">
      <div class="lang" role="group" aria-label="<?= e(t('lang_label')) ?>">
<?php foreach ($cfg['langs'] as $code => $label): ?>
        <a href="?lang=<?= e($code) ?>" hreflang="<?= e($code) ?>" lang="<?= e($code) ?>" title="<?= e($label) ?>"<?= $code === $lang ? ' aria-current="true"' : '' ?>><?= e(strtoupper($code === 'el' ? 'ΕΛ' : $code)) ?></a>
<?php endforeach; ?>
      </div>
<?php if ($cfg['repo_url'] !== ''): ?>
      <a class="btn btn-ghost btn-sm nav-gh" href="<?= e($cfg['repo_url']) ?>" rel="noopener"><?= e(t('nav.github')) ?></a>
<?php endif; ?>
      <a class="btn btn-sm" href="#get"><?= e(t('nav.get')) ?></a>
    </div>
  </div>
</header>

<main id="main">

<!-- ───────────── hero ───────────── -->
<section class="hero">
  <div class="wrap hero-grid">
    <div class="hero-copy">
      <p class="eyebrow"><span class="dot"></span><?= e(t('hero.eyebrow')) ?> · <?= e($cfg['version']) ?></p>
      <h1><?= e(t('hero.title')) ?></h1>
      <p class="lead"><?= e(t('hero.lead')) ?></p>
      <div class="cta">
        <a class="btn" href="#get"><?= e(t('hero.cta1')) ?> <?= ico('arrow', 'ico ico-end') ?></a>
        <a class="btn btn-ghost" href="#features"><?= e(t('hero.cta2')) ?></a>
<?php if ($cfg['repo_url'] !== ''): ?>
        <a class="btn btn-ghost" href="<?= e($cfg['repo_url']) ?>" rel="noopener"><?= e(t('hero.cta3')) ?> <?= ico('arrow', 'ico ico-end') ?></a>
<?php endif; ?>
      </div>
      <p class="notice <?= $rc ? 'notice-warn' : 'notice-ok' ?>"><?= ico($rc ? 'warn' : 'check') ?><span><?= $rc ? t('hero.warn_rc') : t('hero.warn_ok') ?></span></p>
    </div>

    <figure class="hero-visual">
      <div class="glow" aria-hidden="true"></div>
      <div class="rings" aria-hidden="true"></div>
      <div class="device" id="device" role="img" aria-label="<?= e(t('hero.mock_alt')) ?>">
        <div class="glass">
          <span class="cam" aria-hidden="true"></span>
          <div class="screen">
            <img class="screen-img" src="<?= asset('assets/img/screens/home.jpg') ?>" srcset="<?= asset('assets/img/screens/home-1000.jpg') ?> 1000w, <?= asset('assets/img/screens/home.jpg') ?> 2000w" sizes="(max-width: 1000px) 92vw, 640px" width="2000" height="1250" alt="" decoding="async" fetchpriority="high">
          </div>
        </div>
      </div>
      <figcaption><?= e(t('hero.mock_caption')) ?></figcaption>
    </figure>
  </div>
</section>

<!-- ───────────── features ───────────── -->
<section class="section" id="features">
  <div class="wrap">
    <header class="head">
      <p class="kicker"><?= e(t('features.kicker')) ?></p>
      <h2><?= e(t('features.title')) ?></h2>
      <p class="sublead"><?= e(t('features.lead')) ?></p>
    </header>
    <div class="cards">
<?php foreach ($T['features']['items'] as [$icon, $title, $text]): ?>
      <article class="card">
        <span class="card-ico"><?= ico($icon) ?></span>
        <h3><?= e($title) ?></h3>
        <p><?= $text ?></p>
      </article>
<?php endforeach; ?>
    </div>
  </div>
</section>

<!-- ───────────── real screens ───────────── -->
<section class="section" id="screens">
  <div class="wrap">
    <header class="head">
      <p class="kicker"><?= e(t('screens.kicker')) ?></p>
      <h2><?= e(t('screens.title')) ?></h2>
      <p class="sublead"><?= e(t('screens.lead')) ?></p>
    </header>
    <div class="shots">
<?php
$shots = [['start', 'start-menu.jpg', 1600, 931], ['cc', 'control-center.jpg', 1000, 1048], ['settings', 'settings.jpg', 900, 1298], ['splash', 'boot-splash.png', 750, 1200]];
foreach ($shots as $i => [$key, $file, $w, $h]):
    if ($i === 0 || $i === 2): ?>
      <div class="shots-row shots-row-<?= $i === 0 ? 'a' : 'b' ?>">
<?php endif; ?>
        <figure class="shot shot-<?= e($key) ?>">
          <a href="<?= asset("assets/img/screens/$file") ?>" class="shot-img"><img src="<?= asset("assets/img/screens/$file") ?>" width="<?= $w ?>" height="<?= $h ?>" loading="lazy" decoding="async" alt="<?= e(t("screens.items.$key.0")) ?>"></a>
          <figcaption><strong><?= e(t("screens.items.$key.0")) ?></strong> <?= e(t("screens.items.$key.1")) ?></figcaption>
        </figure>
<?php if ($i === 3): ?>
        <aside class="shot-note card">
          <h3><?= e(t('screens.note_title')) ?></h3>
          <p><?= e(t('screens.note')) ?></p>
        </aside>
<?php endif;
    if ($i === 1 || $i === 3): ?>
      </div>
<?php endif;
endforeach; ?>
    </div>
  </div>
</section>

<!-- ───────────── look ───────────── -->
<section class="section section-alt" id="look">
  <div class="wrap">
    <header class="head">
      <p class="kicker"><?= e(t('look.kicker')) ?></p>
      <h2><?= e(t('look.title')) ?></h2>
      <p class="sublead"><?= t('look.lead') ?></p>
    </header>
    <ul class="walls">
<?php foreach ($walls as $slug => $tone): $name = t("look.names.$slug"); ?>
      <li><a class="wall-card" href="<?= asset("assets/img/wallpapers/$slug.jpg") ?>" download="dorothyos-<?= e($slug) ?>.jpg" aria-label="<?= e(t('look.dl') . ': ' . $name) ?>">
        <img src="<?= asset("assets/img/wallpapers/$slug-thumb.jpg") ?>" width="480" height="300" loading="lazy" decoding="async" alt="">
        <span class="wall-name"><?= e($name) ?><?= ico('down', 'ico ico-end') ?></span>
      </a></li>
<?php endforeach; ?>
    </ul>
  </div>
</section>

<!-- ───────────── get ───────────── -->
<section class="section" id="get">
  <div class="wrap">
    <header class="head">
      <p class="kicker"><?= e(t('get.kicker')) ?></p>
      <h2><?= e(t('get.title')) ?></h2>
      <p class="sublead"><?= t('get.lead') ?></p>
    </header>
    <div class="panels">
<?php foreach (['tianma', 'csot'] as $p): $file = sprintf('dorothyos-%s-%s.sparse.img', $cfg['image_version'], $p); ?>
      <article class="panel">
        <p class="panel-tag"><?= e(t('get.panel')) ?></p>
        <h3><?= e(t("get.$p")) ?></h3>
        <p class="file"><span><?= e(t('get.file')) ?></span><code><?= e($file) ?></code></p>
<?php if ($cfg['releases_url'] !== ''): ?>
        <a class="btn" href="<?= e($cfg['releases_url']) ?>" rel="noopener"><?= e(t('get.open')) ?> <?= ico('arrow', 'ico ico-end') ?></a>
<?php else: ?>
        <p class="soon"><?= e(t('get.soon')) ?></p>
<?php endif; ?>
      </article>
<?php endforeach; ?>
    </div>
    <p class="fine"><?= e(t('get.note')) ?></p>
    <p class="notice notice-warn"><?= ico('warn') ?><span><?= t('get.danger') ?></span></p>
  </div>
</section>

<!-- ───────────── install (light band) ───────────── -->
<section class="section section-paper" id="install">
  <div class="wrap">
    <header class="head">
      <p class="kicker"><?= e(t('install.kicker')) ?></p>
      <h2><?= e(t('install.title')) ?></h2>
    </header>
    <ol class="steps">
<?php foreach ($T['install']['steps'] as $i => [$title, $text]): ?>
      <li class="step"><span class="num"><?= $i + 1 ?></span><div><h3><?= e($title) ?></h3><p><?= $text ?></p></div></li>
<?php endforeach; ?>
    </ol>
    <div class="code" data-code>
      <button type="button" class="copy" data-copy data-label="<?= e(t('install.copy')) ?>" data-done="<?= e(t('install.copied')) ?>" hidden><?= ico('copy') ?><span><?= e(t('install.copy')) ?></span></button>
      <pre><code><?= e(sprintf(t('install.code'), $cfg['image_version'])) ?></code></pre>
    </div>
    <p class="fine"><?= e(t('install.uboot')) ?></p>
  </div>
</section>

<!-- ───────────── status ───────────── -->
<section class="section" id="status">
  <div class="wrap">
    <header class="head">
      <p class="kicker"><?= e(t('status.kicker')) ?></p>
      <h2><?= e(t('status.title')) ?></h2>
      <p class="sublead"><?= e($rc ? t('status.lead_rc') : t('status.lead_ok')) ?></p>
    </header>
    <div class="two">
      <article class="card checks">
        <h3><?= e(t('status.ok_title')) ?></h3>
        <ul>
<?php foreach ($T['status']['ok'] as $li): ?>
          <li><?= ico('check', 'ico ico-ok') ?><span><?= e($li) ?></span></li>
<?php endforeach; ?>
        </ul>
      </article>
      <article class="card checks checks-todo">
        <h3><?= e(t('status.todo_title')) ?></h3>
        <ul>
<?php foreach ($T['status']['todo'] as $li): ?>
          <li><?= ico('open', 'ico ico-todo') ?><span><?= e($li) ?></span></li>
<?php endforeach; ?>
        </ul>
      </article>
    </div>
    <article class="card checks checks-next">
      <h3><?= e(t('status.next_title')) ?></h3>
      <ul>
<?php foreach ($T['status']['next'] as $li): ?>
        <li><?= ico('arrow', 'ico ico-next') ?><span><?= e($li) ?></span></li>
<?php endforeach; ?>
      </ul>
    </article>
<?php if ($cfg['issues_url'] !== ''): ?>
    <p class="report"><span><?= e(t('status.report')) ?></span> <a class="btn btn-ghost btn-sm" href="<?= e($cfg['issues_url']) ?>" rel="noopener"><?= e(t('status.report_cta')) ?> <?= ico('arrow', 'ico ico-end') ?></a></p>
<?php endif; ?>
  </div>
</section>

<!-- ───────────── source ───────────── -->
<section class="section section-alt" id="source">
  <div class="wrap">
    <header class="head">
      <p class="kicker"><?= e(t('source.kicker')) ?></p>
      <h2><?= e(t('source.title')) ?></h2>
      <p class="sublead"><?= e(t('source.lead')) ?></p>
    </header>
    <div class="source-grid">
      <div class="code code-dark" data-code>
        <button type="button" class="copy" data-copy data-label="<?= e(t('install.copy')) ?>" data-done="<?= e(t('install.copied')) ?>" hidden><?= ico('copy') ?><span><?= e(t('install.copy')) ?></span></button>
        <pre><code><?= e(t('source.code')) ?></code></pre>
      </div>
      <div class="card lic">
        <h3><?= e(t('source.lic_title')) ?></h3>
        <dl>
<?php foreach ($T['source']['lic'] as [$what, $which]): ?>
          <div><dt><?= e($what) ?></dt><dd><?= e($which) ?></dd></div>
<?php endforeach; ?>
        </dl>
<?php if ($cfg['repo_url'] !== ''): ?>
        <a class="btn btn-ghost btn-sm" href="<?= e($cfg['repo_url']) ?>" rel="noopener"><?= e(t('source.repo')) ?> <?= ico('arrow', 'ico ico-end') ?></a>
<?php else: ?>
        <p class="fine fine-tight"><?= e(t('source.repo_soon')) ?></p>
<?php endif; ?>
      </div>
    </div>
  </div>
</section>

</main>

<footer class="foot">
  <div class="wrap">
    <div class="foot-top">
      <div>
        <img class="foot-word" src="<?= asset('assets/img/wordmark-on-dark.svg') ?>" width="180" height="39" alt="DorothyOS" loading="lazy">
        <p class="foot-tag"><?= e(t('footer.tag')) ?></p>
      </div>
      <a class="totop" href="#top"><?= e(t('footer.top')) ?> <?= ico('arrow', 'ico ico-up') ?></a>
    </div>
    <details class="credits">
      <summary><?= e(t('footer.credits')) ?></summary>
      <div class="credits-body">
        <p><?= e(t('footer.credits_intro')) ?></p>
        <ul>
<?php foreach ($T['footer']['credits_items'] as [$who, $what]): ?>
          <li><strong><?= e($who) ?></strong> — <?= e($what) ?></li>
<?php endforeach; ?>
        </ul>
        <p><?= e(t('footer.credits_more')) ?></p>
      </div>
    </details>
    <p class="legal">© <?= e(date('Y')) ?> <a href="<?= e($cfg['author_url']) ?>" rel="author noopener"><?= e($cfg['author']) ?></a> and DorothyOS contributors · <?= e(t('footer.indep')) ?></p>
  </div>
</footer>

</body>
</html>
