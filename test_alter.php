<?php
require 'c:/xampp/htdocs/HiTECH-Owner/api/config.php';
try {
    $pdo->exec("CREATE TABLE IF NOT EXISTS brochures (
        id INT AUTO_INCREMENT PRIMARY KEY,
        vehicle_name VARCHAR(100) NOT NULL UNIQUE,
        pdf_path VARCHAR(255) NOT NULL,
        uploaded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB");
    echo "Table brochures created successfully!\n";
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>
