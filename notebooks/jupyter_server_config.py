import os
from jupyter_server.auth import passwd

c.ServerApp.ip = '0.0.0.0'
c.ServerApp.allow_origin = '*'
c.ServerApp.allow_remote_access = True

# Jupyter Server 2.x auth API
c.IdentityProvider.token = ''

password = os.environ.get('JUPYTER_PASSWORD', '')
if password:
    c.PasswordIdentityProvider.hashed_password = passwd(password)
    c.PasswordIdentityProvider.allow_password_change = False
else:
    c.PasswordIdentityProvider.hashed_password = ''

c.MappingKernelManager.cull_idle_timeout = 3600
c.MappingKernelManager.cull_interval = 300
c.MappingKernelManager.cull_connected = False
