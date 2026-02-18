# Tahoe 5 Web (MVP)

## Run Locally
From `/Users/urlocker/Downloads/Vibe1`:

```bash
cd app
python3 -m http.server 8080
```

Then open:
`http://localhost:8080`

## Implemented
- Classic Tahoe economy baseline (`$90` balance, `$10` bet step)
- Deal / Hold / Draw game loop
- Jacks or Better hand evaluation with legacy paytable
- Keyboard controls: `Enter`, `1-5`, arrows, `S`, `H`, `Esc`
- Touch controls for hold/bet/deal
- Help dialog and sound toggle
- Emergency loan behavior with taunt messaging
