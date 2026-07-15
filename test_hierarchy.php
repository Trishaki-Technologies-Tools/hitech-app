<?php
require 'c:/xampp/htdocs/HiTECH-Owner/api/config.php';
$stmt = $pdo->query("SELECT id, role, tl_id, manager_id FROM users");
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));
?>
