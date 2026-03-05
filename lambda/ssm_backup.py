import boto3
import json
import logging
import os
from typing import Any

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event: dict[str, Any], _context: object) -> dict[str, Any]:
    ssm = boto3.client("ssm")
    s3 = boto3.client("s3")

    path = os.environ["SSM_PATH"]
    bucket = os.environ["S3_BUCKET"]

    logger.info("Starting SSM backup for path: %s", path)

    paginator = ssm.get_paginator("get_parameters_by_path")
    params = {}
    for page in paginator.paginate(Path=path, WithDecryption=True, Recursive=True):
        for p in page["Parameters"]:
            params[p["Name"]] = {
                "Value": p["Value"],
                "Type": p["Type"],
                "Version": p["Version"],
                "LastModifiedDate": p["LastModifiedDate"].isoformat(),
            }

    logger.info("Fetched %d parameters from SSM", len(params))

    key = f"ssm-backup{path}.json"

    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(params, indent=2, sort_keys=True).encode("utf-8"),
        ContentType="application/json",
        ServerSideEncryption="aws:kms",
        SSEKMSKeyId=os.environ["KMS_KEY_ID"],
        ExpectedBucketOwner=os.environ["ACCOUNT_ID"],
    )

    logger.info("Backup successful: %d parameters backed up", len(params))
    return {"statusCode": 200, "key": key, "count": len(params)}
