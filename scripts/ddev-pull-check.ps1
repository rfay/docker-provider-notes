# Checks `ddev pull` with a local provider for one project on native Windows.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File ddev-pull-check.ps1 -Dir D:\workspace\proj -Name proj1
#   -Dir needs a public\index.php docroot. Uses ddev-pull-check-provider.yaml from this directory.
# Prepares ~\tmp\pullsrc (a dump of a table "pulled" and files\a.txt), configures the project with upload_dirs
# set to uploads, drops the table, runs `ddev pull localpull`, and prints whether the table and the file came back.
# Expected: "table after pull: pull-ok" and "file after pull: pull-file-ok". Stops the project at the end.
param([Parameter(Mandatory)][string]$Dir, [Parameter(Mandatory)][string]$Name)
$ErrorActionPreference = "SilentlyContinue"
$env:DDEV_NO_INSTRUMENTATION = "true"
function L($x) { $x | % { "$_" } | ? { $_.Trim() } }
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Dir
ddev config --project-name=$Name --project-type=php --docroot=public --performance-mode=mutagen --upload-dirs=uploads 2>&1 | Out-Null
New-Item -ItemType Directory -Force .ddev\providers, "$HOME\tmp\pullsrc\files" | Out-Null
Set-Content "$HOME\tmp\pullsrc\files\a.txt" "pull-file-ok"
Copy-Item "$here\ddev-pull-check-provider.yaml" .ddev\providers\localpull.yaml
L (ddev start 2>&1 | Select-Object -Last 1)
ddev mysql -e "drop table if exists pulled; create table pulled(v varchar(20)); insert into pulled values ('pull-ok');" 2>&1 | Out-Null
Remove-Item "$HOME\tmp\pullsrc\db.sql.gz"
ddev export-db --file="$HOME\tmp\pullsrc\db.sql.gz" 2>&1 | Out-Null
ddev mysql -e "drop table pulled;" 2>&1 | Out-Null
"pull:"; L (ddev pull localpull -y --skip-confirmation 2>&1 | Select-Object -Last 2)
"table after pull: " + (ddev mysql -N -e "select v from pulled" 2>&1)
"file after pull: " + (ddev exec "cat /var/www/html/public/uploads/a.txt" 2>&1)
ddev stop 2>&1 | Out-Null
