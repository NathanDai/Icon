---
name: quantumult-icon-assets
description: Create crisp Quantumult-ready icon PNG assets for this Icon repository. Use when adding or refreshing service icons such as OpenAI, Anthropic, or other proxy/app icons that should be sourced from SVG/vector artwork, rendered to 144x144 PNG with transparent background, saved under the repository's quantumult/ folder, and reflected in README raw links.
---

# Quantumult Icon Assets

## Workflow

Use vector artwork whenever possible. Do not upscale small PNGs unless the user explicitly asks for a pixel-preserving resize.

1. Identify a reliable SVG source for the icon, preferably an official brand asset or a maintained icon library page that exposes SVG, such as Bootstrap Icons.
2. Render the SVG to `quantumult/<name>.png` at `144x144` with an alpha channel.
3. Validate the output with `sips -g pixelWidth -g pixelHeight -g hasAlpha quantumult/<name>.png` and `file quantumult/<name>.png`.
4. Update `README.md` to list `quantumult/<name>.png`, using the matching preview path and the repository's existing raw GitHub URL format:

```text
https://raw.githubusercontent.com/<owner>/<repo>/<branch>/quantumult/<name>.png
```

5. Keep filenames lowercase, hyphenated or underscored only. Prefer short service names such as `openai.png` and `anthropic.png`.

## Script

Use `scripts/render_svg_icon.py` for the standard path:

```bash
python3 skills/quantumult-icon-assets/scripts/render_svg_icon.py \
  --source https://icons.getbootstrap.com/assets/icons/openai.svg \
  --out quantumult/openai.png
```

The script defaults to `144x144`, supports local SVG paths or `http(s)` URLs, renders with macOS `sips`, and validates the resulting PNG dimensions and alpha channel.

## Notes

- If `sips` renders a tiny icon in the corner, try the direct SVG URL rather than a copied HTML page or thumbnail file.
- If no vector source is available, tell the user the tradeoff before using a raster source; raster enlargement will usually look soft.
- Preserve existing user files and unrelated README entries.
