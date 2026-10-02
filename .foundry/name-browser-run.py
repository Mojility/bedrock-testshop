import os,secrets,subprocess,json,re
from pathlib import Path
suffix="_name_browser_"+secrets.token_hex(6)
env=dict(os.environ,MIX_ENV="test",MIX_TEST_PARTITION=suffix,HEX_HOME="/tmp/starter-c9-tools/hex",ERL_FLAGS="+S 4:4")
try:
 result=subprocess.run(["foundry","capture","--","mix","test",".foundry/name-browser-test.exs"],env=env,capture_output=True,text=True)
 print(result.stdout+result.stderr,flush=True)
 paths=dict(re.findall(r"^(stdout|stderr): (.+)$",result.stdout+result.stderr,re.MULTILINE))
 record={"command":"MIX_ENV=test mix test .foundry/name-browser-test.exs","exit_code":result.returncode,"logs":paths,"database":"business_test"+suffix}
finally:
 cleanup=subprocess.run(["dropdb","--if-exists","--force","business_test"+suffix],env=env)
 record["cleanup_exit_code"]=cleanup.returncode
 Path(".foundry/name-browser.json").write_text(json.dumps(record,indent=2)+"\n")
raise SystemExit(result.returncode or cleanup.returncode)
