# BL CarLock V1

A customizable vehicle lock system for FiveM, supporting **QBCore**, **QBX**, and **ESX** frameworks.  
Allows players to lock/unlock vehicles via commands, keybinds, or targeting actions.

---

## ✨ Features
- **Framework Compatibility:** QBCore, QBX, ESX  
- **Inventory Compatibility:** qb-inventory, ox_inventory, QS Inventory  
- **Targeting Support:** qb-target, ox_target  
- **Lock/Unlock System:** Command or keybind (**L** by default)  
- **Key Sharing:** Give keys to other players  
- **Animations & Custom Sounds:** Optional locking/unlocking effects  
- **Lights Flashing:** Visual feedback when locking/unlocking  
- **Locale Support:** English, Spanish, French, German  

---

## 📹 Showcase Video
[▶ Watch Showcase](https://youtu.be/l4YdAFpuwQg?si=6bBddJANpcpE_MQD)

---

## 📦 Installation

### 1. Download the Resource
Clone or download the latest release:
```bash
git clone https://github.com/blscriptss/bl_carlock_v1.git
```

### 2. Install Required Dependency
This script requires **bl_lib**.
This script requires **InteractSound**.
1. Download or clone [bl_lib](https://github.com/blscriptss/bl_lib).
   Download or clone [interact-sound](https://github.com/plunkettscott/interact-sound)
2. Place it in your `resources/[bl]` folder.  
3. Add to `server.cfg` **before** `bl_carlock`:
```
ensure bl_lib
ensure InteractSound
```

### 3. Import SQL
This script will **stop** if the `vehicle_keys` table is missing.  
1. Open your database in phpMyAdmin or HeidiSQL.  
2. Import `main.sql` from the `bl_carlock` folder.

### 4. Add to server.cfg
```
ensure bl_carlock
```

---

## ⚙️ Configuration
Edit `config/config.lua`:
```lua
Config.Framework = "qbcore"  -- qbcore, qbx, or esx
Config.Inventory = "qb"      -- qb, ox, or qs
Config.Target    = "ox"      -- ox or qb
```

Additional options:
- Change commands and keybinds  
- Set lock distance and key requirements  
- Toggle animations and sounds  
- Enable debug mode  

---

## 🛠 Usage
- `/lock` — Lock/Unlock vehicle  
- **L** — Default keybind to lock/unlock    

With targeting (qb-target / ox_target):
- **Lock Vehicle**  
- **Unlock Vehicle**  
- **Give Vehicle Key**  

---

## 📄 License
Licensed under the **MIT License** — free to use, modify, and share with credit.

---

## 📢 Support
- Open a GitHub issue  
- Join our Discord: [discord.gg/9fuJWEGSmK](https://discord.gg/9fuJWEGSmK)  
- Ask in FiveM community forums  

---

## 📜 Changelog
### v1.2.0 (2025-11-07)
- Added **custom InteractSound support** for lock/unlock sounds  
- Enhanced **Discord logging** with vehicle plate and player name  
- Added **Standalone compatibility improvements**  
- Optimized **framework detection** (QBCore, QBX, ESX)  
- Added New **key item system** (now handled via dealerships)  
