param(
    [switch]$KeepRemote
)

$ErrorActionPreference = 'Stop'

$vcsRoot = Split-Path $PSScriptRoot -Parent
$verificationRoot = Split-Path $vcsRoot -Parent
$workRoot = Split-Path $verificationRoot -Parent
$moduleRoot = Split-Path $workRoot -Parent
$runId = 'ADC_TOP_VCS_' + ([guid]::NewGuid().ToString('N'))
$remoteBase = '/home/zezhoux/Project/vcs_jobs'
$remoteJob = "$remoteBase/$runId"
$localResult = Join-Path $vcsRoot "results\$runId"

$sshExe = 'C:\Windows\System32\OpenSSH\ssh.exe'
$scpExe = 'C:\Windows\System32\OpenSSH\scp.exe'
$sshKey = 'C:\Users\Administrator\.ssh\codex_vmware_eda_ed25519'
$knownHosts = 'C:\Users\Administrator\.ssh\codex_vmware_eda_known_hosts'
$remote = 'zezhoux@192.168.66.128'
$commonArgs = @(
    '-i', $sshKey,
    '-o', 'IdentitiesOnly=yes',
    '-o', "UserKnownHostsFile=$knownHosts",
    '-o', 'StrictHostKeyChecking=yes'
)

if ($remoteJob -notmatch '^/home/zezhoux/Project/vcs_jobs/ADC_TOP_VCS_[0-9a-f]{32}$') {
    throw "Unsafe remote job path: $remoteJob"
}

$required = @(
    (Join-Path $moduleRoot 'rtl\ADC_RXD.v'),
    (Join-Path $moduleRoot 'rtl\ADI_JESD204\jesd204_rx.v'),
    (Join-Path $vcsRoot 'filelist.f'),
    (Join-Path $vcsRoot 'model\AC9810_MASTER.sv'),
    (Join-Path $vcsRoot 'tb\tb_adc_rxd_vcs.sv'),
    (Join-Path $vcsRoot 'patterns\afe0_i.hex'),
    (Join-Path $vcsRoot 'patterns\afe0_q.hex')
)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing VCS input: $path"
    }
}

New-Item -ItemType Directory -Force -Path $localResult | Out-Null
$transportLog = Join-Path $localResult 'transport.log'

try {
    & $sshExe @commonArgs $remote "mkdir -p '$remoteJob/rtl/ADI_JESD204' '$remoteJob/vcs' '$remoteJob/results'" 2>&1 |
        Tee-Object -FilePath $transportLog
    if ($LASTEXITCODE -ne 0) { throw 'Remote job creation failed' }

    & $scpExe @commonArgs (Join-Path $moduleRoot 'rtl\ADC_RXD.v') "$remote`:$remoteJob/rtl/" 2>&1 |
        Tee-Object -FilePath $transportLog -Append
    if ($LASTEXITCODE -ne 0) { throw 'ADC_RXD upload failed' }

    & $scpExe @commonArgs (Join-Path $moduleRoot 'rtl\ADI_JESD204\jesd204_rx.v') "$remote`:$remoteJob/rtl/ADI_JESD204/" 2>&1 |
        Tee-Object -FilePath $transportLog -Append
    if ($LASTEXITCODE -ne 0) { throw 'ADI source upload failed' }

    $vcsUploadSources = @(
        (Join-Path $vcsRoot 'model'),
        (Join-Path $vcsRoot 'tb'),
        (Join-Path $vcsRoot 'patterns'),
        (Join-Path $vcsRoot 'scripts'),
        (Join-Path $vcsRoot 'filelist.f')
    )
    & $scpExe @commonArgs -r @vcsUploadSources "$remote`:$remoteJob/vcs/" 2>&1 |
        Tee-Object -FilePath $transportLog -Append
    if ($LASTEXITCODE -ne 0) { throw 'VCS workspace upload failed' }

    & $sshExe @commonArgs $remote "bash '$remoteJob/vcs/scripts/run_vcs.sh'" 2>&1 |
        Tee-Object -FilePath $transportLog -Append
    if ($LASTEXITCODE -ne 0) { throw 'Remote VCS run failed' }

    & $scpExe @commonArgs -r "$remote`:$remoteJob/results/." $localResult 2>&1 |
        Tee-Object -FilePath $transportLog -Append
    if ($LASTEXITCODE -ne 0) { throw 'VCS result retrieval failed' }

    Write-Host "VCS_LOCAL_RESULT=$localResult"
    Write-Host "VCS_REMOTE_JOB=$remoteJob"
    Write-Host 'VCS_SMOKE_PASS'
}
finally {
    if (-not $KeepRemote) {
        & $sshExe @commonArgs $remote "rm -rf -- '$remoteJob'" 2>&1 |
            Tee-Object -FilePath $transportLog -Append
    } else {
        Write-Warning "Remote debug job retained by request: $remoteJob"
    }
}
