import os,secrets,subprocess,json,re,signal
from pathlib import Path
root=Path.cwd()
suffix='_name_c9_'+secrets.token_hex(6)
env=dict(os.environ,MIX_ENV='test',ERL_FLAGS='+S 4:4',HEX_HOME='/tmp/starter-c9-tools/hex',MIX_TEST_PARTITION=suffix)
commands=[['mix','deps.get'],['mix','format','--check-formatted'],['mix','compile','--warnings-as-errors'],['mix','deps.unlock','--check-unused'],['mix','test','--cover'],['mix','credo','--strict'],['mix','dialyzer'],['mix','docs','--warnings-as-errors'],['mix','hex.audit'],['mix','deps.audit'],['mix','sobelow','--config'],['mix','precommit'],['mix','hex.outdated','--all']]
record={'environment':{k:env[k] for k in ('MIX_ENV','ERL_FLAGS','HEX_HOME','MIX_TEST_PARTITION')},'checks':[]}
def interrupted(signum,frame): raise SystemExit(128+signum)
signal.signal(signal.SIGINT,interrupted)
signal.signal(signal.SIGTERM,interrupted)
try:
 for cmd in commands:
  result=subprocess.run(['foundry','capture','--',*cmd],cwd=root,env=env,capture_output=True,text=True)
  print(result.stdout+result.stderr,flush=True)
  paths=dict(re.findall(r'^(stdout|stderr): (.+)$',result.stdout+result.stderr,re.MULTILINE))
  record['checks'].append({'command':'MIX_ENV=test '+' '.join(cmd),'exit_code':result.returncode,'required':cmd[-1]!='--all',**{k+'_log':v for k,v in paths.items()}})
  (root/'.foundry/name-quality.json').write_text(json.dumps(record,indent=2)+'\n')
finally:
 result=subprocess.run(['dropdb','--if-exists','--force','business_test'+suffix],env=env)
 record['cleanup']={'database':'business_test'+suffix,'exit_code':result.returncode}
 (root/'.foundry/name-quality.json').write_text(json.dumps(record,indent=2)+'\n')
raise SystemExit(any(r['required'] and r['exit_code'] for r in record['checks']) or record['cleanup']['exit_code'])
