import sys
import os
import apprise
from flask import Flask, request

config_path = os.getenv("CONFIG_PATH")
if config_path is None:
    sys.exit("--config missing")

# Create an Apprise instance
apobj = apprise.Apprise()

# Create an Config instance
config = apprise.AppriseConfig()

# Add a configuration source:
config.add(config_path)
print(f"loading config {config_path}")

apobj.add(config)

app = Flask(__name__)


@app.route("/", methods=["GET", "POST"])
def notify():
    query = request.args
    title = query.get("title")
    body = query.get("body")
    tag = query.get("tag")

    if request.content_type == "application/json":
        body_json = request.get_json()
        title = title or body_json.get("title")
        body = body or body_json.get("body")
        tag = tag or body_json.get("tag")

    body = body or title
    if not tag:
        return "missing tag", 400
    if not body:
        body = title

    apobj.notify(
        body=body or "",
        title=title or "",
        tag=tag,
    )
    return f"tag: {tag}, title: {title}, body: {body}"
