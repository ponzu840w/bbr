#!/usr/bin/env python3
"""
usage:
    python3 sort_by_time.py  in.json   > out.json         # 昇順
    python3 sort_by_time.py  -r in.json > out.json        # 降順
    python3 sort_by_time.py  -i in.json                   # 上書き（昇順）
"""
import argparse, re, sys, pathlib

SRC = pathlib.Path("./data/database.json")

# ――― レコードを「{…}」単位で安全に抜き出す ──────────────────────
def split_records(text: str):
    records, start = [], text.index('{') + 1
    depth, in_str, esc = 0, False, False
    for i, c in enumerate(text[start:], start):
        if in_str:
            esc = not esc if c == '\\' and not esc else False
            in_str = not in_str if c == '"' and not esc else in_str
        else:
            if c == '"':
                in_str = True
            elif c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
            elif c == ',' and depth == 0:
                records.append(text[start:i].strip())
                start = i + 1
    # 最後のレコード
    end = text.rfind('}')
    if start < end:
        records.append(text[start:end].strip())
    return records

# ――― TIME を拾ってソート ───────────────────────────────────────
def sort_records(records):
    time_re = re.compile(r'"TIME"\s*:\s*(\d+)')
    def key(rec):
        m = time_re.search(rec)
        if not m:
            sys.exit("TIME が見つからないレコードがあります")
        return int(m.group(1))
    return sorted(records, key=key, reverse=True)

def main():
    txt = SRC.read_text(encoding="utf-8")
    recs = split_records(txt)
    recs = sort_records(recs)
    new_txt = '{\n' + ',\n'.join(recs) + '\n}'

    #if args.inplace:
    #    args.file.write_text(new_txt, encoding='utf-8')
    #else:
    sys.stdout.write(new_txt)

if __name__ == '__main__':
    main()
