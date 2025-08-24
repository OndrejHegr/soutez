<?php
session_start();
require __DIR__ . '/../inc/bootstrap.php';

if (!isset($_SESSION['user_id'])) {
    $_SESSION['user_id'] = dibi::fetchSingle('SELECT id FROM person WHERE email = %s', 'admin@nasoutez.eu');
}

$performances = dibi::fetchAll("select
    p.id,
    c.title as contest_title, c.venue_date, c.deadline,
    concat(cb.name, ' ', cb.city) as club_title,
    cast(sum(IF(p.status in ('registered', 'presented'), 1, 0)) as unsigned) as performances,
    cast(sum(IF(p.status in ('registered', 'presented'), p.dancers_count, 0)) as unsigned) as contestants
from application a
join contest c on c.id = a.contest_id
join club cb on cb.id = a.club_id
join performance p on p.application_id = a.id
where a.leader_id = %i and c.venue_date >= curdate()
group by
    p.id,
    c.title,
    c.venue_date,
    c.deadline,
    cb.name,
    cb.city
order by c.venue_date, club_title", $_SESSION['user_id'] ?? 0);
?>
<!DOCTYPE html>
<html lang="cs">
<head>
    <meta charset="UTF-8" />
    <title>Přihlášení vystoupení</title>
</head>
<body>
<h1>Přehled přihlášek</h1>
<ul>
    <li><a href="index.php">Přihlášení na soutěž</a></li>
    <li><a href="third.php">Přehled přihlášek</a></li>
</ul>
<?php if(!$performances): ?>
    <p>Zatím nejste přihlášeni na žádnou soutěž.</p>
<?php else: ?>
    <ul>
        <?php
            foreach($performances as $perf)
                echo '<h3>' . $perf->contest_title . '</h3><p>Datum konání: ' . cz_date($perf->venue_date) . '</p><p>' . $perf->club_title . ' - ' . $perf->performances . ' vystoupení ('. $perf->contestants . ' soutěžících)</p>';
        ?>
    </ul>
<?php endif; ?>
</body>
</html>