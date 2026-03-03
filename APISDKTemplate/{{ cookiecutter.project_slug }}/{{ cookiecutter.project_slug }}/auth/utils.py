"""Auth utility constants for {{ cookiecutter.service_name }} SDK."""

from dotenv import load_dotenv

load_dotenv()

CLIENT_CREDS_ENV_VARS: dict[str, str] = {
    "client_id": "{{ cookiecutter.service_name.upper() }}_CLIENT_ID",
    "client_username": "{{ cookiecutter.service_name.upper() }}_USERNAME",
    "client_password": "{{ cookiecutter.service_name.upper() }}_PASSWORD",
}
