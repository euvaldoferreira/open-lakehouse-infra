"""
Airflow Webserver Configuration
Supports two auth modes driven by AIRFLOW_AUTH_TYPE env var:
  - AUTH_DB (default): username/password stored in the Airflow DB
  - AUTH_OAUTH: Keycloak OIDC — activated by the security stack overlay
"""
from __future__ import annotations

import os

from flask_appbuilder.security.manager import AUTH_DB, AUTH_OAUTH

_AUTH_TYPE = os.getenv("AIRFLOW_AUTH_TYPE", "AUTH_DB")

if _AUTH_TYPE == "AUTH_OAUTH":
    AUTH_TYPE = AUTH_OAUTH

    _keycloak_url = os.environ["KEYCLOAK_URL"]
    _realm = os.environ["KEYCLOAK_REALM"]
    _base = f"{_keycloak_url}/realms/{_realm}/protocol/openid-connect"

    OAUTH_PROVIDERS = [
        {
            "name": "keycloak",
            "token_key": "access_token",
            "icon": "fa-key",
            "remote_app": {
                "client_id": os.environ["KEYCLOAK_AIRFLOW_CLIENT_ID"],
                "client_secret": os.environ["KEYCLOAK_AIRFLOW_CLIENT_SECRET"],
                "server_metadata_url": (
                    f"{_keycloak_url}/realms/{_realm}"
                    "/.well-known/openid-configuration"
                ),
                "api_base_url": _base,
                "access_token_url": f"{_base}/token",
                "authorize_url": f"{_base}/auth",
                "client_kwargs": {"scope": "openid email profile roles"},
            },
        }
    ]

    AUTH_USER_REGISTRATION = True
    AUTH_USER_REGISTRATION_ROLE = "Viewer"
    AUTH_ROLES_SYNC_AT_LOGIN = True

    # Mapeamento: role Keycloak → role Airflow
    AUTH_ROLES_MAPPING = {
        "admin": ["Admin"],
        "data-engineer": ["Op"],
        "data-analyst": ["Viewer"],
        "viewer": ["Viewer"],
    }

else:
    AUTH_TYPE = AUTH_DB
