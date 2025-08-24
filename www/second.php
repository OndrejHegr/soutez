<?php
session_start();
require __DIR__ . '/../inc/bootstrap.php';

$userId = (int)($_SESSION['user_id'] ?? null);
$contestId = (int)($_SESSION['contest_id'] ?? null);
$clubId = (int)($_SESSION['club_id'] ?? null);

if (!$userId || !$contestId || !$clubId) {
    header('Location: index.php');
    exit;
}

header('Content-Type: text/html; charset=utf-8');

$allData = loadData($contestId);
$message = '';

$contestSettings = dibi::fetch('SELECT use_team_sizes, min_dancers, min_duration_sec, max_duration_sec, base_fee_czk
FROM contest
WHERE id = %i', $contestId);

$rules = dibi::fetchAll('
    SELECT age_id, style_id, level_id, fee_czk, min_duration_sec, max_duration_sec
    FROM contest_rules
    WHERE contest_id = %i
', $contestId);

$teamSizes = [];
if ($contestSettings->use_team_sizes) {
    $teamSizes = dibi::fetchAll('
        SELECT id, min_members, max_members, min_duration_sec, max_duration_sec
        FROM contest_team_size
        WHERE contest_id = %i
    ', $contestId);
}

$application = dibi::fetch('
    SELECT * FROM application 
    WHERE contest_id = %i AND leader_id = %i AND club_id = %i LIMIT 1', $contestId, $userId, $clubId);

if ($_SERVER['REQUEST_METHOD'] === 'POST')
{
    $title = $_POST['title'] ?? '';
    $ageId = (int)($_POST['age_id'] ?? 0);
    $styleId = (int)($_POST['style_id'] ?? 0);
    $levelId = (int)($_POST['level_id'] ?? 0);
    $appliedTeamSizeId = 0;
    $duration = trim($_POST['duration'] ?? '');
    $amount = (int)($_POST['amount'] ?? 0);

    $found = false;
    foreach ($allData as $row) {
        if ($row->age_id == $ageId && $row->style_id == $styleId && $row->level_id == $levelId) {
            $found = true;
            break;
        }
    }

    $lenValid = preg_match('/^\d{1,2}:\d{2}$/', $duration);
    $amountValid = $amount > 0;

    if (!$found) {
        $message = 'Neplatná volba kombinace kategorií.';
    } elseif (!$lenValid) {
        $message = 'Délka vystoupení musí být ve formátu MM:SS.';
    } elseif (!$amountValid) {
        $message = 'Počet soutěžících musí být větší než nula.';
    } else {
        list($minutes, $seconds) = explode(':', $duration);
        $duration_sec = ((int)$minutes) * 60 + ((int)$seconds);

        $rule = getContestRule($contestId, $ageId, $styleId, $levelId);
        $minDuration = $rule->min_duration_sec ?? null;
        $maxDuration = $rule->max_duration_sec ?? null;
        $fee = $rule->fee_czk ?? null;
        $teamRule = null;

        if (!$rule && $contestSettings->use_team_sizes) {
            $teamRule = getTeamSizeRule($contestId, $amount);
            if ($teamRule) {
                $minDuration = $teamRule->min_duration_sec ?? $minDuration;
                $maxDuration = $teamRule->max_duration_sec ?? $maxDuration;
                $appliedTeamSizeId = $teamRule['id'];
            }
        }

        $minDuration = $minDuration ?? $contestSettings->min_duration_sec;
        $maxDuration = $maxDuration ?? $contestSettings->max_duration_sec;
        $fee = $fee ?? $contestSettings->base_fee_czk;

        if ($duration_sec < $minDuration) {
            $message = "Délka vystoupení je příliš krátká. Minimálně: " . floor($minDuration / 60) . " minut.";
        } elseif ($duration_sec > $maxDuration) {
            $message = "Délka vystoupení je příliš dlouhá. Maximálně: " . floor($maxDuration / 60) . " minut.";
        } elseif ($amount < $contestSettings->min_dancers) {
            $message = "Minimální počet soutěžících je: {$contestSettings->min_dancers}.";
        } else {
            if (!$application) {
                dibi::query('
                    INSERT INTO application (contest_id, club_id, leader_id)
                    VALUES (%i, %i, %i)
                ', $contestId, $clubId, $userId);

                $applicationId = dibi::getInsertId();
            } else {
                $applicationId = $application->id;
            }

            if ($levelId === 0) $levelId = null;
            if ($appliedTeamSizeId === 0) $appliedTeamSizeId = null;

            dibi::query('
                INSERT INTO performance (contest_id, application_id, title, dancers_count, duration_sec, age_id, style_id, level_id, size_id, fee_czk)
                VALUES (%i, %i, %s, %i, %i, %i, %i, %i, %i, %i)
            ', $contestId, $applicationId, $title, $amount, $duration_sec, $ageId, $styleId, $levelId, $appliedTeamSizeId, $fee * $amount);

            if (!$application)
                $application = dibi::query('SELECT * FROM application WHERE id = %i', $applicationId)->fetch();

            $message = "Přihlášení bylo úspěšné.";
            header('Location: second.php');
        }
    }
}

$performances = [];
if ($application) {
    $performances = dibi::fetchAll('SELECT * FROM performance WHERE application_id = %i ORDER BY created DESC', $application->id);
}

?>
<!DOCTYPE html>
<html lang="cs">
<head>
    <meta charset="UTF-8" />
    <title>Přihlášení vystoupení</title>
</head>
<body>
<h1>Přihláška na soutěž</h1>

<p>Soutěž: <strong><?= dibi::fetchSingle('select title from contest where id = %i', $contestId) ?></strong></p>
<p>Klub: <strong><?= dibi::fetchSingle("select concat(name, ' ', city) from club where id = %i", $clubId) ?></strong></p>
<p><a href="index.php">Změnit soutěž/klub</a></p>

<h2>Přidat nové vystoupení</h2>

<?php if ($message): ?>
    <p><strong><?=htmlspecialchars($message)?></strong></p>
<?php endif; ?>

<form method="post" id="form">
    <label for="title">Název vystoupení:</label>
    <input type="text" id="title" name="title" required></input><br />

    <label for="age_id">Věková kategorie:</label>
    <select id="age_id" name="age_id" required></select><br />

    <label for="style_id">Tanec:</label>
    <select id="style_id" name="style_id" required disabled></select><br />

    <label for="level_id">Úroveň:</label>
    <select id="level_id" name="level_id" required disabled></select><br />

    <label for="duration">Délka vystoupení:</label>
    <!-- <input type="time" id="duration" name="duration" step="60" required><br /> -->
    <input type="text" id="duration" name="duration" placeholder="MM:SS" pattern="^\d{1,2}:\d{2}$" required><br />

    <label for="amount">Počet soutěžících:</label>
    <input type="number" id="amount" name="amount" min="1" max="99" step="1" required><br />

    <!-- Přidejte k formuláři pole pro nahrání hudby -->
    <label for="musicFileInput" id="musicFileLabel" style="display:none;">Hudební soubor:</label>
    <input type="file" id="musicFileInput" accept="audio/*" style="display:none;" />
    <p id="musicDurationDisplay"></p>
    <p id="validationMessage" style="color:red;"></p>
    <button type="submit" id="submitBtn" disabled>Přihlásit vystoupení</button>
</form>

<script>
    const allData = <?= json_encode($allData, JSON_UNESCAPED_UNICODE) ?>;

    const rulesSetup = {
        contestSettings: <?= json_encode($contestSettings, JSON_UNESCAPED_UNICODE) ?>,
        contestRules: <?= json_encode($rules, JSON_UNESCAPED_UNICODE) ?>,
        contestTeamSizes: <?= json_encode($teamSizes, JSON_UNESCAPED_UNICODE) ?>
    };

    const ageSelect = document.getElementById('age_id');
    const styleSelect = document.getElementById('style_id');
    const levelSelect = document.getElementById('level_id');
    const durationInput = document.getElementById('duration');
    const amountInput = document.getElementById('amount');
    const submitBtn = document.getElementById('submitBtn');
    const validationMessage = document.getElementById('validationMessage');

    function fillAges() {
        const ages = [...new Map(allData.map(i => [i.age_id, {id:i.age_id, title:i.age_title}])).values()];
        ageSelect.innerHTML = '<option value="">Vyber věk</option>';
        ages.forEach(a => ageSelect.appendChild(new Option(a.title, a.id)));
        ageSelect.disabled = false;
    }

    function fillStyles(ageId) {
        styleSelect.innerHTML = '<option value="">Vyber tanec</option>';
        levelSelect.innerHTML = '<option value="">Vyber úroveň</option>';
        levelSelect.disabled = true;
        submitBtn.disabled = true;
        validationMessage.textContent = '';
        if (!ageId) { styleSelect.disabled = true; return; }
        let styles = [...new Map(allData.filter(i => i.age_id == ageId).map(i => [i.style_id, {id:i.style_id, title:i.style_title}])).values()];
        styles.forEach(s => styleSelect.appendChild(new Option(s.title, s.id)));
        styleSelect.disabled = false;
    }

    function fillLevels(ageId, styleId) {
        levelSelect.innerHTML = '<option value="">Vyber úroveň</option>';
        submitBtn.disabled = true;
        validationMessage.textContent = '';
        if (!styleId) { levelSelect.disabled = true; return; }
        let levels = [...new Map(allData.filter(i => i.age_id == ageId && i.style_id == styleId).map(i => [i.level_id, {id:i.level_id, title:i.level_title}])).values()];
        levels.forEach(l => levelSelect.appendChild(new Option(l.title, l.id)));
        levelSelect.disabled = levels.length === 0;
        submitBtn.disabled = levels.length > 0;
    }

    function formatDuration(seconds) {
        const minutes = Math.floor(seconds / 60);
        const secs = seconds % 60;
        return `${minutes}:${secs.toString().padStart(2, '0')}`;
    }

    function validatePerformance(ageId, styleId, levelId, durationSec, amount) {
        function score(r) {
            return (r.age_id ? 1 : 0) + (r.style_id ? 1 : 0) + (r.level_id ? 1 : 0);
        }

        // Výchozí hodnoty z contestSettings
        let minDuration = rulesSetup.contestSettings.min_duration_sec;
        let maxDuration = rulesSetup.contestSettings.max_duration_sec;
        let minDancers = rulesSetup.contestSettings.min_dancers;

        // Pokud je zapnuto použití týmových velikostí, zkusíme najít pravidlo podle počtu tanečníků
        if (rulesSetup.contestSettings.use_team_sizes) {
            let teamRule = rulesSetup.contestTeamSizes.find(ts => {
                const maxMembers = ts.max_members ?? Infinity;
                return amount >= ts.min_members && amount <= maxMembers;
            });

            if (teamRule) {
                minDuration = teamRule.min_duration_sec ?? minDuration;
                maxDuration = teamRule.max_duration_sec ?? maxDuration;
            }
        }

        // Nalezneme pravidlo z contestRules podle věku, stylu a úrovně
        let candidates = rulesSetup.contestRules.filter(r =>
            (!r.age_id || r.age_id == ageId) &&
            (!r.style_id || r.style_id == styleId) &&
            (!r.level_id || r.level_id == levelId)
        );
        candidates.sort((a, b) => score(b) - score(a));
        let rule = candidates[0] || null;

        // Pokud pravidlo existuje, přepíšeme mu min/max duration na základě pravidel
        if (rule) {
            minDuration = rule.min_duration_sec ?? minDuration;
            maxDuration = rule.max_duration_sec ?? maxDuration;
        }

        // Validace délky vystoupení a počtu soutěžících
        if (durationSec < minDuration) return {valid:false, msg:`Minimální délka vystoupení je ${formatDuration(minDuration)}.`};
        if (durationSec > maxDuration) return {valid:false, msg:`Maximální délka vystoupení je ${formatDuration(maxDuration)}.`};
        if (amount < minDancers) return {valid:false, msg:`Minimální počet soutěžících je ${minDancers}.`};

        return {valid:true, msg:''};
    }

    function validateForm() {
        const ageId = ageSelect.value;
        const styleId = styleSelect.value;
        const levelId = levelSelect.value;
        const durationVal = durationInput.value;
        const dancersVal = parseInt(amountInput.value, 10);

        if (!ageId || !styleId || !durationVal || isNaN(dancersVal) || dancersVal < 1) {
            validationMessage.textContent = '';
            return false;
        }

        const timePattern = /^([0-5]?\d):([0-5]\d)$/;

        if (!timePattern.test(durationVal)) {
            validationMessage.textContent = 'Délka vystoupení není ve správném formátu MM:SS.';
            return false;
        }

        const parts = durationVal.split(':').map(Number);
        let durationSec;
        if(parts.length === 2) {
            const [minutes, seconds] = parts;
            durationSec = minutes * 60 + seconds;
        } else if(parts.length === 3) {
            const [hours, minutes, seconds] = parts;
            durationSec = hours * 3600 + minutes * 60 + seconds;
        } else {
            durationSec = 0; // nebo invalid
        }

        const result = validatePerformance(ageId, styleId, levelId, durationSec, dancersVal);

        if (!result.valid) {
            validationMessage.textContent = result.msg;
            return false;
        } else {
            validationMessage.textContent = '';
            return true;
        }
    }

    function updateSubmit() {
        submitBtn.disabled = !validateForm();
    }

    ageSelect.addEventListener('change', () => {
        fillStyles(ageSelect.value);
        levelSelect.innerHTML = '<option value="">Vyber úroveň</option>';
        levelSelect.disabled = true;
        validationMessage.textContent = '';
        updateSubmit();
    });

    styleSelect.addEventListener('change', () => {
        fillLevels(ageSelect.value, styleSelect.value);
        validationMessage.textContent = '';
        updateSubmit();
    });

    levelSelect.addEventListener('change', () => {
        validationMessage.textContent = '';
        updateSubmit();
    });

    durationInput.addEventListener('input', updateSubmit);
    amountInput.addEventListener('input', updateSubmit);

    fillAges();

    const musicFileInput = document.getElementById('musicFileInput');
    const musicFileLabel = document.getElementById('musicFileLabel');
    const musicDurationDisplay = document.getElementById('musicDurationDisplay');

    // Funkce pro zobrazení/skrývání nahrávání podle music_required
    function updateMusicRequirement() {
        let ageId = ageSelect.value;
        let styleId = styleSelect.value;
        if (!ageId || !styleId) {
            musicFileLabel.style.display = 'none';
            musicFileInput.style.display = 'none';
            return;
        }

        // Najdeme music_required z allData podle ageId a styleId
        let rec = allData.find(item => item.age_id == ageId && item.style_id == styleId);
        if (rec && rec.music_required == 1) {
            musicFileLabel.style.display = 'inline-block';
            musicFileInput.style.display = 'inline-block';
            musicFileInput.required = true;
        } else {
            musicFileLabel.style.display = 'none';
            musicFileInput.style.display = 'none';
            musicFileInput.required = false;
            // Vymažeme data pokud dříve byl povinný
            musicDurationDisplay.textContent = '';
        }
    }

    // Pokusíme se zjistit délku skladby po výběru souboru
    musicFileInput.addEventListener('change', () => {
        const file = musicFileInput.files[0];
        if (!file) {
            musicDurationDisplay.textContent = '';
            return;
        }

        const audio = new Audio();
        audio.src = URL.createObjectURL(file);
        audio.addEventListener('loadedmetadata', () => {
            const durationSec = Math.floor(audio.duration);
            const minutes = Math.floor(durationSec / 60).toString().padStart(2, '0');
            const seconds = (durationSec % 60).toString().padStart(2, '0');
            musicDurationDisplay.textContent = `Délka skladby: ${minutes}:${seconds}`;
            // Nastavíme délku vystoupení do pole typu time (HH:MM)
            durationInput.value = `00:${minutes}:${seconds}`.slice(3,8); // jen MM:SS část
            updateSubmit(); // spustíme validaci znovu
        });
    });

    // Zavoláme update při změně věku nebo stylu
    ageSelect.addEventListener('change', () => {
        fillStyles(ageSelect.value);
        levelSelect.innerHTML = '<option value="">Vyber úroveň</option>';
        levelSelect.disabled = true;
        updateMusicRequirement();
        updateSubmit();
    });

    styleSelect.addEventListener('change', () => {
        fillLevels(ageSelect.value, styleSelect.value);
        updateMusicRequirement();
        updateSubmit();
    });
</script>

<h2>Stávající vystoupení</h2>
<?php if(!$performances): ?>
    <p>Zatím nemáte žádná vystoupení.</p>
<?php else: ?>
    <ul>
        <?php foreach($performances as $perf): ?>
            <li><?=htmlspecialchars($perf->title)?> - <?=htmlspecialchars($perf->dancers_count)?> tanečníků, <?=floor($perf->duration_sec/60)?>:<?=str_pad($perf->duration_sec % 60, 2,'0', STR_PAD_LEFT)?></li>
        <?php endforeach; ?>
    </ul>
<?php endif; ?>
</body>
</html>