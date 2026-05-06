INSERT INTO app_versions (
  platform,
  version,
  force_update,
  download_url,
  notes_md
) VALUES
(
  'windows',
  '0.1.0',
  0,
  'https://github.com/38209930/ai-audio/releases',
  'Initial Windows client foundation with local transcription engine and cloud API scaffold.'
)
ON DUPLICATE KEY UPDATE
  force_update = VALUES(force_update),
  download_url = VALUES(download_url),
  notes_md = VALUES(notes_md);
