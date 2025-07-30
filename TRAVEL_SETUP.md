# Quick Travel Setup Guide

This is your cheat sheet for the Flag Transfer System when traveling. Keep this handy!

## 🧳 Before Leaving Home

1. **Transfer your flag to laptop:**
   ```bash
   ./scripts/transfer_flag.sh localhost
   ```
   That's it! This single command will:
   - Shutdown your Pi safely
   - Copy all your data to laptop
   - Transfer the "active flag" 
   - Start your laptop deployment

2. **Verify laptop is working:**
   ```bash
   curl http://localhost:3000/up
   ```

## ✈️ While Traveling

- **Access your app:** http://localhost:3000
- Use it normally - add data, make changes, etc.
- Your Pi is safely shutdown and won't start without the flag

## 🏠 When Returning Home

1. **Transfer your flag back to Pi:**
   ```bash
   ./scripts/transfer_flag.sh home.local
   ```
   This will:
   - Copy your travel data back to Pi
   - Transfer the flag back home
   - Shutdown laptop deployment
   - Start Pi deployment

2. **Verify Pi is working:**
   ```bash
   curl http://home.local:3000/up
   ```

## 🚨 Emergency Commands

**Check flag status:**
```bash
./scripts/transfer_flag.sh --status     # See where your flag is
```

**If transfer fails:**
```bash
./scripts/transfer_flag.sh --dry-run localhost    # Preview what would happen
```

**If something breaks:**
```bash
# Check deployment health
curl http://localhost:3000/up           # Laptop
curl http://home.local:3000/up          # Pi

# Check deployment logs
kamal logs -d local          # Laptop
kamal logs                   # Pi (when home)

# Force create flag (emergency only)
kamal app exec -d local --reuse "bin/rails flag:force_create[emergency]"
```

## 📁 File Locations to Remember

- **Transfer script:** `./scripts/transfer_flag.sh` (main command)
- **Flag file:** `storage/ACTIVE_FLAG` (in each deployment)
- **Backups:** `tmp/flag_transfer/` (transfer exports)
- **Documentation:** `FLAG_TRANSFER_GUIDE.md` (detailed guide)

## 💡 Pro Tips

- **Always check status first** - `./scripts/transfer_flag.sh --status`
- **Use dry-run when unsure** - `./scripts/transfer_flag.sh --dry-run localhost`
- **The flag follows your data** - Only one deployment can be active
- **Transfers are atomic** - Either they complete fully or rollback
- **Test at home first** - Practice the transfer process before traveling

## 🔄 The Mental Model

Think of it as **"transferring your digital flag"**:
- 🏠 Flag at home.local = Working from home
- 💻 Flag at localhost = Working while traveling  
- 🚫 No flag = App won't start (safety feature)
- ⚠️ Two flags = Something went wrong (check status)

---

**Need help?** See `FLAG_TRANSFER_GUIDE.md` for detailed instructions and troubleshooting.