# Edge Function Contract: `ai-try-on-gemini`

Flutter app now calls this function with:

```json
{
  "mannequinImageUrl": "https://...",
  "garmentImageUrl": "https://...",
  "prompt": "Dress the mannequin image..."
}
```

Function should return one of these:

```json
{ "resultImageUrl": "https://..." }
```

or

```json
{ "resultImageBase64": "<base64 png>" }
```

If both are returned, `resultImageUrl` is used directly.
