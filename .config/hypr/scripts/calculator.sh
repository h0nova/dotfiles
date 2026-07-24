#!/usr/bin/env bash
python3 - "$1" << 'PYEOF'
import sys, math

try:
    expr = sys.argv[1].replace('^', '**').replace(',', '.')
    safe = {k: getattr(math, k) for k in dir(math) if not k.startswith('_')}
    safe.update({'abs': abs, 'round': round})
    result = eval(expr, {'__builtins__': {}}, safe)
    if isinstance(result, float) and result.is_integer() and abs(result) < 1e15:
        print(int(result))
    else:
        print(f'{result:g}')
except:
    sys.exit(1)
PYEOF
