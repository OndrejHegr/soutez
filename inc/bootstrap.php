<?php
declare(strict_types=1);

if (!defined('APP_BOOTSTRAPPED')) {
    define('APP_BOOTSTRAPPED', true);

    // Composer autoload
    require __DIR__ . '/../vendor/autoload.php';

    if (session_status() !== PHP_SESSION_ACTIVE)
        session_start();

    $config = require __DIR__ . '/config.php';

    dibi::connect($config['db']);

    //require_once __DIR__ . '/functions.php';
    require_once __DIR__ . '/database.php';
    //require_once __DIR__ . '/auth.php';

    if (!empty($config['debug'])) {
        ini_set('display_errors','1');
        error_reporting(E_ALL);
    } else {
        ini_set('display_errors','0');
        error_reporting(E_ALL & ~E_NOTICE & ~E_STRICT & ~E_DEPRECATED);
    }

    // shared config
    $GLOBALS['app_config'] = $config;

    Tracy\Debugger::enable(Tracy\Debugger::Development);
}
