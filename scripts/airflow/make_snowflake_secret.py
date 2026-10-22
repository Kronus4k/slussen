import argparse
import base64
import hashlib
import json
from pathlib import Path

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa


def main() -> None:
    parser = argparse.ArgumentParser(description="Create a key pair and the Airflow Snowflake connection secret.")
    parser.add_argument("--account", required=True)
    parser.add_argument("--out", default="/out")
    args = parser.parse_args()

    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    private_pem = key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    public_der = key.public_key().public_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    public_b64 = base64.b64encode(public_der).decode("ascii")
    fingerprint = "SHA256:" + base64.b64encode(hashlib.sha256(public_der).digest()).decode("ascii")

    connection = {
        "conn_type": "snowflake",
        "login": "SVC_AIRFLOW",
        "schema": "AUDIT",
        "extra": {
            "account": args.account,
            "database": "ECOM_DB",
            "warehouse": "TRANSFORM_WH",
            "role": "ORCHESTRATOR_ROLE",
            "private_key_content": base64.b64encode(private_pem).decode("ascii"),
        },
    }

    out = Path(args.out)
    (out / "secret.json").write_text(json.dumps(connection), encoding="utf-8")
    (out / "set_public_key.sql").write_text(
        "USE ROLE USERADMIN;\n"
        f"ALTER USER SVC_AIRFLOW SET RSA_PUBLIC_KEY = '{public_b64}';\n"
        "DESC USER SVC_AIRFLOW;\n"
        "USE ROLE DATA_ENGINEER;\n",
        encoding="utf-8",
    )
    print("public key fingerprint", fingerprint)


if __name__ == "__main__":
    main()