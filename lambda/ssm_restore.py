import boto3
import json
import logging
import os
from typing import Any

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event: dict[str, Any], _context: object) -> dict[str, Any]:
    s3 = boto3.client("s3")
    ssm = boto3.client("ssm")

    path = os.environ["SSM_PATH"]
    bucket = os.environ["S3_BUCKET"]

    dry_run = event.get("dry_run", True)
    version_id = event.get("version_id")
    only = set(event.get("parameters", [])) or None

    key = f"ssm-backup/{path.strip('/').replace('/', '-')}.json"

    get_kwargs = {"Bucket": bucket, "Key": key}
    if version_id:
        get_kwargs["VersionId"] = version_id

    logger.info(
        "Loading backup s3://%s/%s%s",
        bucket,
        key,
        f" (version {version_id})" if version_id else "",
    )
    obj = s3.get_object(**get_kwargs)
    backup = json.loads(obj["Body"].read())

    if only:
        backup = {name: data for name, data in backup.items() if name in only}

    logger.info(
        "%s restore of %d parameters for path: %s",
        "Dry-run" if dry_run else "Starting",
        len(backup),
        path,
    )

    restored = []
    failed = []
    for name, data in backup.items():
        if dry_run:
            restored.append(name)
            continue
        try:
            ssm.put_parameter(
                Name=name,
                Value=data["Value"],
                Type=data["Type"],
                Overwrite=True,
            )
            restored.append(name)
        except Exception:
            logger.exception("Failed to restore parameter: %s", name)
            failed.append(name)

    logger.info(
        "Restore %s: %d succeeded, %d failed",
        "dry-run complete" if dry_run else "complete",
        len(restored),
        len(failed),
    )

    return {
        "dry_run": dry_run,
        "restored": restored,
        "failed": failed,
        "count": len(restored),
    }
