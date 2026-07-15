<?php
require 'c:/xampp/htdocs/HiTECH-Owner/api/config.php';

$stmt = $pdo->query("DESCRIBE attendance");
print_r($stmt->fetchAll());
?>

