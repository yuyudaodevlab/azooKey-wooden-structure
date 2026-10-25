param([Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$Commit)
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root
if ((git rev-parse HEAD) -ne $Commit) { throw 'Checkout does not match build SHA' }
foreach ($tool in @('swift', 'cargo', 'rustup', 'protoc', 'npm')) {
    if (!(Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Required tool is missing: $tool" }
}
$iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (!(Test-Path $iscc)) { throw 'Install Inno Setup 6 first' }
Set-Location (Join-Path $root 'windows')
function Get-Repository([string]$Url, [string]$Revision, [string]$Destination) {
    if (!(Test-Path "$Destination/.git")) {
        git init $Destination
        git -C $Destination remote add origin $Url
    }
    git -C $Destination fetch --depth 1 origin $Revision
    git -C $Destination checkout --detach $Revision
    if ((git -C $Destination rev-parse HEAD) -ne $Revision) { throw "Incorrect revision: $Destination" }
}
Get-Repository 'https://github.com/ensan-hcl/azooKey_dictionary_storage.git' 'b05798b43679c385ce2179fb746512d7643dfe12' 'server-swift/azooKey_dictionary_storage'
Get-Repository 'https://github.com/ensan-hcl/azooKey_emoji_dictionary_storage.git' '24e88dd14c27e333454ba15c7cc4c2b4a4dd9d34' 'server-swift/azooKey_emoji_dictionary_storage'
foreach ($backend in @(
    @{Name='cpu'; File='llama-b4846-bin-win-avx-x64.zip'},
    @{Name='cuda'; File='llama-b4846-bin-win-cuda-cu12.4-x64.zip'},
    @{Name='vulkan'; File='llama-b4846-bin-win-vulkan-x64.zip'}
)) {
    $zip = Join-Path $env:TEMP $backend.File
    Invoke-WebRequest "https://github.com/fkunn1326/llama.cpp/releases/download/b4846/$($backend.File)" -OutFile $zip
    Expand-Archive -LiteralPath $zip -DestinationPath "llama_$($backend.Name)" -Force
}
Copy-Item llama_cpu/llama.lib server-swift/llama.lib -Force
$modelHash = '501f605d088f5b988791a00ae19ed46985ed7c48144f364b2f3f1f951c9b2083'
if (!(Test-Path zenz.gguf) -or (Get-FileHash zenz.gguf -Algorithm SHA256).Hash.ToLowerInvariant() -ne $modelHash) {
    Invoke-WebRequest 'https://huggingface.co/Miwa-Keita/zenz-v3-small-gguf/resolve/d48369e21adb9f49903eb7c54be1a1d9723eb805/ggml-model-Q5_K_M.gguf' -OutFile zenz.gguf
}
if ((Get-FileHash zenz.gguf -Algorithm SHA256).Hash.ToLowerInvariant() -ne $modelHash) { throw 'Model checksum mismatch' }
# Swift 6.0.2 UCRT definitions compatible with newer Windows SDKs.
$moduleMap = Join-Path $env:SDKROOT 'usr/share/ucrt.modulemap'
if (!(Test-Path $moduleMap)) { throw 'SDKROOT must point to the Swift Windows SDK' }
Invoke-WebRequest 'https://gist.githubusercontent.com/fkunn1326/ef8be2217082302b291f2b8d4178194a/raw/c424968c250afcd5afa1131aea1329dc0744a7f9/ucrt.modulemap' -OutFile $moduleMap
Push-Location server-swift
try {
    # Keep large source lists out of Windows response-file argument escaping.
    # https://github.com/swiftlang/swift-driver/issues/1477
    # Use filelists even below the driver's default threshold; preserve Release/WMO.
    $swiftBuildArguments = @(
        '-c', 'release',
        '-Xswiftc', '-driver-filelist-threshold', '-Xswiftc', '0'
    )
    swift --version
    swift build @swiftBuildArguments
    $swiftBin = (swift build @swiftBuildArguments --show-bin-path | Select-Object -Last 1).Trim()
    Copy-Item (Join-Path $swiftBin 'azookey-server.lib') ../azookey-server.lib -Force
} finally { Pop-Location }
rustup target add i686-pc-windows-msvc
cargo build --locked --release -p azookey-windows -p azookey-server -p ui -p launcher
cargo build --locked --release -p azookey-windows --target i686-pc-windows-msvc
Push-Location frontend
try {
    npm ci
    npm run tauri build -- --no-bundle
} finally { Pop-Location }
# Stage in a fresh directory; do not include previous installers.
$stage = Join-Path $env:TEMP ("azookey-stage-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path "$stage/x86", "$stage/licenses" -Force | Out-Null
foreach ($file in @('ui.exe','azookey-server.exe','azookey_windows.dll','launcher.exe','frontend.exe')) {
    Copy-Item "target/release/$file" $stage
}
Copy-Item 'target/i686-pc-windows-msvc/release/azookey_windows.dll' "$stage/x86"
Copy-Item (Join-Path $swiftBin 'azookey-server.dll') $stage
Get-ChildItem $swiftBin -Directory -Filter '*.resources' | Copy-Item -Destination $stage -Recurse
$runtime = Join-Path $env:LOCALAPPDATA 'Programs/Swift/Runtimes/6.0.2/usr/bin'
if (!(Test-Path $runtime)) { throw "Swift 6.0.2 runtime not found: $runtime" }
Copy-Item "$runtime/*" $stage -Recurse
foreach ($backend in @('llama_cpu','llama_cuda','llama_vulkan')) { Copy-Item $backend $stage -Recurse }
Copy-Item 'server-swift/azooKey_dictionary_storage/Dictionary' $stage -Recurse
Copy-Item 'server-swift/azooKey_emoji_dictionary_storage/EmojiDictionary' $stage -Recurse
Copy-Item zenz.gguf $stage
Copy-Item LICENSE "$stage/licenses/azooKey-Windows-MIT.txt"
Copy-Item ../LICENSE "$stage/licenses/azooKey-wooden-structure-MIT.txt"
Copy-Item UPSTREAM.md "$stage/licenses/UPSTREAM.md"
Get-ChildItem server-swift/azooKey_dictionary_storage -File -Filter 'LICENSE*' | Copy-Item -Destination "$stage/licenses/dictionary-license.txt"
New-Item -ItemType Directory -Path ../installer -Force | Out-Null
& $iscc "/DSourceDir=$stage" "/DCommit=$Commit" "/O$root/installer" installer/Installer.iss
$output = Join-Path $root "installer/azooKey-wooden-structure-$Commit.exe"
if (!(Test-Path $output)) { throw 'Installer was not produced' }
Write-Host "Created $output"
