param([string]$ProjectPath)
$ErrorActionPreference='Stop'
if(-not$ProjectPath){$ProjectPath=(Get-Location).Path}
$ProjectPath=(Resolve-Path -LiteralPath $ProjectPath).Path
$algorithm='PUNTASH_SOURCE_V1'
$excluded=@('.comprehensive-qa','.comprehensive-qa-backups','.git','.hg','.svn')
$maxFiles=100000
$maxBytes=[int64]5*1024*1024*1024
function Emit-Failure([string]$Reason){[ordered]@{ok=$false;algorithm=$algorithm;reason=$Reason}|ConvertTo-Json -Compress;exit 2}
function Sha-File([string]$Path){$stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read);$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose();$stream.Dispose()}}
try{
  $records=New-Object System.Collections.Generic.List[object];[int64]$total=0
  $stack=New-Object System.Collections.Generic.Stack[string];$stack.Push($ProjectPath)
  while($stack.Count){
    $dir=$stack.Pop()
    foreach($item in Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop){
      $rel=[IO.Path]::GetRelativePath($ProjectPath,$item.FullName).Replace('\','/')
      if(-not$rel.Contains('/') -and $excluded-contains$rel){continue}
      if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw 'Project snapshot cannot be proven while a symlink or filesystem redirection is present.'}
      if($item.PSIsContainer){$stack.Push($item.FullName);continue}
      if(-not($item-is[IO.FileInfo])){throw 'Project snapshot encountered an unsupported filesystem object.'}
      $total+=[int64]$item.Length
      if($total-gt$maxBytes){throw 'Project snapshot is too large to verify safely. Use Git for release freshness or reduce the project scope.'}
      if($records.Count-ge$maxFiles){throw 'Project snapshot contains too many files to verify safely. Use Git for release freshness or reduce the project scope.'}
      $records.Add([pscustomobject]@{path=$rel;sha=(Sha-File $item.FullName)})
    }
  }
  $arr=$records.ToArray();[Array]::Sort($arr,[Comparison[object]]{param($a,$b);[StringComparer]::Ordinal.Compare([string]$a.path,[string]$b.path)})
  $sha=[Security.Cryptography.SHA256]::Create();$ms=New-Object IO.MemoryStream
  try{
    foreach($r in $arr){$bytes=[Text.Encoding]::UTF8.GetBytes(([string]$r.path)+[char]0+([string]$r.sha)+"`n");$ms.Write($bytes,0,$bytes.Length)}
    $ms.Position=0;$digest=([BitConverter]::ToString($sha.ComputeHash($ms))).Replace('-','').ToUpperInvariant()
  }finally{$sha.Dispose();$ms.Dispose()}
  [ordered]@{ok=$true;algorithm=$algorithm;sha256=$digest;file_count=$arr.Count;byte_count=$total}|ConvertTo-Json -Compress
}catch{Emit-Failure $_.Exception.Message}
