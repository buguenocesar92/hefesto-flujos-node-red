#!/usr/bin/env python3
import os,secrets
from pathlib import Path
r=Path(__file__).resolve().parents[1]
s=(r/'.env.example').read_text().replace('NR_CREDENTIAL_SECRET=GENERAR','NR_CREDENTIAL_SECRET='+secrets.token_hex(32))
fd=os.open(r/'.env',os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600)
with os.fdopen(fd,'w') as f:f.write(s)
print('.env creado. Completar hashes de autenticación antes de iniciar.')
