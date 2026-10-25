#!/usr/bin/env python3
"""Décode un lien de partage de widget Omalauncher.
Format: https://simonschubert.github.io/omarchy-widgets/w#owl1.<base64url(deflate brut)>
Usage: ./decode-share-link.py '<url ou data>' [-o fichier.owl]
"""
import sys, re, base64, zlib, urllib.parse, argparse

def decode(s: str) -> str:
    s = s.strip()
    if '#' in s:
        s = s.split('#', 1)[1]
    s = re.sub(r'^owl\d+\.', '', s)
    s = urllib.parse.unquote(s)
    pad = '=' * (-len(s) % 4)
    raw = base64.urlsafe_b64decode(s + pad)
    try:
        return zlib.decompress(raw, -15).decode('utf-8')
    except zlib.error:
        return zlib.decompress(raw).decode('utf-8')

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('link')
    ap.add_argument('-o', '--output')
    a = ap.parse_args()
    text = decode(a.link)
    if a.output:
        open(a.output, 'w', encoding='utf-8').write(text)
        print(f'écrit {a.output} ({len(text)} octets)')
    else:
        sys.stdout.write(text)

if __name__ == '__main__':
    main()
