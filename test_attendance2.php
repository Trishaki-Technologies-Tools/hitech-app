<?php
require 'c:/xampp/htdocs/HiTECH-Owner/api/config.php';

$sessionUserId = 10;
$sessionRole = 'dse';
$startDate = '2026-05-05';
$endDate = '';
$userId = '';

$query = "SELECT a.*, u.name, u.role FROM attendance a JOIN users u ON a.user_id = u.id WHERE 1=1";
$params = [];

// Role-based visibility
if ($sessionRole === 'tl') {
    $query .= " AND (u.tl_id = ? OR a.user_id = ?)";
    $params[] = $sessionUserId;
    $params[] = $sessionUserId;
} elseif ($sessionRole === 'dse' || $sessionRole === 'cre') {
    $query .= " AND a.user_id = ?";
    $params[] = $sessionUserId;
}
// Owner and Manager see all

if ($startDate) {
    $query .= " AND DATE(a.login_time) >= ?";
    $params[] = $startDate;
}
if ($endDate) {
    $query .= " AND DATE(a.login_time) <= ?";
    $params[] = $endDate;
}
if ($userId) {
    $query .= " AND a.user_id = ?";
    $params[] = $userId;
}

$query .= " ORDER BY a.login_time DESC";

echo "Query: $query\n";
print_r($params);

try {
    $stmt = $pdo->prepare($query);
    $stmt->execute($params);
    print_r($stmt->fetchAll());
} catch (Exception $e) {
    echo "Error: " . $e->getMessage();
}
?>
