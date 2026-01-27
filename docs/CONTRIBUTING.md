# Contributing Guide

## Getting Started

### First Time Setup

If you're setting up the project for the first time:

1. **Clone the repository:**
   ```bash
   git clone https://github.com/MfLeeAlvaro/RobloxRojoTemplate.git
   cd RobloxRojoTemplate
   ```

2. **Checkout the Trainyourslave branch:**
   ```bash
   git checkout Trainyourslave
   ```

3. **Install dependencies:**
   ```bash
   aftman install
   ```

4. **Build the project:**
   ```bash
   rojo build -o "Trainyourslave.rbxlx"
   ```

---

## Updating Your Local Copy

### If you already have the repository cloned:

1. **Navigate to the project folder:**
   ```bash
   cd RobloxRojoTemplate
   ```

2. **Fetch the latest changes from GitHub:**
   ```bash
   git fetch origin
   ```

3. **Switch to the Trainyourslave branch (if not already on it):**
   ```bash
   git checkout Trainyourslave
   ```

4. **Pull the latest changes:**
   ```bash
   git pull origin Trainyourslave
   ```

### If you're already on the Trainyourslave branch:

Simply pull the latest changes:
```bash
git pull origin Trainyourslave
```

---

## Common Scenarios

### Scenario 1: Fresh Clone
```bash
git clone https://github.com/MfLeeAlvaro/RobloxRojoTemplate.git
cd RobloxRojoTemplate
git checkout Trainyourslave
```

### Scenario 2: Already Have Repo, Need to Switch Branch
```bash
cd RobloxRojoTemplate
git fetch origin
git checkout Trainyourslave
git pull origin Trainyourslave
```

### Scenario 3: Already on Branch, Just Need Updates
```bash
git pull origin Trainyourslave
```

### Scenario 4: You Have Local Changes (Stash First)
If you have uncommitted changes, stash them first:
```bash
git stash                    # Save your changes temporarily
git pull origin Trainyourslave
git stash pop                # Restore your changes
```

---

## Troubleshooting

### "Branch not found" error
Make sure you've fetched the latest branches:
```bash
git fetch origin
git checkout Trainyourslave
```

### "Your local changes would be overwritten"
Stash your changes or commit them first:
```bash
git stash
git pull origin Trainyourslave
git stash pop
```

### "Already up to date"
Your local copy is already synchronized with the remote branch. No action needed!

---

## Verifying Your Setup

After updating, verify you have the latest structure:

```bash
# Check current branch
git branch

# Check latest commit
git log -1

# Verify docs folder exists
ls docs/
```

---

**Note**: Always make sure you're on the `Trainyourslave` branch before pulling updates!
