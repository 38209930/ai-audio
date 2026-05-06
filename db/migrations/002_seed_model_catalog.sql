INSERT INTO model_catalog (
  model_id,
  display_name,
  task,
  license,
  commercial_use,
  manual_download_url,
  required_files,
  recommended_hardware
) VALUES
(
  'Systran/faster-whisper-large-v3',
  'faster-whisper large-v3',
  'asr',
  'MIT',
  'allowed',
  'https://hf-mirror.com/Systran/faster-whisper-large-v3/tree/main',
  JSON_ARRAY('config.json', 'model.bin', 'preprocessor_config.json', 'tokenizer.json', 'vocabulary.json'),
  'NVIDIA GPU recommended; CPU possible but slow'
),
(
  'Systran/faster-whisper-medium',
  'faster-whisper medium',
  'asr',
  'MIT',
  'allowed',
  'https://hf-mirror.com/Systran/faster-whisper-medium/tree/main',
  JSON_ARRAY('config.json', 'model.bin', 'preprocessor_config.json', 'tokenizer.json', 'vocabulary.json'),
  'CPU or GPU'
)
ON DUPLICATE KEY UPDATE
  display_name = VALUES(display_name),
  task = VALUES(task),
  license = VALUES(license),
  commercial_use = VALUES(commercial_use),
  manual_download_url = VALUES(manual_download_url),
  required_files = VALUES(required_files),
  recommended_hardware = VALUES(recommended_hardware);

