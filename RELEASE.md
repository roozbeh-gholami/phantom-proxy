# How to Create a Release

This guide explains how to create a release for phantom-proxy, which enables users to use the automated installation scripts.

## Prerequisites

- Push all your code to the `main` branch
- Ensure the code builds successfully
- GitHub Actions workflows are set up (they will build binaries automatically)

## Steps to Create a Release

### 1. Create and Push a Tag

```bash
# Make sure you're on the main branch and up to date
git checkout main
git pull

# Create a version tag (use semantic versioning)
git tag -a v1.0.0 -m "Release v1.0.0"

# Push the tag to GitHub
git push origin v1.0.0
```

### 2. Create GitHub Release

1. Go to your repository: https://github.com/roozbeh-gholami/phantom-proxy
2. Click on "Releases" on the right sidebar
3. Click "Create a new release"
4. Select the tag you just created (v1.0.0)
5. Set the release title: "v1.0.0"
6. Add release notes describing what's new
7. If GitHub Actions built binaries, they will be attached automatically
8. Click "Publish release"

### 3. Manual Binary Upload (if needed)

If you don't have GitHub Actions set up, you can build and upload binaries manually:

```bash
# Build for different platforms
GOOS=linux GOARCH=amd64 go build -o phantom-proxy_linux_amd64 ./cmd
GOOS=linux GOARCH=arm64 go build -o phantom-proxy_linux_arm64 ./cmd
GOOS=darwin GOARCH=amd64 go build -o phantom-proxy_darwin_amd64 ./cmd
GOOS=darwin GOARCH=arm64 go build -o phantom-proxy_darwin_arm64 ./cmd
GOOS=windows GOARCH=amd64 go build -o phantom-proxy_windows_amd64.exe ./cmd
```

Then attach these binaries to your GitHub release.

## Automated Build with GitHub Actions

The repository includes GitHub Actions workflows (`.github/workflows/build.yml`) that automatically:
- Build binaries for all platforms
- Attach them to the release
- Run on tag push

Make sure the workflow file is committed and pushed before creating a tag.

## After Creating Release

Once the release is created, users can install phantom-proxy with:

**Linux/macOS:**
```bash
curl -fsSL https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/install.sh | sudo bash
```

**Windows:**
```powershell
iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/roozbeh-gholami/phantom-proxy/master/install.ps1'))
```

## Updating to a New Version

To release a new version:
1. Update code
2. Commit changes
3. Create new tag (e.g., v1.1.0)
4. Push tag
5. Create new GitHub release
