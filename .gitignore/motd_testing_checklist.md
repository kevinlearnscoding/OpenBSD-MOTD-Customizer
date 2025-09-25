# MOTD Script VM Testing Checklist

## ✅ Pre-Run Setup
- [ ] Spin up a **fresh OpenBSD VM** (minimal install).  
- [ ] Create both a **root user** and a **normal user** for testing.  
- [ ] Make sure **pkg mirrors are working** (sometimes OpenBSD pkg mirrors need an updated `/etc/installurl`).  

## 🧪 Script Testing
1. **Run as root**  
   - [ ] Confirm system-wide install works (`/etc/motd`, `/etc/profile`, `/usr/local/bin/rc.motd_openbsd`).  
   - [ ] Check backup is created only once (`/etc/motd.backup`).  

2. **Run as normal user**  
   - [ ] Confirm user-only install works (`~/.motd`, `~/.profile`, `~/.motd_openbsd`).  
   - [ ] Ensure system-wide MOTD is unaffected.  

3. **Dependencies**  
   - [ ] Test case: **all dependencies installed** (script should skip pkg_add prompts).  
   - [ ] Test case: **missing figlet and curl** (should offer `pkg_add figlet curl`).  
   - [ ] Test case: **missing lolcat** (should prompt to build or exit).  
   - [ ] Test case: **missing git** when trying to build lolcat (should prompt for pkg_add git).  

4. **lolcat build**  
   - [ ] Accept “build lolcat for me” → ensure it clones, compiles, installs, and resumes script.  
   - [ ] Decline → ensure script exits gracefully.  

## 🎨 MOTD Functionality
- [ ] Verify **banner text** shows correctly in figlet output.  
- [ ] Verify **font rotation** works across logins (and skips missing fonts gracefully).  
- [ ] Test a case where one font is removed → ensure script warns and continues with next.  
- [ ] Check **divider, hostname, uptime, memory, disk** all show expected values.  
- [ ] Test **weather with manual city** (e.g., `Paris`).  
- [ ] Test **weather with auto-locate** (confirm it works or fails gracefully).  

## ⚙️ Edge Cases
- [ ] Run script twice → verify backup not overwritten and script appends to profile only once.  
- [ ] Delete `/tmp/motd_font_index` → ensure script regenerates correctly.  
- [ ] Corrupt `/tmp/motd_font_index` (e.g., put “999”) → ensure script wraps safely to valid index.  
- [ ] Disable network → check weather gracefully shows `(unavailable)`.  

## 📝 Post-Test
- [ ] Confirm MOTD shows up on **SSH login** as well as local tty login.  
- [ ] Push working script to **GitHub** with README + instructions.  
- [ ] Tag current state as **v1.0** before shelving for future improvements.  
