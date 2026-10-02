import os,secrets,subprocess,json,re
from pathlib import Path
suffix='_name_final_'+secrets.token_hex(6)
env=dict(os.environ,MIX_ENV='test',MIX_TEST_PARTITION=suffix,HEX_HOME='/tmp/starter-c9-tools/hex',ERL_FLAGS='+S 4:4')
try:
 result=subprocess.run(['foundry','capture','--','mix','precommit'],env=env,capture_output=True,text=True)
 print(result.stdout+result.stderr,flush=True)
 logs=dict(re.findall(r'^(stdout|stderr): (.+)$',result.stdout+result.stderr,re.MULTILINE))
 record={'command':'MIX_ENV=test mix precommit','exit_code':result.returncode,'logs':logs,'database':'business_test'+suffix}
finally:
 cleanup=subprocess.run(['dropdb','--if-exists','--force','business_test'+suffix],env=env)
 record['cleanup_exit_code']=cleanup.returncode
 Path('.foundry/name-final-checks.json').write_text(json.dumps(record,indent=2)+'\n')
raise SystemExit(result.returncode or cleanup.returncode)
