#!/usr/bin/env python3
import argparse,json,mimetypes,secrets,subprocess,sys,threading,time,webbrowser
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote,urlparse

INSTALL=Path(__file__).resolve().parent.parent
TOOLS=INSTALL/'tools'; STATE=INSTALL/'state'; STATE.mkdir(exist_ok=True)
POLICY=STATE/'OWNER_POLICY.json'; TEMPLATE=INSTALL/'templates'/'OWNER_POLICY.json'
if not POLICY.exists(): POLICY.write_bytes(TEMPLATE.read_bytes())

def run_json(cmd):
    r=subprocess.run(cmd,capture_output=True,text=True)
    if r.returncode: raise RuntimeError((r.stderr or r.stdout).strip() or f'command failed {r.returncode}')
    return json.loads(r.stdout)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--project');ap.add_argument('--port',type=int,default=0);ap.add_argument('--idle-minutes',type=int,default=30);ap.add_argument('--no-browser',action='store_true');ap.add_argument('--token');a=ap.parse_args()
    project=Path(a.project).resolve() if a.project else INSTALL.parent.resolve()
    token=a.token or secrets.token_hex(32); last=[time.monotonic()]; stop=threading.Event()
    policy_tool=[sys.executable,str(TOOLS/'policy-manager.py')]; scheduler_tool=[sys.executable,str(TOOLS/'scheduler.py')]
    class H(BaseHTTPRequestHandler):
        server_version='ComprehensiveQAControl/2.1'
        def log_message(self,*args): pass
        def headers_common(self):
            self.send_header('Cache-Control','no-store');self.send_header('X-Content-Type-Options','nosniff');self.send_header('Referrer-Policy','no-referrer');self.send_header('Content-Security-Policy',"default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self'; img-src 'self' data:; object-src 'none'; frame-ancestors 'none'; base-uri 'none'")
        def send_bytes(self,b,ctype='application/octet-stream',code=200):
            self.send_response(code);self.send_header('Content-Type',ctype);self.headers_common();self.send_header('Content-Length',str(len(b)));self.end_headers();self.wfile.write(b)
        def send_json(self,obj,code=200): self.send_bytes(json.dumps(obj,separators=(',',':')).encode(),'application/json; charset=utf-8',code)
        def authorized(self):
            if self.headers.get('X-QA-Control-Token','')!=token:return False
            origin=self.headers.get('Origin','');expected=f'http://127.0.0.1:{self.server.server_address[1]}'
            return not origin or origin==expected
        def api_get(self,path):
            if not self.authorized():return self.send_json({'ok':False,'error':'unauthorized'},403)
            if path=='/api/policy': return self.send_json({'ok':True,'policy':json.loads(POLICY.read_text(encoding='utf-8-sig'))})
            if path=='/api/scheduler': return self.send_json({'ok':True,'scheduler':run_json(scheduler_tool+['status'])})
            return self.send_json({'ok':False,'error':'not_found'},404)
        def do_GET(self):
            last[0]=time.monotonic();path=urlparse(self.path).path
            if path.startswith('/api/'):return self.api_get(path)
            rel=unquote(path.lstrip('/')) or 'dashboard/index.html'
            if rel=='index.html':rel='dashboard/index.html'
            if rel=='data.js':rel='dashboard/data.js'
            try:p=(INSTALL/rel).resolve();p.relative_to(INSTALL.resolve())
            except Exception:return self.send_bytes(b'Not Found','text/plain',404)
            if not p.is_file():return self.send_bytes(b'Not Found','text/plain',404)
            ctype=mimetypes.guess_type(str(p))[0] or 'application/octet-stream';self.send_bytes(p.read_bytes(),ctype)
        def do_POST(self):
            last[0]=time.monotonic();path=urlparse(self.path).path
            if not self.authorized():return self.send_json({'ok':False,'error':'unauthorized'},403)
            if path=='/api/shutdown':
                self.send_json({'ok':True});stop.set();return
            if path!='/api/policy':return self.send_json({'ok':False,'error':'not_found'},404)
            try:n=int(self.headers.get('Content-Length','-1'))
            except ValueError:n=-1
            if n<0 or n>65536:return self.send_json({'ok':False,'error':'invalid_body_size'},413)
            try:candidate=json.loads(self.rfile.read(n))
            except Exception:return self.send_json({'ok':False,'error':'invalid_json'},400)
            temp=STATE/('.owner-policy-candidate-'+secrets.token_hex(8)+'.json')
            try:
                temp.write_text(json.dumps(candidate,indent=2)+'\n',encoding='utf-8')
                r=subprocess.run(policy_tool+['apply','--policy-json',str(temp),'--owner-approved','--approval-source','dashboard_local_control'],capture_output=True,text=True)
                if r.returncode:raise RuntimeError((r.stderr or r.stdout).strip())
                sched_ok=True;sched_msg=None
                op='apply' if candidate.get('schedule',{}).get('enabled') else 'remove'
                sr=subprocess.run(scheduler_tool+[op,'--owner-approved'],capture_output=True,text=True)
                if sr.returncode not in (0,7):sched_ok=False;sched_msg=(sr.stderr or sr.stdout).strip()
                refresh=TOOLS/'dashboard-refresh.sh'
                if refresh.exists():subprocess.run(['bash',str(refresh),str(project)],capture_output=True,text=True)
                saved=json.loads(POLICY.read_text(encoding='utf-8-sig'));sched=run_json(scheduler_tool+['status'])
                self.send_json({'ok':True,'policy':saved,'scheduler':sched,'scheduler_apply_ok':sched_ok,'scheduler_message':sched_msg})
            except Exception as e:self.send_json({'ok':False,'error':str(e)},400)
            finally:
                try:temp.unlink()
                except Exception:pass
    srv=ThreadingHTTPServer(('127.0.0.1',a.port),H);port=srv.server_address[1];srv.timeout=1
    print(f'DASHBOARD_CONTROL_URL=http://127.0.0.1:{port}/',flush=True);print('DASHBOARD_CONTROL_BIND=127.0.0.1',flush=True)
    if not a.no_browser:webbrowser.open(f'http://127.0.0.1:{port}/#token={token}')
    try:
        while not stop.is_set() and time.monotonic()-last[0] < a.idle_minutes*60:srv.handle_request()
    finally:srv.server_close();print('DASHBOARD_CONTROL_STOPPED=1',flush=True)
if __name__=='__main__':raise SystemExit(main())
