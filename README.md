# Rotasi Growlauncher - Enterprise Bot V3.1

Automated farming, harvesting, PNB (Place & Break), planting, and storage management script for Growtopia utilizing **Growlauncher Lua API**.

Based on API Documentation: [IniEyyy/Growlauncher-Documentation](https://github.com/IniEyyy/Growlauncher-Documentation)

---

## 🚀 Features

- **Multi-World Farm Rotation**: Seamlessly rotates across up to 7 designated farm worlds.
- **Isolated PNB System**: Performs safe vertical 3-block PNB in a dedicated break world when blocks accumulate.
- **Smart Harvesting & Planting**: Optimized O(1) tile blacklisting and shared tile caching for maximum performance.
- **Automatic Storage & Fast Drop**: Automatically drops farmed items into designated storage worlds when world tasks complete.
- **White-List Flee Protocol**: Detects stranger players in farm worlds, instantly escapes to storage, drops items, and triggers an emergency cooldown (2 minutes).
- **Auto Shop & Gems Management**: Automatically spends accumulated gems on Surgeon packs and World Locks.
- **Global Fault Tolerance**: Wrapped in `pcall` to ensure continuous stable execution without crashing on unexpected API errors.

---

## ⚙️ Configuration

Edit the `config` table in the script to match your setup:

```lua
local config = {
    pickaxe_id = 28, 
    owner_names = { "YOUR_MAIN_ACCOUNT" },
    farm_worlds = { "WORLD1", "WORLD2", "WORLD3", "WORLD4", "WORLD5", "WORLD6", "WORLD7" },
    break_world = "WORLD_BREAK",
    break_door  = "DOORBREAK",
    storage_world = "WORLD_STORAGE",
    storage_door  = "DOORSTORAGE",
    block_id = 1058,
    pnb_x = 3, 
    pnb_y = 1,
    target_planted_per_world = 2645,
    -- ... other delays and parameters
}
```

---

## 📌 Requirements

- [Growlauncher](https://github.com/IniEyyy/Growlauncher-Documentation) (Official Growtopia Lua Scripting Client)
- Sumneko Lua Language Server / VS Code extension (recommended for development)

---

## 📜 Credits & License

- **Author**: VaaaStore
- **Refactored & Optimized**: Raditya (V3.1 Enterprise)
- **API Reference**: [Growlauncher Documentation](https://github.com/IniEyyy/Growlauncher-Documentation)
