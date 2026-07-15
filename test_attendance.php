<?php
require 'c:/xampp/htdocs/HiTECH-Owner/api/config.php';

$_GET['type'] = 'attendance';
$_GET['start_date'] = '2026-05-05';
$_SERVER['REQUEST_METHOD'] = 'GET';

// Mock checkAuth to avoid session
function checkAuth($roles = []) {
    return [
        'user_id' => 10, // Assuming 10 is a DSE user ID
        'role' => 'dse'
    ];
}

require 'c:/xampp/htdocs/HiTECH-Owner/api/tracking.php';
?>
