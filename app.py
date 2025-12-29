#!/usr/bin/env python3
from flask import Flask, jsonify, send_from_directory
import subprocess
import os
from datetime import datetime

app = Flask(__name__, static_url_path='', static_folder='static')


def run(cmd):
    try:
        return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:
        return e.output


def list_connections():
    out = run("ss -tunap || netstat -tunap")
    return out.splitlines()


def list_processes():
    out = run("ps -eo pid,comm,cmd --sort=comm")
    return out.splitlines()


def list_devices():
    # Try ip neigh; fallback to arp -a
    out = run("ip neigh show || arp -a")
    return out.splitlines()


@app.route('/')
def index():
    return send_from_directory('static', 'index.html')


@app.route('/api/connections')
def api_connections():
    return jsonify({"timestamp": datetime.now().isoformat(), "lines": list_connections()})


@app.route('/api/processes')
def api_processes():
    return jsonify({"timestamp": datetime.now().isoformat(), "lines": list_processes()})


@app.route('/api/devices')
def api_devices():
    return jsonify({"timestamp": datetime.now().isoformat(), "lines": list_devices()})


if __name__ == '__main__':
    port = int(os.environ.get('PORT', '5000'))
    app.run(host='0.0.0.0', port=port)
