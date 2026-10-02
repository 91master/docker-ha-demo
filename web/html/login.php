<?php
declare(strict_types=1);
session_start();

$error = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $name = trim((string) ($_POST['username'] ?? ''));
    if ($name === '' || mb_strlen($name) > 32) {
        $error = 'username must be 1-32 characters';
    } else {
        try {
            $pdo = new PDO('mysql:host=mariadb;dbname=lb_logs;charset=utf8mb4', 'logger', 'logger123', [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_TIMEOUT => 3,
            ]);
            $pdo->prepare('INSERT INTO users (username) VALUES (?) ON DUPLICATE KEY UPDATE last_seen = NOW()')
                ->execute([$name]);
            $pdo->prepare('INSERT INTO login_logs (username, backend) VALUES (?, ?)')
                ->execute([$name, gethostname()]);
        } catch (Throwable $e) {
            // DB is optional for the demo: the session part still proves the point
            error_log('mariadb unavailable: ' . $e->getMessage());
        }

        $_SESSION['user'] = $name;
        header('Location: dashboard.php');
        exit;
    }
}
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>login &mdash; HA demo</title>
<style>
  body { font-family: ui-monospace, Menlo, Consolas, monospace; background:#12141a; color:#e6e6e6;
         margin:0; padding:2.5rem; }
  h1 { font-size:1.25rem; color:#ffd166; }
  form { margin-top:1.25rem; }
  input, button { font: inherit; padding:.5rem .7rem; border-radius:6px; border:1px solid #333a46;
                  background:#1a1d24; color:#e6e6e6; }
  button { background:#22577a; border-color:#2f6f9a; cursor:pointer; }
  .err { color:#ff6b6b; }
  .who { color:#06d6a0; }
</style>
</head>
<body>
<h1>login</h1>
<p class="who">this request was handled by <?= htmlspecialchars(gethostname()) ?></p>

<?php if ($error): ?><p class="err"><?= htmlspecialchars($error) ?></p><?php endif; ?>

<form method="post">
  <input name="username" placeholder="your name" autofocus>
  <button type="submit">log in</button>
</form>

<p><a href="index.php" style="color:#4cc9f0">back</a></p>
</body>
</html>
