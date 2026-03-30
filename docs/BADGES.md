# Achievement Badges

Visual badges for each achievement tier, displayed when achievements unlock.

## Badge Tiers

Each skill level has a unique badge design:

| Tier | Visual | Description |
|---|---|---|
| **Beginner** | Bronze Shield | Entry-level achievements |
| **Intermediate** | Silver Star | Mid-tier achievements |
| **Experienced** | Gold Trophy | Advanced achievements |
| **Master** | Platinum Crown | Expert-level achievements |
| **Impossible** | Diamond Artifact | Ultra-rare achievements |
| **Secret** | Mystery Box | Hidden until unlocked |

## Display Modes

### 1. Terminal Display (ASCII Art)

When an achievement unlocks, an ASCII art badge is displayed in the terminal:

```
    ╔═══════════╗
    ║   ◢█◣     ║
    ║  ◢███◣    ║
    ║ ◢█████◣   ║
    ║ ███████   ║
    ║  ◥███◤    ║
    ║   ⭐️      ║
    ║ BEGINNER  ║
    ╚═══════════╝
```

**Trigger:** Automatic on achievement unlock (via `stop.sh` hook)

### 2. iTerm2 Image Display

If you're using iTerm2 with `imgcat` installed, SVG badges are displayed as high-quality images inline in the terminal.

**Install imgcat:**
```bash
# macOS with iTerm2
brew install imgcat
# or manually download from: https://iterm2.com/utilities/imgcat
```

### 3. Manual Badge Viewing

View any achievement's badge at any time:

```bash
# Show badge for a specific achievement
bash ~/.claude/achievements/scripts/show-badge.sh power_user

# View all SVG badges
open ~/.claude/achievements/data/badge-templates/
```

## Badge Files

Badges are stored in `~/.claude/achievements/data/badge-templates/`:

```
badge-templates/
├── beginner.svg        # Bronze shield
├── intermediate.svg    # Silver star
├── experienced.svg     # Gold trophy
├── master.svg          # Platinum crown
├── impossible.svg      # Diamond artifact
├── secret.svg          # Mystery box
└── ascii-badges.sh     # ASCII art fallback script
```

## Customization

You can customize badge designs by editing the SVG files. Each badge is a standalone SVG with:

- **Gradients** for metallic/shiny effects
- **Filters** for shadows and glows
- **Consistent size** (120x120px viewBox)
- **Text labels** at the bottom

## Technical Details

**Display Logic:**
1. `stop.sh` detects achievement unlock
2. Reads achievement tier from `skill_level` field
3. Attempts to display SVG via `imgcat` (if available)
4. Falls back to ASCII art from `ascii-badges.sh`
5. Shows achievement name, description, and points

**ASCII Art Fallback:**
- Always works in any terminal
- Uses Unicode box-drawing characters
- Bash 3.2 compatible
- No external dependencies

## Future Enhancements

- [ ] Animated SVG badges (sparkle effects)
- [ ] Custom color schemes per category
- [ ] Badge export as PNG for social sharing
- [ ] Achievement wall HTML generator
- [ ] Community badge pack system

## Credits

Badge designs created for the Claude Cheevos achievement system.
SVG templates are CC0 (public domain) - customize freely!
