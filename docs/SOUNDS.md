# Achievement Sound System

Pavlovian conditioning for productivity! Play satisfying sounds when achievements unlock.

## Overview

The sound system plays tier-appropriate sounds when achievements unlock, providing instant auditory feedback that reinforces positive behavior. Like Powerwash Simulator's satisfying "ding!" when cleaning objects, these sounds make unlocking achievements more rewarding.

## Quick Start

Sounds are **enabled by default** after installation. Achievement unlocks will automatically play sounds.

```bash
# Configure sounds
bash ~/.claude/achievements/scripts/sound-config.sh show

# Disable if you prefer silence
bash ~/.claude/achievements/scripts/sound-config.sh disable

# Set volume
bash ~/.claude/achievements/scripts/sound-config.sh volume 50

# Set quiet hours (no sounds between 10pm-7am)
bash ~/.claude/achievements/scripts/sound-config.sh quiet-hours 22:00 07:00
```

## Sound Tiers

Each achievement tier plays a unique sound pattern:

| Tier | macOS System Sound | Pattern | Feel |
|---|---|---|---|
| **Beginner** | Tink | Single pleasant ding 🔔 | "Nice work!" - Pavlovian reward |
| **Intermediate** | Pop | Double beep | "Getting better!" |
| **Experienced** | Blow | Triple ascending | "Impressive!" |
| **Master** | Glass | Triumphant chime | "You're amazing!" |
| **Impossible** | Funk | Epic fanfare | "LEGENDARY!" |
| **Secret** | Submarine | Mystery sound | "Ooh, sneaky!" |
| **Rank** | Funk | Epic fanfare | "Milestone reached!" |

**Multiple achievements in one turn:** Plays the Master tier sound (fanfare) regardless of individual tiers.

## Pavlovian Design 🧠

The beginner tier sound is intentionally designed as a **Pavlovian conditioning tool**:

- **Pleasant tone:** Tink.aiff is friendly and non-jarring
- **Immediate feedback:** Plays the moment the achievement unlocks
- **Consistency:** Same sound for all beginner achievements
- **Positive reinforcement:** Builds association between Claude usage and reward

Over time, users subconsciously associate Claude Code with the pleasant "ding" sound, encouraging continued engagement. Just like Powerwash Simulator makes cleaning satisfying!

## Configuration

### Enable/Disable

```bash
# Turn sounds on
bash sound-config.sh enable

# Turn sounds off
bash sound-config.sh disable
```

### Volume Control

```bash
# Set volume (0-100)
bash sound-config.sh volume 75

# Mute (set to 0)
bash sound-config.sh volume 0
```

### Quiet Hours

Prevent sounds during specific hours (useful for late-night coding):

```bash
# No sounds between 10pm and 7am
bash sound-config.sh quiet-hours 22:00 07:00

# Clear quiet hours
bash sound-config.sh quiet-hours "" ""
```

### View Settings

```bash
bash sound-config.sh show

# Output:
# Achievement Sound Settings
# ==========================
#   Status:       ✓ Enabled
#   Sound Pack:   default
#   Volume:       75%
#   Quiet Hours:  22:00 - 07:00
```

## Custom Sound Packs

### Creating a Sound Pack

1. Create a directory in `~/.claude/achievements/data/sounds/`:

```bash
mkdir -p ~/.claude/achievements/data/sounds/8bit
```

2. Add WAV files for each tier:

```
8bit/
├── beginner.wav
├── intermediate.wav
├── experienced.wav
├── master.wav
├── impossible.wav
├── secret.wav
└── rank.wav
```

3. Activate the sound pack:

```bash
bash sound-config.sh pack 8bit
```

### Sound File Requirements

- **Format:** WAV (best compatibility)
- **Duration:** < 2 seconds (preferably < 1 second)
- **Size:** < 100KB per file
- **Sample Rate:** 44.1kHz or 48kHz
- **Channels:** Mono (saves space) or stereo
- **Volume:** Normalized to -3dB to prevent clipping

### Generating Sounds with Sox

