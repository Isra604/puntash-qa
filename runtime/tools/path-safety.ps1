$ErrorActionPreference='Stop'
function Get-ExistingItem([string]$Path){
  try{return Get-Item -LiteralPath $Path -Force -ErrorAction Stop}catch{return $null}
}
function Assert-NoReparsePoint {
  param([Parameter(Mandatory=$true)][string]$Path,[string]$Label='path',[switch]$Recursive)
  $item=Get-ExistingItem $Path
  if($null-eq$item){return}
  if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw "UNSAFE_REPARSE_POINT: $Label -> $Path"}
  if(-not$Recursive-or-not$item.PSIsContainer){return}
  $queue=New-Object 'System.Collections.Generic.Queue[string]';$queue.Enqueue($item.FullName)
  while($queue.Count-gt0){
    $dir=$queue.Dequeue()
    foreach($child in Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop){
      if(($child.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw "UNSAFE_REPARSE_POINT: $Label contains reparse point -> $($child.FullName)"}
      if($child.PSIsContainer){$queue.Enqueue($child.FullName)}
    }
  }
}
function Assert-PathWithin {
  param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Root,[string]$Label='path',[switch]$MustExist)
  $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
  if($MustExist-and-not(Test-Path -LiteralPath $Path)){throw "PATH_NOT_FOUND: $Label -> $Path"}
  $pathFull=[IO.Path]::GetFullPath($Path)
  $prefix=$rootFull+[IO.Path]::DirectorySeparatorChar
  if(-not($pathFull.Equals($rootFull,[StringComparison]::OrdinalIgnoreCase)-or$pathFull.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase))){throw "PATH_OUTSIDE_ALLOWED_ROOT: $Label -> $pathFull | root=$rootFull"}
}
