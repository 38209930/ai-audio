CREATE TABLE IF NOT EXISTS guest_trials (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  device_id VARCHAR(128) NOT NULL UNIQUE,
  guest_public_id VARCHAR(64) NOT NULL UNIQUE,
  trial_started_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  trial_expires_at TIMESTAMP NOT NULL,
  last_seen_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status VARCHAR(32) NOT NULL DEFAULT 'active',
  ip_hash CHAR(64) NULL,
  ip_mask VARCHAR(64) NULL,
  os_name VARCHAR(64) NULL,
  os_version VARCHAR(128) NULL,
  app_version VARCHAR(64) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_guest_public_id (guest_public_id),
  INDEX idx_guest_expires (trial_expires_at),
  INDEX idx_guest_last_seen (last_seen_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
