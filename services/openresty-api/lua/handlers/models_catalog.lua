local res = require "lib.json_response"

res.ok({
  models = {
    {
      id = "Systran/faster-whisper-large-v3",
      displayName = "faster-whisper large-v3",
      task = "asr",
      license = "MIT",
      commercialUse = "allowed",
      manualDownloadUrl = "https://hf-mirror.com/Systran/faster-whisper-large-v3/tree/main",
      requiredFiles = {"config.json", "model.bin", "preprocessor_config.json", "tokenizer.json", "vocabulary.json"},
      recommendedHardware = "NVIDIA GPU recommended",
    },
    {
      id = "Systran/faster-whisper-medium",
      displayName = "faster-whisper medium",
      task = "asr",
      license = "MIT",
      commercialUse = "allowed",
      manualDownloadUrl = "https://hf-mirror.com/Systran/faster-whisper-medium/tree/main",
      requiredFiles = {"config.json", "model.bin", "preprocessor_config.json", "tokenizer.json", "vocabulary.json"},
      recommendedHardware = "CPU or GPU",
    },
  }
})

