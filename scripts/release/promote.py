"""Promote a ready blue or green deployment, or route back to the prior colour."""

import argparse
import json
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--context", required=True)
    parser.add_argument("--namespace", required=True)
    parser.add_argument("--color", required=True, choices=("blue", "green"))
    args = parser.parse_args()
    command = ["kubectl", "--context", args.context, "--namespace", args.namespace]
    service = "image-processing-active"

    live = json.loads(subprocess.check_output(
        [*command, "get", "service", service, "-o", "json"], text=True
    ))
    selector = live["spec"]["selector"]
    previous = selector.get("color")
    if selector.get("app") != "image-processing" or previous not in ("blue", "green"):
        raise SystemExit("Unexpected selector on the active Service.")
    if previous == args.color:
        print(f"{args.color} already serves live traffic.")
        return

    subprocess.run(
        [*command, "rollout", "status", f"deployment/image-processing-{args.color}", "--timeout=120s"],
        check=True,
    )
    patch = [
        {"op": "test", "path": "/spec/selector", "value": selector},
        {"op": "replace", "path": "/spec/selector/color", "value": args.color},
    ]
    subprocess.run(
        [*command, "patch", "service", service, "--type=json", "--patch", json.dumps(patch)],
        check=True,
    )
    print(f"Active traffic changed from {previous} to {args.color}.")
    print(f"To roll back, run this command again with --color {previous}.")


if __name__ == "__main__":
    main()
