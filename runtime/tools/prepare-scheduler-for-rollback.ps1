param([string]$ProjectPath)
$ErrorActionPreference='Stop'
$installRoot=Split-Path -Parent $PSScriptRoot
if(-not$ProjectPath){$ProjectPath=Split-Path -Parent $installRoot}
$scheduler=Join-Path $PSScriptRoot 'scheduler.ps1'
if(-not(Test-Path $scheduler -PathType Leaf)){Write-Host 'ROLLBACK_SCHEDULER_PREFLIGHT=NO_SCHEDULER_TOOL';exit 0}
function Get-State {
  $raw=& $scheduler -Operation Status | Out-String
  return ($raw|ConvertFrom-Json)
}
try{
  $before=Get-State
  $beforeRegistration=$before.registration
  if($beforeRegistration -and [string]$beforeRegistration.status -in @('REGISTRATION_STATE_INVALID','SCHEDULER_STATUS_ERROR','POLICY_INVALID','STALE_LOCAL_REGISTRATION','MISSING_LOCAL_REGISTRATION','BLOCKED')){
    Write-Host "ROLLBACK_BLOCKED_SCHEDULER_STATE=$([string]$beforeRegistration.status)"
    exit 14
  }
  & $scheduler -Operation Remove -OwnerApproved | Out-Null
  $after=Get-State
  $registration=$after.registration
  if($after.registered-eq$true){Write-Host "ROLLBACK_BLOCKED_LOCAL_SCHEDULE=$($after.task_name)";exit 12}
  if($registration -and [string]$registration.status -eq 'NEEDS_PLATFORM_DEACTIVATION'){
    Write-Host 'ROLLBACK_BLOCKED_EXTERNAL_SCHEDULE=1'
    Write-Host "EXTERNAL_ID=$([string]$registration.external_id)"
    exit 13
  }
  if($registration -and [string]$registration.status -in @('REGISTRATION_STATE_INVALID','SCHEDULER_STATUS_ERROR','POLICY_INVALID','STALE_LOCAL_REGISTRATION','MISSING_LOCAL_REGISTRATION','BLOCKED')){
    Write-Host "ROLLBACK_BLOCKED_SCHEDULER_STATE=$([string]$registration.status)"
    exit 14
  }
  Write-Host 'ROLLBACK_SCHEDULER_PREFLIGHT=PASS'
  exit 0
}catch{
  Write-Host ('ROLLBACK_BLOCKED_SCHEDULER_ERROR='+$_.Exception.Message)
  exit 14
}
