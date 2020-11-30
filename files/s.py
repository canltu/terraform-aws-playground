#!/usr/bin/python3.8
import datetime

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import padding
from botocore.signers import CloudFrontSigner
from flask import Flask, jsonify, request
from flask_cors import CORS
from urllib.parse import urlparse


def rsa_signer(message):
    with open('signing_private_key.pem', 'rb') as key_file:
        private_key = serialization.load_pem_private_key(
            key_file.read(),
            password=None,
            backend=default_backend()
        )
    return private_key.sign(message, padding.PKCS1v15(), hashes.SHA1())

key_id = 'KZN00IJAUP3SL'
url = 'https://d1hwbwrtnf3c8c.cloudfront.net/content/as.png'
expire_date = datetime.datetime(2030, 1, 1)
PORT = 8080

cloudfront_signer = CloudFrontSigner(key_id, rsa_signer)
signed_url = cloudfront_signer.generate_presigned_url(url, date_less_than=expire_date)

app = Flask(__name__)
cors = CORS(app, resources={r"/*": {"origins": "*"}})

@app.route("/healthz", methods=["GET"])
def healthz():
    return 'ok'

@app.route("/sign/", methods=["GET"])
def list_users():
    url = request.args['url']
    signed_url = cloudfront_signer.generate_presigned_url(url, date_less_than=expire_date)
    return signed_url


if __name__ == "__main__":
    app.run(host="0.0.0.0", port="8080", debug=False)
