<?php
session_start();
require __DIR__ . '/../inc/bootstrap.php';
$message = '';

if (!isset($_SESSION['user_id'])) {
    $_SESSION['user_id'] = dibi::fetchSingle('SELECT id FROM person WHERE email = %s', 'admin@nasoutez.eu');
}

if (isset($_SESSION['contest_id'])) {
    $_SESSION = [];
    $_SESSION['user_id'] = dibi::fetchSingle('SELECT id FROM person WHERE email = %s', 'admin@nasoutez.eu');
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $contestId = (int)($_POST['contest_id'] ?? 0);
    $clubId = (int)($_POST['club_id'] ?? 0);

    // Základní validace, že existují a platí v DB
    $contestExists = dibi::query('SELECT COUNT(*) FROM contest WHERE id = %i', $contestId)->fetchSingle();
    $clubExists = dibi::query('SELECT COUNT(*) FROM club WHERE id = %i', $clubId)->fetchSingle();

    if (!$contestExists || !$clubExists) {
        $message = 'Vybraná soutěž nebo klub neexistuje.';
    } else {
        $_SESSION['contest_id'] = $contestId;
        $_SESSION['club_id'] = $clubId;
        header('Location: second.php');
        exit;
    }
}

// Načíst seznam soutěží a klubů pro formulář
$now = date('Y-m-d');
$contests = dibi::query('SELECT id, title FROM contest WHERE deadline >= %s ORDER BY id', $now)->fetchAll();
$clubs = dibi::query("SELECT id, concat(name, ' ', city) as name FROM club ORDER BY name")->fetchAll();
?>
<!DOCTYPE html>
<html lang="cs">
<head><meta charset="UTF-8" /><title>Vyber soutěž a klub</title></head>
<body>
<h1>Přihlášení na soutěž</h1>
<ul>
    <li><a href="index.php">Přihlášení na soutěž</a></li>
    <li><a href="third.php">Přehled přihlášek</a></li>
</ul>
<?php if ($message): ?>
    <p style="color:red;"><?=htmlspecialchars($message)?></p>
<?php endif; ?>
<form method="post">
    <label for="contest_id">Soutěž:</label>
    <select id="contest_id" name="contest_id" required>
        <option value="">Vyberte soutěž</option>
        <?php foreach ($contests as $c): ?>
            <option value="<?= $c->id ?>"><?= htmlspecialchars($c->title) ?></option>
        <?php endforeach; ?>
    </select><br/>

    <label for="club_id">Klub:</label>
    <select id="club_id" name="club_id" required>
        <option value="">Vyberte klub</option>
        <?php foreach ($clubs as $k): ?>
            <option value="<?= $k->id ?>"><?= htmlspecialchars($k->name) ?></option>
        <?php endforeach; ?>
    </select><br/>

    <button type="submit">Pokračovat</button>
</form>
</body>
</html>
