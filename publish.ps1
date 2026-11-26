$ErrorActionPreference = 'Stop'

# Ayarlar
$repoName      = 'abap-cloud-excel'
$branch        = 'main'
$commitMessage = 'Initial release: cloud-safe XLSX/CSV upload library'

# Arac kontrolu
foreach ($tool in @('git', 'gh')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool bulunamadi. Once kurup YENI bir PowerShell penceresi acin."
    }
}

gh auth status | Out-Host
$owner = gh api user --jq .login
if (-not $owner) {
    throw 'GitHub kullanici adi alinamadi. gh auth login calistirdiginizdan emin olun.'
}

Set-Location -Path $PSScriptRoot

# Repo yerel git kimligi (global ayari degistirmez)
$gitEmail = gh api user --jq .email
if (-not $gitEmail -or $gitEmail -eq 'null') {
    $gitEmail = "$owner@users.noreply.github.com"
}
git config user.name $owner
git config user.email $gitEmail

# Git baslat
if (-not (Test-Path '.git')) {
    git init -b $branch
}
else {
    Write-Host "Mevcut git repo kullaniliyor: $branch"
}

# Degisiklikleri commit et
git add -A
$staged = git diff --cached --name-only
if ($staged) {
    git commit -m $commitMessage
}
else {
    Write-Host 'Commit icin yeni degisiklik yok.'
}

# Repoyu olustur veya guncelle
$fullName = "$owner/$repoName"
$repoExists = $false
try {
    gh repo view $fullName 2>$null | Out-Null
    $repoExists = ($LASTEXITCODE -eq 0)
}
catch {
    $repoExists = $false
}

if ($repoExists) {
    Write-Host "Repo zaten var: $fullName"
    git remote set-url origin "https://github.com/$fullName.git"
    git push -u origin $branch
}
else {
    gh repo create $repoName --public --source=. --remote=origin --push
}

Write-Host ""
Write-Host "Bitti: https://github.com/$fullName"
