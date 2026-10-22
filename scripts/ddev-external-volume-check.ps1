# Checks the DDEV features that depend on bind mounts and Mutagen, for one project on native Windows.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File ddev-external-volume-check.ps1 -Dir D:\workspace\proj -Name proj1
#   -Dir may be a plain directory, a junction, or a symlink; it needs a public\index.php docroot.
# Configures the project (php, docroot public, Mutagen, MariaDB), then runs: start, HTTP status, snapshot,
# snapshot restore, export-db with a file check, import-db, the /mnt/ddev_config listing, mutagen-diagnose, and
# a stop and start with DDEV_DEBUG to count session recreates (0 expected). Stops the project at the end.
# Delete it afterwards with: ddev delete -Oy <Name>. Remove a link with: cmd /c rmdir <link>
param([Parameter(Mandatory)][string]$Dir, [Parameter(Mandatory)][string]$Name)
$ErrorActionPreference = "SilentlyContinue"
$env:DDEV_NO_INSTRUMENTATION = "true"
function L($x) { $x | % { "$_" } | ? { $_.Trim() } }
Set-Location $Dir
ddev config --project-name=$Name --project-type=php --docroot=public --performance-mode=mutagen 2>&1 | Out-Null
"== $Dir"
L (ddev start 2>&1 | Select-Object -Last 1)
L (ddev mutagen st -l 2>&1 | Select-String "URL:" | Select-Object -First 1)
"http: " + (curl.exe -sk -o NUL -w "%{http_code}" (ddev describe -j | ConvertFrom-Json).raw.primary_url)
ddev mysql -e "create table if not exists t(a int); insert into t values (42);" 2>&1 | Out-Null
"snapshot:"; L (ddev snapshot --name s1 2>&1 | Select-Object -Last 1)
"export-db:"; Remove-Item dump.sql.gz
L (ddev export-db --file=dump.sql.gz 2>&1 | Select-Object -Last 1)
"dump exists: " + (Test-Path dump.sql.gz) + ", bytes: " + (Get-Item dump.sql.gz).Length
"import-db:"; L (ddev import-db --file=dump.sql.gz 2>&1 | Select-Object -Last 1)
"restore:"; L (ddev snapshot restore s1 2>&1 | Select-Object -Last 1)
"/mnt/ddev_config (empty means Docker can't read this drive):"; L (ddev exec "ls /mnt/ddev_config | head -2" 2>&1)
"diagnose:"; L (ddev utility mutagen-diagnose 2>&1 | Select-String "No issues|⚠")
ddev stop 2>&1 | Out-Null
$env:DDEV_DEBUG = "true"
"restart recreate lines: " + @(ddev start 2>&1 | Select-String "does not sync|incompatible").Count
$env:DDEV_DEBUG = ""
ddev stop 2>&1 | Out-Null
