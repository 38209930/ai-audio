# Database

MySQL migrations for the commercial cloud API.

## Apply

```bash
mysql -u root -p ai_audio < db/migrations/001_base_schema.sql
mysql -u root -p ai_audio < db/migrations/002_seed_model_catalog.sql
```

## Privacy Requirements

- Use hashes for lookup fields.
- Use masked fields for admin display.
- Encrypt original phone/IP only if operationally required.
- Never store user LLM API keys in MySQL.

