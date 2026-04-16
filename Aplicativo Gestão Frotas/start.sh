#!/usr/bin/env bash
set -e
pip install --quiet -r requirements.txt
exec python server.py
