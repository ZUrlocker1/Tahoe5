# Versions

- `v1.0` snapshot path: `/Users/urlocker/Downloads/Vibe1/versions/v1.0/app`
- `v1.1` snapshot path: `/Users/urlocker/Downloads/Vibe1/versions/v1.1/app`
- `v1.2` snapshot path: `/Users/urlocker/Downloads/Vibe1/versions/v1.2/app`
- Updated: 2026-02-12

Restore commands:

```bash
# Restore v1.0
rsync -a --delete /Users/urlocker/Downloads/Vibe1/versions/v1.0/app/ /Users/urlocker/Downloads/Vibe1/app/

# Restore v1.1
rsync -a --delete /Users/urlocker/Downloads/Vibe1/versions/v1.1/app/ /Users/urlocker/Downloads/Vibe1/app/

# Restore v1.2
rsync -a --delete /Users/urlocker/Downloads/Vibe1/versions/v1.2/app/ /Users/urlocker/Downloads/Vibe1/app/
```
