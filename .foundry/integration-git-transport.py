#!/usr/bin/env python3
import os,sys
args=sys.argv[1:]
root='/tmp/starter-integration-sources-083990/bedrock'
if len(args)>2 and args[0]=='-C' and args[1]==root:
    if args[2] not in ('remote','rev-parse','show','archive','status','log'): raise SystemExit('Forbidden archive Git write')
    args[1]='/home/svetzal/Work/Projects/Mojility/bedrock'
pins={'bedrock':'69c7f88c796299f0a4c46a888dddb91c77cf70b3', 'roost':'bb57e6d0bf2bff3af72d40ad9adb5fa7c34d81b8', 'bedrock-workshop':'adfcae0a96c291ddebfd28a086e5464bf97c9376'}
if len(args)>2 and args[0]=='-C':
    name=os.path.basename(args[1])
    if name in pins:
        args=[pins[name] if a=='HEAD' else a for a in args]
os.execv('/usr/bin/git',['git',*args])
