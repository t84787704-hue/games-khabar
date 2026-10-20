import os
import re
import json

existing_en_path = 'assets/translations/en.json'
with open(existing_en_path, 'r', encoding='utf-8') as f:
    existing_keys = json.load(f)

print(f"Loaded {len(existing_keys)} existing keys from en.json")

# We want to scan all dart files in lib/
dart_files = []
for root, dirs, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            dart_files.append(os.path.join(root, file))

print(f"Total Dart files to scan: {len(dart_files)}")

# 1. Collect all already used .tr() keys in Dart files
tr_key_pattern = re.compile(r"['\"]([a-zA-Z0-9_]+)['\"]\s*\.tr\s*\(")
all_tr_keys_found = set()

for fpath in dart_files:
    try:
        with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
            code = f.read()
        for match in tr_key_pattern.finditer(code):
            all_tr_keys_found.add(match.group(1))
    except Exception as e:
        pass

print(f"Found {len(all_tr_keys_found)} distinct .tr() keys in code")

# 2. Extract UI strings from code
# Common UI string patterns
# Text('...'), Text("...")
# hintText: '...'
# labelText: '...'
# tooltip: '...'
# SnackBar(content: Text('...'))
# AppBar(title: Text('...'))
# AlertDialog(title: Text('...'), content: Text('...'))
# Tab(text: '...')
# validator: ... '...'

ui_string_patterns = [
    # Text widget
    re.compile(r'''Text\s*\(\s*(['"])(.*?)\1''', re.DOTALL),
    # TextSpan
    re.compile(r'''TextSpan\s*\([^)]*?text\s*:\s*(['"])(.*?)\1''', re.DOTALL),
    # hintText
    re.compile(r'''hintText\s*:\s*(['"])(.*?)\1''', re.DOTALL),
    # labelText
    re.compile(r'''labelText\s*:\s*(['"])(.*?)\1''', re.DOTALL),
    # helperText
    re.compile(r'''helperText\s*:\s*(['"])(.*?)\1''', re.DOTALL),
    # tooltip
    re.compile(r'''tooltip\s*:\s*(['"])(.*?)\1''', re.DOTALL),
    # Tab text
    re.compile(r'''Tab\s*\([^)]*?text\s*:\s*(['"])(.*?)\1''', re.DOTALL),
    # label: Text('...') or label: '...'
    re.compile(r'''label\s*:\s*(['"])(.*?)\1''', re.DOTALL),
    # SnackBar content
    re.compile(r'''SnackBar\s*\([^)]*?content\s*:\s*Text\s*\(\s*(['"])(.*?)\1''', re.DOTALL),
    # title / subtitle in ListTile or Dialog
    re.compile(r'''title\s*:\s*Text\s*\(\s*(['"])(.*?)\1''', re.DOTALL),
    re.compile(r'''subtitle\s*:\s*Text\s*\(\s*(['"])(.*?)\1''', re.DOTALL),
]

def clean_key_name(text):
    # remove format args, interpolation like $name or ${user.name}
    cleaned = re.sub(r'\$\{?[a-zA-Z0-9_.]+\}?', '', text)
    # lowercase
    cleaned = cleaned.lower()
    # replace non-alphanumeric with underscore
    cleaned = re.sub(r'[^a-z0-9]+', '_', cleaned)
    # strip leading/trailing underscores
    cleaned = cleaned.strip('_')
    # truncate if too long
    words = cleaned.split('_')
    if len(words) > 6:
        cleaned = '_'.join(words[:6])
    return cleaned

# Store extracted hardcoded strings per file
hardcoded_by_file = {}
new_keys_map = {} # key -> string

# Ignored patterns (not user facing, assets, colors, urls, code, single char / emojis, etc.)
ignored_prefixes = ('http://', 'https://', 'assets/', 'package:', 'images/', 'lib/', 'icons/', '@', '#', 'fonts/', '/')
ignored_exact = {'', ' ', ':', '-', '|', '/', '*', '+', '•', '...', '---', 'null', 'true', 'false', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9'}

for fpath in dart_files:
    file_strings = set()
    try:
        with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
            code = f.read()
    except Exception:
        continue

    for pat in ui_string_patterns:
        for match in pat.finditer(code):
            s = match.group(2).strip()
            # filter out non-UI strings
            if not s or s in ignored_exact or len(s) < 2:
                continue
            if any(s.startswith(p) for p in ignored_prefixes):
                continue
            if s.endswith('.png') or s.endswith('.jpg') or s.endswith('.svg') or s.endswith('.json') or s.endswith('.ttf') or s.endswith('.mp4'):
                continue
            if s.startswith('0x') or (s.startswith('#') and len(s) in (4, 7, 9)):
                continue
            # ignore if it's already a translation key (e.g. 'nav_feed')
            if s in existing_keys or s in all_tr_keys_found:
                continue
            # ignore date formats or regex like 'yyyy-MM-dd' or 'hh:mm a'
            if s in ('hh:mm a', 'yyyy-MM-dd', 'dd/MM/yyyy', 'MM/dd/yyyy', 'dd MMM yyyy', 'MMM dd, yyyy'):
                continue
            # ignore purely numbers/symbols
            if re.match(r'^[0-9\s\-_:.,!@#$%^&*()+=/\\|<>\[\]{}]+$', s):
                continue

            file_strings.add(s)

    if file_strings:
        hardcoded_by_file[fpath] = file_strings
        for s in file_strings:
            k = clean_key_name(s)
            if k and len(k) >= 2:
                if k not in new_keys_map:
                    new_keys_map[k] = s

print(f"Files with hardcoded strings: {len(hardcoded_by_file)}")
print(f"Total new candidate keys: {len(new_keys_map)}")

# Combine all keys: existing_keys + all_tr_keys_found + new_keys_map
all_keys_set = set(existing_keys.keys()) | all_tr_keys_found | set(new_keys_map.keys())
sorted_keys = sorted(list(all_keys_set))

output_json = {k: "" for k in sorted_keys}

with open('all_strings_keys.json', 'w', encoding='utf-8') as f:
    json.dump(output_json, f, indent=2, ensure_ascii=False)

summary = {
    "total_keys": len(sorted_keys),
    "existing_keys_in_json": len(existing_keys),
    "already_in_json_count": len(set(existing_keys.keys()) & all_keys_set),
    "new_keys_count": len(all_keys_set - set(existing_keys.keys())),
    "files_with_hardcoded": sorted(list(hardcoded_by_file.keys()))
}

with open('summary_report.json', 'w', encoding='utf-8') as f:
    json.dump(summary, f, indent=2, ensure_ascii=False)

print("Scan complete! Output written to all_strings_keys.json and summary_report.json")
