import os
import re

urdu_regex = re.compile(r'[\u0600-\u06FF]')
hindi_regex = re.compile(r'[\u0900-\u097F]')
bengali_regex = re.compile(r'[\u0980-\u09FF]')
arabic_regex = re.compile(r'[\u0621-\u064A]')

roman_urdu_words = {
    'aap', 'aapka', 'aapke', 'aapki', 'apna', 'apni', 'apne',
    'karein', 'karen', 'karna', 'karta', 'karti', 'karte',
    'bheja', 'bhejein', 'bhejo',
    'pehle', 'pehlain', 'baad',
    'gaya', 'gayi', 'gaye', 'hoga', 'hogi', 'honge', 'hai', 'hain',
    'chahiye', 'nahi', 'nahin', 'sirf', 'shamil', 'intezar', 'khatam',
    'taake', 'taaki', 'mutabiq', 'parhein', 'parho',
    'khiladi', 'muqabla', 'tasdeeq', 'barah', 'barah-e-karam', 'zaroori',
    'wala', 'wali', 'wale', 'dono', 'saaray', 'sab', 'sabse',
    'theek', 'shukriya', 'madad', 'bohot', 'bahut', 'ziyada', 'zyada',
    'rukay', 'rukiye', 'dekhein', 'kholein', 'hatao', 'hataiye'
}

dart_files = []
for root, dirs, files in os.walk('lib'):
    for f in files:
        if f.endswith('.dart'):
            dart_files.append(os.path.join(root, f))

results = []

str_pattern = re.compile(r"""(?:"([^"\\]*(?:\\.[^"\\]*)*)"|'([^'\\]*(?:\\.[^'\\]*)*)')""")

for path in sorted(dart_files):
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except Exception as e:
        continue

    urdu_lines = []
    hindi_lines = []
    bengali_lines = []
    roman_lines = []
    english_ui_lines = []

    for line_num, line in enumerate(content.splitlines(), start=1):
        stripped = line.strip()
        if stripped.startswith('//') or stripped.startswith('/*') or stripped.startswith('*') or stripped.startswith('import ') or stripped.startswith('export '):
            continue

        matches = str_pattern.findall(line)
        for m in matches:
            text = m[0] if m[0] else m[1]
            t_clean = text.strip()

            if len(t_clean) < 2:
                continue
            if t_clean.startswith('assets/') or t_clean.startswith('package:') or t_clean.startswith('dart:'):
                continue
            if t_clean.startswith('http://') or t_clean.startswith('https://'):
                continue
            if f"'{text}'.tr()" in line or f'"{text}".tr()' in line or f"'{text}'.tr(" in line or f'"{text}".tr(' in line:
                continue

            if urdu_regex.search(t_clean):
                urdu_lines.append((line_num, t_clean))
            elif hindi_regex.search(t_clean):
                hindi_lines.append((line_num, t_clean))
            elif bengali_regex.search(t_clean):
                bengali_lines.append((line_num, t_clean))
            else:
                tokens = set(re.findall(r'[a-zA-Z]+', t_clean.lower()))
                matches_roman = tokens.intersection(roman_urdu_words)
                if len(matches_roman) >= 2 or (len(matches_roman) == 1 and len(tokens) >= 3 and any(w in ['aap', 'karein', 'karen', 'hai', 'nahi', 'pehle', 'gaya'] for w in matches_roman)):
                    roman_lines.append((line_num, t_clean))
                elif len(tokens) >= 2 and any(c.isalpha() for c in t_clean):
                    ui_indicators = ['Text(', 'title:', 'subtitle:', 'label:', 'hintText:', 'SnackBar(', 'content:', 'TextSpan(', 'tooltip:']
                    if any(ind in line for ind in ui_indicators):
                        if not any(x in t_clean for x in ['yyyy', 'MM/dd', 'Bearer ', 'Content-Type', 'image/', 'application/', '##', '==', 'flutter', 'dart']):
                            english_ui_lines.append((line_num, t_clean))

    if urdu_lines or hindi_lines or bengali_lines or roman_lines or english_ui_lines:
        results.append({
            'file': path,
            'urdu': urdu_lines,
            'hindi': hindi_lines,
            'bengali': bengali_lines,
            'roman': roman_lines,
            'english': english_ui_lines
        })

print(f"TOTAL_DART_FILES={len(dart_files)}")
print(f"FILES_WITH_HARDCODED={len(results)}")

urdu_files = [r for r in results if r['urdu']]
hindi_files = [r for r in results if r['hindi']]
bengali_files = [r for r in results if r['bengali']]
roman_files = [r for r in results if r['roman']]
english_files = [r for r in results if r['english']]

print(f"FILES_WITH_URDU={len(urdu_files)}")
print(f"FILES_WITH_HINDI={len(hindi_files)}")
print(f"FILES_WITH_BENGALI={len(bengali_files)}")
print(f"FILES_WITH_ROMAN={len(roman_files)}")
print(f"FILES_WITH_ENGLISH_UI={len(english_files)}")

print("\n================== 1. URDU SCRIPT FILES ==================")
for r in urdu_files:
    print(f"\n📁 {r['file']} ({len(r['urdu'])} occurrences):")
    for l_num, text in r['urdu']:
        print(f"   Line {l_num}: {text}")

print("\n================== 2. HINDI SCRIPT FILES ==================")
for r in hindi_files:
    print(f"\n📁 {r['file']} ({len(r['hindi'])} occurrences):")
    for l_num, text in r['hindi']:
        print(f"   Line {l_num}: {text}")

print("\n================== 3. ROMAN URDU / HINDI FILES ==================")
for r in roman_files:
    print(f"\n📁 {r['file']} ({len(r['roman'])} occurrences):")
    for l_num, text in r['roman']:
        print(f"   Line {l_num}: {text}")

print("\n================== 4. HARDCODED ENGLISH UI FILES (COUNT & TOP SAMPLES) ==================")
sorted_eng = sorted(english_files, key=lambda x: len(x['english']), reverse=True)
print(f"Total files with hardcoded English UI strings: {len(sorted_eng)}")
for r in sorted_eng[:25]:
    print(f"📁 {r['file']}: {len(r['english'])} strings (e.g. {r['english'][0][1]!r})")
