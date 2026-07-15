<?php
require 'c:/xampp/htdocs/HiTECH-Owner/api/config.php';
$stmt = $pdo->query('DESCRIBE users');
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));
?>
