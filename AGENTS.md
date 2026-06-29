# AGENTS.md

## Project Scope

This repository stores icon and image assets. Keep changes focused on the requested asset files, `README.md`, and related project-local skill instructions.

## Icon Conventions

- Put Quantumult-specific icons in `quantumult/`.
- Prefer vector sources for new service icons. Render to PNG rather than enlarging small raster images.
- Use `144x144` PNG with an alpha channel for Quantumult icons.
- Keep filenames lowercase with letters, digits, hyphens, or underscores.
- After adding an icon, update `README.md` with the relative preview path and raw GitHub URL.

## Project Skill

Use the project-local skill at `skills/quantumult-icon-assets/` when adding or refreshing Quantumult icon assets.

Typical command:

```bash
python3 skills/quantumult-icon-assets/scripts/render_svg_icon.py \
  --source https://icons.getbootstrap.com/assets/icons/openai.svg \
  --out quantumult/openai.png
```

Validate image outputs with:

```bash
sips -g pixelWidth -g pixelHeight -g hasAlpha quantumult/<name>.png
file quantumult/<name>.png
```
