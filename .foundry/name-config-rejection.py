import json,os,re,shutil,subprocess,sys
from pathlib import Path
sys.dont_write_bytecode=True
root=Path.cwd()
sys.path.insert(0,str(root/'scripts'))
from qualify_callers import disposable_snapshot,snapshot
records=[]
env={k:v for k,v in os.environ.items() if k not in ('BUSINESS_NAME','SHOP_NAME','PHX_SERVER')}
env.update(MIX_ENV='test',HEX_HOME='/tmp/starter-c9-tools/hex',ERL_FLAGS='+S 4:4')
with disposable_snapshot(None) as app:
 snapshot(app)
 for directory in ('deps','_build'):
  shutil.copytree(root/directory,app/directory,symlinks=True,dirs_exist_ok=True)
 path=app/'priv/business.json'
 for label,data,override,expected,diagnostic in [
  ('malformed','{',{},None,'Jason.DecodeError'),
  ('missing-name','{}',{},None,'must contain a string name'),
  ('non-string','{"name":42}',{},None,'must contain a string name'),
  ('malformed-business-override','{',{'BUSINESS_NAME':'Runtime override','SHOP_NAME':'Old override'},'Runtime override',None),
  ('malformed-shop-override','{',{'SHOP_NAME':'Old override'},'Old override',None),
  ('malformed-empty-override','{',{'BUSINESS_NAME':''},'',None)]:
  path.write_text(data)
  case_env=dict(env,**override,NAME_EXPECTED=expected or '')
  command=['mix','run','--no-start','--no-compile','-e','if Business.name() != System.fetch_env!("NAME_EXPECTED"), do: raise("Name precedence changed")']
  result=subprocess.run(['foundry','capture','--',*command],cwd=app,env=case_env,capture_output=True,text=True)
  print(label+':\n'+result.stdout+result.stderr,flush=True)
  logs=dict(re.findall(r'^(stdout|stderr): (.+)$',result.stdout+result.stderr,re.MULTILINE))
  record={'case':label,'command':' '.join(command),'exit_code':result.returncode,'logs':logs}
  records.append(record)
  if diagnostic:
   assert result.returncode != 0
   assert diagnostic in Path(logs['stderr']).read_text()
  else:
   assert result.returncode == 0
Path('.foundry/name-config-rejection.json').write_text(json.dumps({'checks':records,'cleanup':'Snapshot removed; no database or listener started.'},indent=2)+'\n')
