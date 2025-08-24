<?php
/**
 * Konfigurace po prostředích.
 * Vybere se podle HTTP_HOST nebo podle proměnné prostředí APP_ENV.
 */
$env = getenv('APP_ENV') ?: ($_SERVER['HTTP_HOST'] ?? 'localhost');

$all = [

  // Lokální vývoj (app běží v podadresáři /soutez/www)
  'localhost' => [
    'app' => [
      'base_url'  => 'http://localhost/soutez/www', // <- KOŘEN APLIKACE
      // volitelně: 'pretty_urls' => false,
    ],
    'db'  => [
      'driver'   => 'mysqli',
      'host'     => '127.0.0.1',
      'username' => 'root',
      'password' => 'xxxx',
      'database' => 'soutez',
      'charset'  => 'utf8',
    ],
    'debug' => true,
  ],

  // Produkce – hlavní doména, DocumentRoot je public_html (kořen app = /)
  'nasoutez.eu' => [
    'app' => [
      'base_url' => 'https://nasoutez.eu',
    ],
    'db'  => [ /* prod DB */ ],
    'debug' => false,
  ],

  // Produkce – demo subdoména, DocumentRoot je public_html/demo (kořen app = /)
  'demo.nasoutez.eu' => [
    'app' => [
      'base_url' => 'https://demo.nasoutez.eu',
    ],
    'db'  => [ /* demo DB */ ],
    'debug' => false,
  ],
];

/* Fallback – když host neodpovídá klíči, použij nejbližší */
$config = $all['localhost'];
foreach ($all as $host => $cfg) {
    if (stripos($env, $host) !== false) { $config = $cfg; break; }
}
return $config;
