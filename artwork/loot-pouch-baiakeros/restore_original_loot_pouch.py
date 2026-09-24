from __future__ import annotations
import json,shutil,sys
from pathlib import Path
CLIENT=Path(r'D:\otserv\otclient-main\data\things\1525')
ART=Path(r'D:\otserv\otclient-main\artwork\loot-pouch-baiakeros')
BACKUP=ART/'backup-original'
SERVER=Path(r'\\wsl.localhost\Ubuntu-24.04\home\baiakeros\baiakeros\data\items\appearances.dat')
manifest=json.loads((ART/'installation.json').read_text())
catalog=CLIENT/'catalog-content.json'
client_app=CLIENT/manifest['client_appearance']
shutil.copy2(BACKUP/'catalog-content.json',catalog)
shutil.copy2(BACKUP/manifest['client_appearance'],client_app)
shutil.copy2(BACKUP/'server-appearances.dat',SERVER)
sheet=CLIENT/manifest['sheet']
if sheet.exists(): sheet.unlink()
print('Loot Pouch original restaurada. A arte Baiakeros e o backup foram preservados em:',ART)
