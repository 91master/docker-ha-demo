<?php
declare(strict_types=1);
session_start();

if (empty($_SESSION['user'])) {
    header('Location: login.php');
    exit;
}

$user        = (string) $_SESSION['user'];
$backend     = gethostname();
$loginCount  = null;
$dbBackends  = [];

try {
    $pdo = new PDO('mysql:host=mariadb;dbname=lb_logs;charset=utf8mb4', 'logger', 'logger123', [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_TIMEOUT => 3,
    ]);
    $stmt = $pdo->prepare('SELECT COUNT(*) FROM login_logs WHERE username = ?');
    $stmt->execute([$user]);
    $loginCount = (int) $stmt->fetchColumn();

    $dbBackends = $pdo->query('SELECT backend, COUNT(*) c FROM login_logs GROUP BY backend ORDER BY c DESC')
        ->fetchAll(PDO::FETCH_ASSOC);
} catch (Throwable $e) {
    error_log('mariadb unavailable: ' . $e->getMessage());
}
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>dashboard &mdash; HA demo</title>
<style>
  body { font-family: ui-monospace, Menlo, Consolas, monospace; background:#12141a; color:#e6e6e6;
         margin:0; padding:2.5rem; }
  h1 { font-size:1.25rem; color:#ffd166; }
  table { border-collapse:collapse; margin-top:1rem; }
  td, th { padding:.4rem .9rem; border-bottom:1px solid #262a33; text-align:left; }
  th { color:#8d93a1; font-weight:400; }
  b { color:#06d6a0; }
  a { color:#4cc9f0; }
</style>
</head>
<body>
<h1>hello, <?= htmlspecialchars($user) ?></h1>

<table>
  <tr><td>this request served by</td><td><b><?= htmlspecialchars($backend) ?></b></td></tr>
  <tr><td>your session lives in</td><td>redis (172.18.0.13) &mdash; shared by both backends</td></tr>
  <tr><td>logins recorded for you</td><td><b><?= $loginCount === null ? 'n/a (db down)' : $loginCount ?></b></td></tr>
</table>

<?php if ($dbBackends): ?>
<h2 style="font-size:1rem;color:#8d93a1;margin-top:1.75rem">who logged in where</h2>
<table>
  <tr><th>backend</th><th>logins</th></tr>
  <?php foreach ($dbBackends as $row): ?>
  <tr><td><?= htmlspecialchars((string) $row['backend']) ?></td><td><?= htmlspecialchars((string) $row['c']) ?></td></tr>
  <?php endforeach; ?>
</table>
<?php endif; ?>

<p style="margin-top:1.75rem">
  <a href="index.php">index</a> &nbsp; <a href="logout.php">logout</a>
</p>
<p style="color:#8d93a1;font-size:.85rem">
  Refresh this page several times: the backend alternates, you stay logged in,
  and the session id never changes.
</p>
</body>
</html>
