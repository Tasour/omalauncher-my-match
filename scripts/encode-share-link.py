#!/usr/bin/env python3
"""Encode un fichier .owl en lien de partage Omalauncher (raw DEFLATE + base64url).
Usage: ./encode-share-link.py widget/my-match.owl
"""
import sys, zlib, base64, argparse

LINK = 'https://simonschubert.github.io/omarchy-widgets/w#owl1.'

def encode(text: str) -> str:
    co = zlib.compressobj(9, zlib.DEFLATED, -15)
    data = co.compress(text.encode('utf-8')) + co.flush()
    return LINK + base64.urlsafe_b64encode(data).decode('ascii').rstrip('=')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('file')
    a = ap.parse_args()
    text = open(a.file, encoding='utf-8').read()
    print(encode(text))

if __name__ == '__main__':
    main()
