#!/usr/bin/env python3
import hashlib, json, os, stat, sys
from pathlib import Path

ALGORITHM='PUNTASH_SOURCE_V1'
EXCLUDED_ROOTS={'.comprehensive-qa','.comprehensive-qa-backups','.git','.hg','.svn'}
MAX_FILES=100000
MAX_BYTES=5*1024*1024*1024
CHUNK=1024*1024

def fail(reason):
    print(json.dumps({'ok':False,'algorithm':ALGORITHM,'reason':reason},separators=(',',':')))
    return 2

def fingerprint(project: Path):
    project=project.resolve(strict=True)
    records=[]; total=0
    stack=[project]
    while stack:
        directory=stack.pop()
        try: entries=list(os.scandir(directory))
        except OSError as exc: raise RuntimeError('A project directory could not be read safely.') from exc
        for entry in entries:
            rel=Path(entry.path).relative_to(project)
            if len(rel.parts)==1 and rel.parts[0] in EXCLUDED_ROOTS: continue
            try:
                st=entry.stat(follow_symlinks=False)
            except OSError as exc: raise RuntimeError('A project item could not be inspected safely.') from exc
            # Reparse/symlink-like objects are rejected rather than followed.
            attrs=getattr(st,'st_file_attributes',0)
            if entry.is_symlink() or bool(attrs & getattr(stat,'FILE_ATTRIBUTE_REPARSE_POINT',0)):
                raise RuntimeError('Project snapshot cannot be proven while a symlink or filesystem redirection is present.')
            if entry.is_dir(follow_symlinks=False):
                stack.append(Path(entry.path)); continue
            if not entry.is_file(follow_symlinks=False):
                raise RuntimeError('Project snapshot encountered an unsupported filesystem object.')
            total += int(st.st_size)
            if total>MAX_BYTES: raise RuntimeError('Project snapshot is too large to verify safely. Use Git for release freshness or reduce the project scope.')
            if len(records)>=MAX_FILES: raise RuntimeError('Project snapshot contains too many files to verify safely. Use Git for release freshness or reduce the project scope.')
            h=hashlib.sha256()
            try:
                with open(entry.path,'rb') as fh:
                    while True:
                        b=fh.read(CHUNK)
                        if not b: break
                        h.update(b)
            except OSError as exc: raise RuntimeError('A project file changed or became unreadable while the snapshot was being calculated.') from exc
            norm='/'.join(rel.parts)
            records.append((norm,h.hexdigest()))
    # .NET StringComparer.Ordinal is UTF-16 code-unit order. UTF-16BE bytes preserve that order.
    records.sort(key=lambda x:x[0].encode('utf-16-be','surrogatepass'))
    overall=hashlib.sha256()
    for rel,digest in records:
        overall.update(rel.encode('utf-8','surrogatepass'));overall.update(b'\0');overall.update(digest.encode('ascii'));overall.update(b'\n')
    return {'ok':True,'algorithm':ALGORITHM,'sha256':overall.hexdigest().upper(),'file_count':len(records),'byte_count':total}

def main():
    project=Path(sys.argv[1]) if len(sys.argv)>1 else Path.cwd()
    try: result=fingerprint(project)
    except Exception as exc: return fail(str(exc) or 'Project snapshot could not be calculated.')
    print(json.dumps(result,separators=(',',':')));return 0
if __name__=='__main__': raise SystemExit(main())
