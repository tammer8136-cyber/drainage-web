import re

with open('drainage_core.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Паттерн: _Solution( с P и vIndex но без F, T, L
pattern = r'_Solution\(\s*P:\s*(\w+),\s*vIndex:\s*(\w+),\s*score:\s*[\d.]+,?\s*\)'

def replacement(match):
    return f'''_Solution(
                  P: {match.group(1)},
                  vIndex: {match.group(2)},
                  score: 0,
                  F: F,
                  T: T,
                  L: L,
                )'''

# Заменяем
new_content = re.sub(pattern, replacement, content)

with open('drainage_core.dart', 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Замены выполнены!")
