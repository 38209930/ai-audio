CREATE TABLE IF NOT EXISTS users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  public_id VARCHAR(64) NOT NULL UNIQUE,
  phone_hash CHAR(64) NOT NULL UNIQUE,
  phone_mask VARCHAR(32) NOT NULL,
  phone_ciphertext VARBINARY(512) NULL,
  status VARCHAR(32) NOT NULL DEFAULT 'active',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS sms_codes (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  phone_hash CHAR(64) NOT NULL,
  code_hash CHAR(64) NOT NULL,
  provider VARCHAR(32) NOT NULL,
  purpose VARCHAR(32) NOT NULL DEFAULT 'login',
  expires_at TIMESTAMP NOT NULL,
  consumed_at TIMESTAMP NULL,
  failed_attempts INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_sms_phone_created (phone_hash, created_at),
  INDEX idx_sms_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS login_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NULL,
  phone_hash CHAR(64) NULL,
  phone_mask VARCHAR(32) NULL,
  ip_hash CHAR(64) NOT NULL,
  ip_mask VARCHAR(64) NOT NULL,
  device_id VARCHAR(128) NULL,
  os_name VARCHAR(64) NULL,
  os_version VARCHAR(128) NULL,
  app_version VARCHAR(64) NULL,
  result VARCHAR(32) NOT NULL,
  reason VARCHAR(128) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_login_phone_created (phone_hash, created_at),
  INDEX idx_login_ip_created (ip_hash, created_at),
  INDEX idx_login_device_created (device_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS client_devices (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  user_id BIGINT UNSIGNED NULL,
  device_id VARCHAR(128) NOT NULL,
  os_name VARCHAR(64) NOT NULL,
  os_version VARCHAR(128) NULL,
  app_version VARCHAR(64) NULL,
  last_ip_hash CHAR(64) NULL,
  last_ip_mask VARCHAR(64) NULL,
  last_seen_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_device (device_id),
  INDEX idx_device_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS captcha_challenges (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  challenge_id VARCHAR(128) NOT NULL UNIQUE,
  phone_hash CHAR(64) NULL,
  ip_hash CHAR(64) NOT NULL,
  prompt VARCHAR(128) NOT NULL,
  answer_ciphertext VARBINARY(1024) NOT NULL,
  expires_at TIMESTAMP NOT NULL,
  consumed_at TIMESTAMP NULL,
  failed_attempts INT NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_captcha_ip_created (ip_hash, created_at),
  INDEX idx_captcha_expires (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS model_catalog (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  model_id VARCHAR(191) NOT NULL UNIQUE,
  display_name VARCHAR(191) NOT NULL,
  task VARCHAR(64) NOT NULL,
  license VARCHAR(64) NOT NULL,
  commercial_use VARCHAR(64) NOT NULL,
  manual_download_url TEXT NOT NULL,
  required_files JSON NOT NULL,
  recommended_hardware TEXT NULL,
  enabled TINYINT(1) NOT NULL DEFAULT 1,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS app_versions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  platform VARCHAR(32) NOT NULL,
  version VARCHAR(64) NOT NULL,
  force_update TINYINT(1) NOT NULL DEFAULT 0,
  download_url TEXT NOT NULL,
  notes_md MEDIUMTEXT NOT NULL,
  published_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uniq_platform_version (platform, version)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS abuse_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  event_type VARCHAR(64) NOT NULL,
  phone_hash CHAR(64) NULL,
  phone_mask VARCHAR(32) NULL,
  ip_hash CHAR(64) NOT NULL,
  ip_mask VARCHAR(64) NOT NULL,
  device_id VARCHAR(128) NULL,
  risk_score INT NOT NULL DEFAULT 0,
  reason VARCHAR(255) NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_abuse_ip_created (ip_hash, created_at),
  INDEX idx_abuse_phone_created (phone_hash, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

