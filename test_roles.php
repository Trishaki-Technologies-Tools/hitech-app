<?php
require 'c:/xampp/htdocs/HiTECH-Owner/api/config.php';

$stmt = $pdo->query("SELECT id, role, name FROM users LIMIT 10");
print_r($stmt->fetchAll());
?>
