<?php
require 'c:/xampp/htdocs/HiTECH-Owner/api/config.php';
$stmt = $pdo->query('DESCRIBE locations');
print_r($stmt->fetchAll(PDO::FETCH_ASSOC));
?>
