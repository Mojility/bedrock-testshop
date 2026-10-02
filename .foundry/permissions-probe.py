import sys, os, subprocess, shutil, json, hashlib, fcntl
from pathlib import Path
base=Path('/tmp/starter-c8-permissions')
root=base/'bedrock'
starter=Path('/home/svetzal/.foundry/worktrees/bedrock-system-template/starter-caller-contracts-v1-c8-795b43')
siblings=Path('/home/svetzal/Work/Projects/Mojility')
sys.path.insert(0,str(root/'scripts'))
import integrate
subprocess.run(['python3', root/'scripts/integrate.py', '--roost', siblings/'roost', '--workshop', siblings/'bedrock-workshop', '--starter', starter], cwd=root, check=True)
destination=root/'.integration/starter'
base_digest=integrate.materialization_digest(destination)
for name in subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard'], cwd=starter, text=True).splitlines():
    if name.startswith('.foundry/'):
        continue
    source=starter/name
    target=destination/name
    if source.is_file():
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source,target)
    elif target.exists():
        target.unlink()
if sys.argv[1]=='broken':
    path=destination/'lib/business_web/controllers/lead_controller.ex'
    data=path.read_text()
    assert 'case Leads.submit(attrs) do' in data
    path.write_text(data.replace('case Leads.submit(attrs) do','case if(Map.has_key?(attrs, "email"), do: {:ok, attrs}, else: Leads.submit(attrs)) do'))
record=json.loads((root/'integration.json').read_text())
record['committed_starter_files_sha256']=base_digest
record['starter_files_sha256']=integrate.materialization_digest(destination)
record['candidate_overlay']={'base_revision':record['sources']['starter']['revision'], 'variant':sys.argv[1], 'materialization_sha256':record['starter_files_sha256']}
(root/'integration.json').write_text(json.dumps(record,indent=2)+'\n')
(starter/'.foundry'/('permissions-integration-sources-'+sys.argv[1]+'.json')).write_text(json.dumps(record,indent=2)+'\n')
os.environ['ERL_FLAGS']='+S 4:4'
os.environ['HEX_HOME']='/tmp/starter-c8-tools/hex'
os.environ['MIX_ENV']='test'
for command in [['mix','deps.get'],['python3','scripts/qualify_owner_journey.py','--stages','1,2,3,4','--output',str(starter/'.foundry'/('permissions-integration-'+sys.argv[1]+'.json'))]]:
    while True:
        if command[0]=='python3':
            print('Waiting for the shared port-4000 lock before invoking the unchanged caller',flush=True)
            with open('/tmp/bedrock-port-4000.lock','a') as lock:
                fcntl.flock(lock,fcntl.LOCK_EX)
        result=subprocess.run(command,cwd=root/'apps/bedrock' if command[0]=='mix' else root)
        if result.returncode and command[0]=='python3':
            proof=json.loads((starter/'.foundry'/('permissions-integration-'+sys.argv[1]+'.json')).read_text())
            if proof.get('error')=='[Errno 11] Resource temporarily unavailable' and not proof.get('commands'):
                attempt=starter/'.foundry'/('integration-queue-'+str(len(list((starter/'.foundry').glob('integration-queue-*.json'))))+'.json')
                attempt.write_text(json.dumps(proof,indent=2)+'\n')
                print('Caller rejected a contended lock before any generation; retrying resource acquisition only',flush=True)
                continue
        if result.returncode: sys.exit(result.returncode)
        break
