<?php
// DorothyOS landing page — the only file you normally edit.
// Upload the whole folder so that it answers at https://dorothy.gr/dorothyos/ (index.php is the page).
return [
    'author' => 'Andreas Boglou',
    'author_url' => 'https://boglou.com',
    'site_url'       => 'https://dorothy.gr/dorothyos/',   // canonical address, with the trailing slash
    'version'        => '0.1.0-rc1',                        // shown in the header and the hero
    'image_version'  => '0.1.0',                            // used in the image file names (dorothyos-<image_version>-<panel>.sparse.img)
    'status'         => 'rc',                               // 'rc' = release candidate, not verified on hardware; 'verified' = hardware reports received

    // The GitHub repository. While these are empty the page shows no repository link at all (useful before the repository is public).
    'repo_url'       => 'https://github.com/andrikosbo/dorothyos',
    'releases_url'   => 'https://github.com/andrikosbo/dorothyos/releases',
    'issues_url'     => 'https://github.com/andrikosbo/dorothyos/issues',

    'default_lang'   => 'en',                               // used when the browser does not ask for a supported language
    'langs'          => ['en' => 'English', 'el' => 'Ελληνικά'],
];
