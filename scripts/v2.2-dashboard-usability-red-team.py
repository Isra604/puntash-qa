#!/usr/bin/env python3
from html.parser import HTMLParser
from pathlib import Path
import re, sys
ROOT=Path(__file__).resolve().parent.parent
HTML=ROOT/'runtime/dashboard/index.html'

def ok(cond,name):
    if not cond:
        raise AssertionError('V22_DASHBOARD_USABILITY_FAIL='+name)
    print('V22_DASHBOARD_USABILITY_PASS='+name)

class VisibleText(HTMLParser):
    def __init__(self):
        super().__init__(); self.skip=0; self.parts=[]
    def handle_starttag(self,tag,attrs):
        attrs=dict(attrs); classes=set((attrs.get('class') or '').split())
        if self.skip:
            self.skip+=1; return
        if tag in {'script','style'} or 'tech' in classes:
            self.skip=1
    def handle_endtag(self,tag):
        if self.skip: self.skip-=1
    def handle_data(self,data):
        if not self.skip:
            t=' '.join(data.split())
            if t:self.parts.append(t)

html=HTML.read_text(encoding='utf-8')
p=VisibleText();p.feed(html);visible='\n'.join(p.parts)
# Core language and information architecture.
for token in [
    'Things to review','What PUNTASH can change','Automatic scans','Your decisions',
    'Ready to release?','Fix PUNTASH QA','Ask PUNTASH','Settings & privacy',
    'What PUNTASH QA noticed, why it matters, and what you can do next.',
    'Choose how much PUNTASH QA is allowed to fix by itself.',
    'When PUNTASH QA needs your permission, you will see exactly what it wants to change and why.',
    'This Dashboard does not send your project data anywhere.',
    'PUNTASH QA checks your project from many different angles and explains the result in plain language.',
    'See proof','Was the expected result checked?','How risky?'
]: ok(token in html,'plain_language_'+re.sub(r'[^a-z0-9]+','_',token.lower())[:48])
# Default/static overview text must not expose implementation jargon.
for bad in ['policy_revision','request_id','authorization_id','executor','JSON','schema','Git HEAD','SHA-256','cron','Task Scheduler','Owner Policy','Control token','telemetry']:
    ok(bad.lower() not in visible.lower(),'overview_hides_'+re.sub(r'[^a-z0-9]+','_',bad.lower()))
# Counts/engine terminology belong to Details, not onboarding/default prose.
ok('Technical detail: a complete scan contains 25 quality gates and 9 reliability lenses.' in html,'technical_engine_counts_preserved_in_details')
ok('PUNTASH QA checks your project using 25 quality gates and 9 reliability lenses.' not in visible,'onboarding_avoids_engine_jargon')
# Local command setup must be Details-only.
ok(re.search(r'<div class="tech"[^>]*>.*?id="executorCommand".*?id="executorArgs".*?</div></article>',html,re.S) is not None,'local_command_fields_details_only')
# Technical raw state remains available for experts, but hidden by default.
ok('<article class="card span12 tech"><h2>Current raw Dashboard state</h2>' in html,'raw_state_details_only')
# Default mode is Overview; Details requires an explicit user choice.
ok('id="overviewMode" class="active"' in html and 'id="detailsMode">Details</button>' in html,'overview_is_default_mode')
# No legacy jargon labels on primary navigation/copy.
for old in ["['findings','Findings']","['permissions','Permissions']","['schedule','Schedule']","['approvals','Approvals']","['release','Release readiness']","['recovery','Recovery']",'View evidence','maximum authority for automatic fixes','Never turns an incomplete check into a PASS.']:
    ok(old not in html,'legacy_jargon_removed_'+str(abs(hash(old))))
# Every primary screen has a plain-language subtitle entry.
for screen in ['home','scan','findings','activity','permissions','schedule','approvals','health','release','recovery','ask','settings']:
    ok(re.search(rf"{screen}:'[^']{{8,}}'",html) is not None,'screen_explains_'+screen)
print('V22_DASHBOARD_USABILITY_RESULT=PASS')
