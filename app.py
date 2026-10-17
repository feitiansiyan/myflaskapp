import argparse
import os

from flask import Flask

app = Flask(__name__)


@app.route('/')
def hello():
    return "Hello, CI/CD with Jenkins!"


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int,
                        default=int(os.environ.get('PORT', '5000')))
    args = parser.parse_args()
    app.run(host='127.0.0.1', port=args.port)
