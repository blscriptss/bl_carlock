CREATE TABLE IF NOT EXISTS `vehicle_keys` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `citizenid` VARCHAR(50) NOT NULL,  -- or identifier/steam ID depending on your framework
  `plate` VARCHAR(20) NOT NULL,
  `key_owner` BOOLEAN DEFAULT TRUE,  -- whether this is the original key or a copy
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_citizenid` (`citizenid`),
  INDEX `idx_plate` (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
