import subprocess,os,sys,signal,secrets
from pathlib import Path

def interrupted(signum,frame): raise SystemExit(128+signum)
signal.signal(signal.SIGINT,interrupted)
signal.signal(signal.SIGTERM,interrupted)
suffix='_starter_c8_795b43_'+secrets.token_hex(6)
Path('/tmp/starter-c8-permissions/partition').write_text(suffix)
env=dict(os.environ,PGHOST='127.0.0.1',ERL_FLAGS='+S 4:4',HEX_HOME='/tmp/starter-c8-tools/hex')
try:
    result=subprocess.run([sys.executable,'/tmp/starter-c8-permissions/probe.py',sys.argv[1]],env=env)
    code=result.returncode
finally:
    subprocess.run(['dropdb','--if-exists','bedrock_test'+suffix],env=env,check=True)
    Path('/tmp/starter-c8-permissions/partition').unlink()
    print('Removed synthetic generation database bedrock_test'+suffix,flush=True)
raise SystemExit(code)