Install [SoX](http://sox.sourceforge.net/) to create custom sounds:

```bash
# macOS
brew install sox

# Linux
sudo apt install sox

# Generate a pleasant 440Hz ding (beginner)
sox -n beginner.wav synth 0.15 sine 440 fade 0.01 0.15 0.05

# Generate double beep (intermediate)
sox -n intermediate.wav synth 0.1 sine 523 0.1 sine 0 0.1 sine 659

# Generate ascending arpeggio (experienced)
sox -n experienced.wav synth 0.1 sine 440 0.1 sine 554 0.1 sine 659

# Generate chord (master)
sox -n master.wav synth 0.3 sine 523 sine 659 sine 784 fade 0.01 0.3 0.1

# Generate epic fanfare (impossible)
sox -n impossible.wav synth 0.15 sine 880 0.15 sine 988 0.15 sine 1047 0.3 sine 1319 fade 0.01 0.8 0.15
```

## Platform Support

| Platform | Primary Player | Fallback |
|---|---|---|
| **macOS** | `afplay` | System sounds (Tink, Pop, etc.) |
| **Linux (PulseAudio)** | `paplay` | Terminal bell (`\a`) |
| **Linux (ALSA)** | `aplay` | Terminal bell |
| **Linux (FFmpeg)** | `ffplay` | Terminal bell |
| **WSL/Windows** | *Not yet implemented* | Silent |

## Testing Sounds

Test individual tier sounds:

```bash
# Test beginner sound (the Pavlovian ding!)
bash ~/.claude/achievements/scripts/play-sound.sh beginner

# Test all sounds in sequence
for tier in beginner intermediate experienced master impossible secret rank; do
    echo "Testing: $tier"
    bash play-sound.sh "$tier"
    sleep 1.5
done
```

## Technical Details

### Sound Playback Flow

1. Achievement unlocks in `stop.sh` hook
2. `stop.sh` calls `play-sound.sh <tier> <achievement-name>`
3. `play-sound.sh` checks if sounds are enabled
4. Checks quiet hours (if configured)
5. Attempts to play `sounds/<pack>/<tier>.wav`
6. Falls back to system sounds or terminal beeps
7. Plays asynchronously (doesn't block notifications)

### Configuration File

Stored in `~/.claude/achievements/sound-config.json`:

```json
{
  "enabled": true,
  "pack": "default",
  "volume": 75,
  "quiet_hours": {
    "start": "22:00",
    "end": "07:00"
  }
}
```

### Async Playback

Sounds play in the background using `&` to avoid blocking:
- Notification appears immediately
- Sound plays simultaneously
- No delay in user experience

## Community Sound Packs

Share and download custom sound packs from the community:

### Installing a Community Pack

```bash
# Clone a sound pack repository
git clone https://github.com/user/cheevos-sounds-zelda \
    ~/.claude/achievements/data/sounds/zelda

# Activate it
bash sound-config.sh pack zelda
```

### Popular Community Pack Ideas

- **8-Bit Retro:** Classic NES/SNES game sounds
- **Zelda:** Rupee collection, chest opening, puzzle solving
- **Pokemon:** Level up, evolution, badge earned
- **Portal 2:** Test chamber complete, cake acquisition
- **Minecraft:** Achievement unlocked, XP orb collection
- **Office:** Email sent, meeting joined, Slack notification
- **Nature:** Birds chirping, wind chimes, gentle bells

### Creating a Community Pack

1. Create sounds (7 WAV files)
2. Add a `CREDITS.txt` with attribution
3. Create GitHub repo: `cheevos-sounds-<name>`
4. Share the repo link for others to install

## Future Enhancements

- [ ] Windows/WSL sound playback support
- [ ] Text-to-speech mode (speak achievement names)
- [ ] Sound pack preview mode
- [ ] Download sound packs from URLs
- [ ] Combo sounds for multiple achievement unlocks
- [ ] Custom sounds per achievement (not just tier)
- [ ] Volume fade-in for gentle notifications

## Accessibility

**For Hearing-Impaired Users:**
- Visual notifications remain even with sounds disabled
- ASCII badge display provides visual feedback
- Desktop notifications show achievement details

**For Neurodivergent Users:**
- Disable sudden loud sounds via volume control
- Quiet hours prevent unexpected notifications
- Sounds can be completely disabled

**For Visual Impairment:**
- Future: TTS mode will speak achievement names aloud
- Sounds provide alternative feedback channel

## Psychology of Sound Feedback

**Why sound works for gamification:**
- **Instant gratification:** Immediate reward for action
- **Classical conditioning:** Sound becomes associated with success
- **Dopamine trigger:** Pleasant sounds activate reward pathways
- **Memory reinforcement:** Audio + visual creates stronger memories
- **Habit formation:** Consistent feedback builds routine

The "ding" sound becomes Pavlovian over time - users start to crave it, driving engagement.

## Credits

Default sound playback uses macOS system sounds:
- Tink, Pop, Blow, Glass, Funk, Submarine (Apple Inc.)
- Terminal bell (standard UNIX)

Sound system inspired by:
- Powerwash Simulator (satisfying cleaning sounds)
- Duolingo (streak notifications)
- Gaming achievement systems (Xbox, PlayStation, Steam)
