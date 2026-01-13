# How to Contribute to Empire Connect

Thank you for your interest in contributing to **Empire Connect**!  
This guide explains how to fork, develop, and submit improvements to the app.

---

## Step 1 – Log in to GitHub

You must be logged into GitHub to contribute.  
If you don’t have an account, create one at: https://github.com

---

## Step 2 – Go to the Empire Connect Repository

Open:
https://github.com/SaifMalik0162/Empire-iOS

---

## Step 3 – Fork the Repository

Click the **Fork** button in the top-right corner.  
This creates your own copy of the project.

---

## Step 4 – Clone Your Fork

```bash
git clone https://github.com/YOUR_USERNAME/Empire-iOS.git
cd Empire-iOS
```

---

## Step 5 – Sync with the Main Repository

Add the original Empire Connect repository as a remote:

```bash
git remote add upstream https://github.com/SaifMalik0162/Empire-iOS.git
git fetch upstream
git checkout main
git pull upstream main
```

Create a new branch for your work:

```bash
git checkout -b your-branch-name
```

---

## Step 6 – Make Your Changes

You can contribute by:
- Fixing bugs  
- Adding features  
- Improving UI  
- Improving documentation  
- Refactoring code  

Use **Xcode** to make changes.

---

## Step 7 – Commit Using Conventional Commits

Use clean, consistent commit messages.

### Format
```
<type>: <description>
```

### Examples
- `feat: add vehicle image slideshow`
- `fix: resolve save bug`
- `docs: update README`
- `chore: cleanup API service`

Commit your changes:

```bash
git add .
git commit -m "feat: add vehicle image slideshow"
```

---

## Step 8 – Push Your Branch

```bash
git push origin your-branch-name
```

---

## Step 9 – Open a Pull Request

1. Go to your fork on GitHub  
2. Click **Pull Requests → New Pull Request**  
3. Set:
   - **Base repository:** `SaifMalik0162/Empire-iOS`
   - **Base branch:** `main`
   - **Compare branch:** your branch  
4. Submit your PR with a clear description  

---

## Step 10 – Review Process

Your pull request will be reviewed.  
You may be asked to update your code — just push to the same branch.

---

## Tips for Contributing

- Keep PRs small
- Follow SwiftUI + MVVM patterns
- Avoid changes that break existing features or data
- Test before submitting

---

## Thank You

Every contribution helps build **Empire Connect** into a real platform for car culture.  
We appreciate your support 🚗
