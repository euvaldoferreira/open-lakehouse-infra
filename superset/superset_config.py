import os

SQLALCHEMY_DATABASE_URI = (
    f"postgresql+psycopg2://{os.environ['SUPERSET_DB_USER']}:"
    f"{os.environ['SUPERSET_DB_PASSWORD']}@postgres:5432/{os.environ['SUPERSET_DB_NAME']}"
)

SECRET_KEY = os.environ["SUPERSET_SECRET_KEY"]

TALISMAN_ENABLED = False
WTF_CSRF_ENABLED = True
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SECURE = False

SUPERSET_WEBSERVER_PORT = int(os.environ.get("SUPERSET_PORT", 8088))
