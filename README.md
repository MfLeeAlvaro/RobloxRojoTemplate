# Trainyourslave

A tower defense/auto-battler game built with Rojo and React-Roblox.

## 🎮 Game Overview

**Trainyourslave** is a Roblox tower defense game where players:
- Place helpers on a grid-based island
- Purchase units from a shop system
- Start waves of enemies that spawn and fight helpers
- Merge helpers to upgrade them (3 same units → 1 upgraded unit)
- Earn coins from combat and passive generation
- Survive waves with increasing difficulty

## 📁 Project Structure

The project uses a clean, organized folder structure:

```
src/
├── ServerScriptService/
│   ├── Core/              # Core game systems (waves, combat)
│   ├── Helpers/           # Helper-related systems
│   ├── Enemies/          # Enemy-related systems
│   ├── Economy/          # Economy and coin systems
│   ├── Special/          # Special abilities
│   └── Utils/            # Utility scripts
├── StarterPlayer/        # Client scripts
├── ReplicatedStorage/    # Shared code and UI (React)
└── ServerStorage/        # Templates and assets
```

## 🚀 Getting Started

### Prerequisites
- [Rojo](https://rojo.space/docs/installation) 7.7.0+
- [Aftman](https://github.com/LPGhatguy/aftman) (for tool management)
- Roblox Studio

### Setup

1. **Install dependencies:**
   ```bash
   aftman install
   ```

2. **Build the place:**
   ```bash
   rojo build -o "Trainyourslave.rbxlx"
   ```

3. **Open in Studio and start Rojo server:**
   ```bash
   rojo serve
   ```

4. **Connect Rojo plugin in Studio** to sync files

## 📚 Documentation

### Architecture & Reference
- **[docs/PROJECT_ARCHITECTURE.md](docs/PROJECT_ARCHITECTURE.md)** - Complete system architecture
- **[docs/reference/FILE_STRUCTURE_REFERENCE.md](docs/reference/FILE_STRUCTURE_REFERENCE.md)** - File structure reference
- **[docs/reference/ATTRIBUTES_REFERENCE.md](docs/reference/ATTRIBUTES_REFERENCE.md)** - Attributes reference guide

### Cleanup & Refactoring
- **[docs/cleanup/CLEANUP_COMPLETED.md](docs/cleanup/CLEANUP_COMPLETED.md)** - Cleanup progress report
- **[docs/cleanup/CLEANUP_MERGE_COMPLETE.md](docs/cleanup/CLEANUP_MERGE_COMPLETE.md)** - Merge completion report
- **[docs/cleanup/CLEANUP_GUIDE.md](docs/cleanup/CLEANUP_GUIDE.md)** - Cleanup guide and instructions

### System Guides
- **[docs/systems/RACE_SYSTEM_DESIGN.md](docs/systems/RACE_SYSTEM_DESIGN.md)** - Race system design documentation
- **[docs/systems/RACE_SYSTEM_QUICK_START.md](docs/systems/RACE_SYSTEM_QUICK_START.md)** - Race system quick start guide
- **[docs/systems/WAVE_SYSTEM_SETUP_GUIDE.md](docs/systems/WAVE_SYSTEM_SETUP_GUIDE.md)** - Wave system setup guide
- **[docs/systems/PLACEMENT_PATCHES.md](docs/systems/PLACEMENT_PATCHES.md)** - Placement system patches and notes

## 🔧 Key Systems

- **Wave System** - Manages wave progression and enemy spawning
- **Combat System** - Real-time combat with grid constraints
- **Helper Placement** - Grid-based helper placement system
- **Blueprint System** - Persists helper configurations across waves
- **Merge System** - Upgrade helpers by merging 3 identical units
- **Shop System** - Purchase helpers from randomized shop
- **Economy System** - Coin collection and passive generation

## 📝 Recent Changes

See [CHANGELOG.md](CHANGELOG.md) for complete change history and [docs/cleanup/CLEANUP_MERGE_COMPLETE.md](docs/cleanup/CLEANUP_MERGE_COMPLETE.md) for details on recent refactoring:
- Files reorganized into logical folders
- Duplicate files merged
- Test files removed
- Improved code organization
- Documentation organized into `docs/` folder structure

## 🔗 Links

- [Rojo Documentation](https://rojo.space/docs)
- [React-Roblox](https://github.com/Roblox/react-roblox)