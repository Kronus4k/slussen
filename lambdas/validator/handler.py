import json
import logging
import os
from pathlib import Path

from pipeline_core.gate import load_contracts, process_batch
from pipeline_core.storage import S3Store

logger = logging.getLogger()
logger.setLevel(logging.INFO)

CONTRACTS = load_contracts(Path(os.environ.get("CONTRACTS_DIR", Path(__file__).resolve().parent / "contracts")))


def lambda_handler(event, context):
    bucket = event["bucket"]
    key = event["key"]
    outcome = process_batch(S3Store(bucket), key, CONTRACTS).to_dict()
    logger.info(json.dumps({"message": "gate_outcome", "bucket": bucket, "key": key, **outcome}))
    return outcome