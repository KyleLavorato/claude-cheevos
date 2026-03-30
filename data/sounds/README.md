# Achievement Sounds

This directory contains sound packs for achievement unlock notifications.

## Sound Packs

Each sound pack is a directory containing WAV files named by achievement tier:

```
sounds/
├── default/
│   ├── beginner.wav
│   ├── intermediate.wav
│   ├── experienced.wav
│   ├── master.wav
│   ├── impossible.wav
│   ├── secret.wav
│   └── rank.wav
└── 8bit/
    └── ...
```

## Current Status

**Default sound pack uses system beeps** as a fallback until WAV files are added.

The `play-sound.sh` script will:
1. First try to play `<pack>/<tier>.wav` if it exists
2. Fall back to platform-specific system sounds (macOS) or terminal beeps

## Pavlovian Conditioning 🔔

The beginner tier uses a pleasant "ding" sound (Tink.aiff on macOS) designed for positive reinforcement - like Powerwash Simulator! Each tier has progressively more satisfying sounds:

| Tier | macOS Sound | Pattern | Feel |
|---|---|---|---|
| **Beginner** | Tink | Single pleasant ding | "Nice work!" |
| **Intermediate** | Pop | Double beep | "Getting better!" |
| **Experienced** | Blow | Triple ascending | "Impressive!" |
| **Master** | Glass | Triumphant chime | "You're amazing!" |
| **Impossible/Rank** | Funk | Epic fanfare | "LEGENDARY!" |
| **Secret** | Submarine | Mystery sound | "Ooh, sneaky!" |

## Adding Custom Sounds

### Option 1: Use Pre-Made WAV Files

Drop WAV files (mono or stereo, any sample rate) into a sound pack directory:

```bash
mkdir -p ~/.claude/achievements/data/sounds/my-pack
cp beginner.wav ~/.claude/achievements/data/sounds/my-pack/
cp intermediate.wav ~/.claude/achievements/data/sounds/my-pack/
# ... etc

bash ~/.claude/achievements/scripts/sound-config.sh pack my-pack
```

### Option 2: Generate Sounds Programmatically

Use `sox` (Sound eXchange) or `ffmpeg` to generate simple tones:

```bash
# Install sox
brew install sox  # macOS
sudo apt install sox  # Linux

# Generate a pleasant ding (440Hz for 0.15 seconds)
sox -n beginner.wav synth 0.15 sine 440 fade 0.01 0.15 0.05

# Generate ascending tones for experienced
sox -n experienced.wav synth 0.1 sine 440 0.1 sine 554 0.1 sine 659

# Generate a chord for master
sox -n master.wav synth 0.3 sine 523 sine 659 sine 784 fade 0.01 0.3 0.1
```

### Option 3: Community Sound Packs

Download community-created sound packs:

```bash
# Clone a sound pack repo
git clone https://github.com/user/cheevos-sounds-zelda ~/.claude/achievements/data/sounds/zelda

# Activate it
bash sound-config.sh pack zelda
```

## Sound Pack Structure

Each sound pack should include 7 files (or use fallback beeps for missing ones):

```
my-pack/
├── beginner.wav      # Simple, pleasant (< 1 second)
├── intermediate.wav  # A bit more interesting
├── experienced.wav   # Satisfying, ascending
├── master.wav        # Triumphant, memorable
├── impossible.wav    # Epic, rare
├── secret.wav        # Mysterious, unique
└── rank.wav          # Special, reserved for rank achievements
```

**Recommendations:**
- Keep files under 100KB each (< 2 seconds duration)
- Use 44.1kHz or 48kHz sample rate
- Mono is fine (saves space)
- WAV format for best compatibility
- Normalized to -3dB to prevent clipping

## Configuration

Control sound behavior:

```bash
# Enable/disable sounds
bash sound-config.sh enable
bash sound-config.sh disable

# Set volume (0-100)
bash sound-config.sh volume 50

# Change sound pack
bash sound-config.sh pack 8bit

# Set quiet hours (no sounds between 10pm-7am)
bash sound-config.sh quiet-hours 22:00 07:00

# View current settings
bash sound-config.sh show
```

## Testing Sounds

Test individual sounds:

```bash
# Test a specific tier sound
bash ~/.claude/achievements/scripts/play-sound.sh beginner

# Test all sounds in current pack
for tier in beginner intermediate experienced master impossible secret rank; do
    echo "Playing: $tier"
    bash play-sound.sh "$tier"
    sleep 1
done
```

## Platform Support

| Platform | Audio Player | Volume Control |
|---|---|---|
| macOS | afplay | System volume |
| Linux (PulseAudio) | paplay | Per-app volume |
| Linux (ALSA) | aplay | System volume |
| Linux (FFmpeg) | ffplay | Per-file volume |
| WSL/Windows | *Not yet implemented* | N/A |

## Future Enhancements

- [ ] Generate default WAV files instead of relying on system sounds
- [ ] Windows/WSL sound playback support
- [ ] Text-to-speech mode (achievement name spoken aloud)
- [ ] Sound pack marketplace
- [ ] Preview mode (play all sounds in a pack)
- [ ] Combo sounds (multiple achievements in one turn)

## License

Sound files you add to this directory should be:
- Public domain (CC0)
- Creative Commons licensed
- Your own original work
- Fair use (for fan sound packs, like Zelda or Pokemon)

Always include attribution in a `CREDITS.txt` file within each sound pack.
