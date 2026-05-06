# Security And Privacy Plan

## Data Minimization

The cloud API must not receive user videos, audio, transcripts, documents, or user-provided LLM API keys.

## Phone Storage

Store:

- `phone_hash`: HMAC-SHA256(phone, server secret)
- `phone_mask`: display value such as `138****8000`
- `phone_ciphertext`: optional encrypted original phone for SMS/account recovery use

Do not log plaintext phone numbers.

## IP Storage

Store:

- `ip_hash`: HMAC-SHA256(ip, server secret)
- `ip_mask`: IPv4 `/24` style or masked IPv6 prefix
- `ip_ciphertext`: optional encrypted original IP for abuse investigation

Do not show plaintext IP in admin views by default.

## SMS Anti-Abuse

Rate-limit dimensions:

- Phone
- IP
- Device ID
- Captcha session
- User-Agent fingerprint

Rules for first implementation:

- Same phone: 60-second cooldown.
- Same phone: hourly and daily cap.
- Same IP: hourly and daily cap.
- Same device: daily cap.
- Captcha failures lock challenge after threshold.
- SMS code failures lock code after threshold.

## Click-Character Captcha

Challenge requirements:

- Short TTL.
- One-time use.
- Random Chinese characters.
- Random layout and noise.
- Server validates click order and coordinate tolerance.
- Challenge state should not expose answer to client.

For v0.3 single-node OpenResty can use `lua_shared_dict`; multi-node deployment must move challenge and rate-limit state to Redis.

## API Keys

User LLM API keys:

- Stored only on the client.
- Protected by OS secure storage.
- Never sent to this product's cloud API.
- Hidden in logs and diagnostic exports.

## Legal Documents

Before v0.9 beta:

- Privacy policy.
- User agreement.
- Data collection notice.
- SMS terms and opt-out language if required by provider/region.

