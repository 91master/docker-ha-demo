<?php
/**
 * Backend identification for the HA demo.
 *
 * WRONG ways (both were tried and paid for):
 *   $_SERVER['SERVER_ADDR']      -> nginx's IP, identical on every request
 *   gethostbyname(gethostname()) -> real DNS lookup that hangs 5-30s, no record exists
 */
declare(strict_types=1);

session_start();

function backend_server(): string
{
    $name = gethostname();                       // web1 / web2, set via compose `hostname:`
    $map  = ['web1' => '172.18.0.11', 'web2' => '172.18.0.12'];
    return $name . ' (' . ($map[$name] ?? $name) . ')';
}

$user    = $_SESSION['user'] ?? null;
$backend = backend_server();
?>
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>nginx + keepalived HA demo</title>
<style>
  body { font-family: ui-monospace, Menlo, Consolas, monospace; background:#12141a; color:#e6e6e6;
         margin:0; padding:2.5rem; }
  h1 { font-size:1.25rem; margin:0 0 1.25rem; color:#ffd166; }
  table { border-collapse:collapse; margin-bottom:1.25rem; }
  td { padding:.4rem .9rem; border-bottom:1px solid #262a33; }
  td:first-child { color:#8d93a1; }
  b { color:#06d6a0; }
  a { color:#4cc9f0; text-decoration:none; margin-right:1rem; }
  .hint { color:#8d93a1; font-size:.85rem; }
</style>
</head>
<body>
<h1>nginx (L7+L4) + keepalived VIP &mdash; HA demo</h1>

<table>
  <tr><td>served by backend</td><td><b><?= htmlspecialchars($backend) ?></b></td></tr>
  <tr><td>fpm hostname</td><td><?= htmlspecialchars(gethostname()) ?></td></tr>
  <tr><td>session id</td><td><?= htmlspecialchars(session_id()) ?></td></tr>
  <tr><td>session user</td><td><?= $user ? htmlspecialchars($user) : '(not logged in)' ?></td></tr>
  <tr><td>session handler</td><td><?= htmlspecialchars((string) ini_get('session.save_handler')) ?>
      @ <?= htmlspecialchars((string) ini_get('session.save_path')) ?></td></tr>
  <tr><td>VIP this request arrived through</td><td>172.18.0.100</td></tr>
</table>

<p class="hint">Refresh a few times: the backend alternates (round-robin) while your login
survives &mdash; that is the Redis session store doing its job.</p>

<p><a href="login.php">login</a><a href="dashboard.php">dashboard</a><a href="logout.php">logout</a></p>
</body>
</html>
