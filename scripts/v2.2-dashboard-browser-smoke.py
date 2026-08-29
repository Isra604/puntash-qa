#!/usr/bin/env python3
import hashlib,json,os,shutil,socket,subprocess,sys,tempfile,time
from html.parser import HTMLParser
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

def ok(c,n):
    if not c: raise AssertionError('V22_BROWSER_SMOKE_FAIL='+n)
    print('V22_BROWSER_SMOKE_PASS='+n)

def browser_path():
    candidates=[]
    if os.name=='nt':
        candidates += [Path(r'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'),Path(r'C:\Program Files\Microsoft\Edge\Application\msedge.exe'),Path(r'C:\Program Files\Google\Chrome\Application\chrome.exe'),Path(r'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe')]
    elif sys.platform=='darwin':
        candidates += [Path('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'),Path('/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge')]
    for c in candidates:
        if c.is_file(): return str(c)
    for name in ['google-chrome','chrome','chromium','chromium-browser','microsoft-edge','msedge']:
        p=shutil.which(name)
        if p:return p
    return None

def port():
    s=socket.socket();s.bind(('127.0.0.1',0));p=s.getsockname()[1];s.close();return p

class Visible(HTMLParser):
    def __init__(self):super().__init__();self.skip=0;self.text=[];self.buttons=[];self.stack=[]
    def handle_starttag(self,tag,attrs):
        attrs=dict(attrs);classes=set((attrs.get('class') or '').split())
        hidden='tech' in classes
        if self.skip:self.skip+=1
        elif tag in {'script','style'} or hidden:self.skip=1
        self.stack.append(tag)
    def handle_endtag(self,tag):
        if self.skip:self.skip-=1
        if self.stack:self.stack.pop()
    def handle_data(self,data):
        if self.skip:return
        t=' '.join(data.split())
        if not t:return
        self.text.append(t)
        if self.stack and self.stack[-1]=='button':self.buttons.append(t)

def main():
    browser=browser_path();ok(bool(browser),'supported_headless_browser_available')
    with tempfile.TemporaryDirectory(prefix='puntash-v22-browser-') as td:
        td=Path(td);project=td/'project';install=project/'.comprehensive-qa';project.mkdir();shutil.copytree(ROOT/'runtime',install)
        state=install/'state';state.mkdir(exist_ok=True)
        for name in ['TERMS_VERSION','LEGAL_MANIFEST.json']:
            shutil.copy2(ROOT/name,install/name)
        legal=json.loads((ROOT/'LEGAL_MANIFEST.json').read_text(encoding='utf-8-sig'))['documents']
        for name in legal:shutil.copy2(ROOT/name,install/name)
        (install/'INSTALLATION.json').write_text(json.dumps({'version':'2.2.0','previous_version':'2.1.0'}),encoding='utf-8')
        (state/'HUMAN_ACCEPTANCE_RECEIPT.json').write_text(json.dumps({'terms_version':(ROOT/'TERMS_VERSION').read_text().strip(),'accepted_by_human_attestation':True,'legal_document_sha256':legal}),encoding='utf-8')
        # Create a canonical human-approved policy using the product tool.
        pm=install/'tools/policy-manager.py'
        base=json.loads(subprocess.run([sys.executable,str(pm),'get'],check=True,capture_output=True,text=True).stdout)
        cand=state/'browser-policy.json';cand.write_text(json.dumps(base),encoding='utf-8')
        subprocess.run([sys.executable,str(pm),'apply','--policy-json',str(cand),'--owner-approved','--approval-source','manual_cli'],check=True,capture_output=True,text=True)
        token='v22-browser-smoke-token';p=port()
        server=subprocess.Popen([sys.executable,str(install/'tools/dashboard-control.py'),'--project',str(project),'--port',str(p),'--idle-minutes','5','--no-browser','--token',token],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
        try:
            deadline=time.time()+10;ready=False
            while time.time()<deadline:
                line=server.stdout.readline().strip()
                if line.startswith('DASHBOARD_CONTROL_URL='):ready=True;break
                if server.poll() is not None:break
            ok(ready,'control_center_started')
            # consume bind line
            server.stdout.readline()
            url=f'http://127.0.0.1:{p}/#token={token}'
            profile=td/'browser-profile'
            cmd=[browser,'--headless=new','--disable-gpu','--no-first-run','--disable-extensions',f'--user-data-dir={profile}','--virtual-time-budget=3500','--dump-dom',url]
            r=subprocess.run(cmd,capture_output=True,text=True,timeout=30,errors='replace')
            ok(r.returncode==0 and '<html' in r.stdout.lower(),'dashboard_renders_in_real_browser')
            vis=Visible();vis.feed(r.stdout);visible='\n'.join(vis.text)
            for label in ['Home','Scan','Things to review','Activity','What PUNTASH can change','Automatic scans','Your decisions','Project health','Ready to release?','Fix PUNTASH QA','Ask PUNTASH','Settings & privacy']:
                ok(label in visible,'rendered_navigation_'+hashlib.sha256(label.encode()).hexdigest()[:8])
            ok('Know what is happening in your project.' in visible,'human_onboarding_rendered')
            ok('PUNTASH QA checks your project from many different angles and explains the result in plain language.' in visible,'onboarding_plain_language_rendered')
            for bad in ['policy_revision','request_id','authorization_id','Git HEAD','SHA-256','Owner Policy']:
                ok(bad.lower() not in visible.lower(),'rendered_overview_hides_'+bad.lower().replace(' ','_').replace('-','_'))
            # Render both desktop and narrow/mobile screenshots and ensure they are non-trivial files.
            for name,size in [('desktop','1365,900'),('mobile','390,844')]:
                shot=td/f'{name}.png'
                rr=subprocess.run([browser,'--headless=new','--disable-gpu','--no-first-run','--disable-extensions',f'--user-data-dir={td/(name+"-profile")}',f'--window-size={size}',f'--screenshot={shot}',url],capture_output=True,text=True,timeout=30,errors='replace')
                ok(rr.returncode==0 and shot.is_file() and shot.stat().st_size>15000,f'{name}_render_nonblank')
            print('V22_BROWSER_SMOKE_RESULT=PASS')
        finally:
            if server.poll() is None:server.kill()
            try:server.wait(timeout=5)
            except Exception:pass
if __name__=='__main__':main()
