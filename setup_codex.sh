#!/usr/bin/env bash
# Customizable Codex setup: reads base_url + api_key from codex_info.yaml
# Rotates now -> last1 -> last2 -> last3 -> last4, applies to ~/.codex/{config.toml,auth.json}
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YAML_FILE="$SCRIPT_DIR/codex_info.yaml"
CODEX_DIR="$HOME/.codex"
BACKUP_DIR="$HOME/codex_copy"
CONFIG_TOML="$CODEX_DIR/config.toml"
AUTH_JSON="$CODEX_DIR/auth.json"

mkdir -p "$CODEX_DIR" "$BACKUP_DIR"

# --- backup current files (raw snapshot, same as 02 script) ---
backup_if_exists() {
  local src="$1" name="$2"
  if [ -e "$src" ]; then
    rm -rf "$BACKUP_DIR/$name"
    cp -r --no-preserve=mode,ownership "$src" "$BACKUP_DIR/$name"
  fi
}
backup_if_exists "$CONFIG_TOML" "config.toml.codex.bak"
backup_if_exists "$AUTH_JSON"   "auth.json.codex.bak"

# --- bootstrap yaml if missing ---
if [ ! -f "$YAML_FILE" ]; then
  cur_url=""
  cur_key=""
  if [ -f "$CONFIG_TOML" ]; then
    cur_url=$(python3 -c "
import re, sys
t = open('$CONFIG_TOML').read()
m = re.search(r'\[model_providers\.crs\][^\[]*', t)
if m:
    mm = re.search(r'base_url\s*=\s*\"([^\"]*)\"', m.group(0))
    if mm: print(mm.group(1))
")
  fi
  if [ -f "$AUTH_JSON" ]; then
    cur_key=$(python3 -c "import json; print(json.load(open('$AUTH_JSON')).get('OPENAI_API_KEY',''))")
  fi
  cat > "$YAML_FILE" <<EOF
# Edit the 'now' section with the base_url and api_key you want to apply.
# On each run, 'now' is rotated into last1; last1->last2; ...; last4 is dropped.
now:
  base_url: "$cur_url"
  api_key: "$cur_key"
last1:
  base_url: ""
  api_key: ""
last2:
  base_url: ""
  api_key: ""
last3:
  base_url: ""
  api_key: ""
last4:
  base_url: ""
  api_key: ""
EOF
  echo "[07] Bootstrapped $YAML_FILE from current ~/.codex state."
  echo "[07] Edit the 'now' section, then re-run this script."
  exit 0
fi

# --- python core: parse yaml, rotate, apply to config.toml + auth.json ---
python3 - "$YAML_FILE" "$CONFIG_TOML" "$AUTH_JSON" <<'PYEOF'
import json, re, sys, os

yaml_path, toml_path, auth_path = sys.argv[1], sys.argv[2], sys.argv[3]

# --- minimal flat-yaml parser (sections: now, last1..last4; each has base_url, api_key) ---
def parse_yaml(p):
    data = {}
    cur = None
    with open(p) as f:
        for raw in f:
            line = raw.rstrip("\n")
            s = line.strip()
            if not s or s.startswith("#"):
                continue
            if not line.startswith(" ") and s.endswith(":"):
                cur = s[:-1]
                data[cur] = {}
            elif cur is not None and ":" in s:
                k, v = s.split(":", 1)
                v = v.strip()
                if v.startswith('"') and v.endswith('"'):
                    v = v[1:-1]
                data[cur][k.strip()] = v
    return data

def dump_yaml(data, p):
    order = ["now", "last1", "last2", "last3", "last4"]
    lines = [
        "# Edit the 'now' section with the base_url and api_key you want to apply.",
        "# On each run, 'now' is rotated into last1; last1->last2; ...; last4 is dropped.",
    ]
    for sec in order:
        d = data.get(sec, {"base_url": "", "api_key": ""})
        lines.append(f"{sec}:")
        lines.append(f'  base_url: "{d.get("base_url","")}"')
        lines.append(f'  api_key: "{d.get("api_key","")}"')
    with open(p, "w") as f:
        f.write("\n".join(lines) + "\n")

data = parse_yaml(yaml_path)
now = data.get("now", {})
new_url = now.get("base_url", "").strip()
new_key = now.get("api_key", "").strip()
if not new_url or not new_key:
    print("[07][ERR] 'now.base_url' or 'now.api_key' is empty in yaml. Fill them first.")
    sys.exit(1)

# determine previous applied state from actual files (source of truth for 'what was live')
prev_url = ""
prev_key = ""
if os.path.exists(toml_path):
    t = open(toml_path).read()
    m = re.search(r'\[model_providers\.crs\][^\[]*', t)
    if m:
        mm = re.search(r'base_url\s*=\s*"([^"]*)"', m.group(0))
        if mm:
            prev_url = mm.group(1)
if os.path.exists(auth_path):
    try:
        prev_key = json.load(open(auth_path)).get("OPENAI_API_KEY", "")
    except Exception:
        pass

# rotate only if prev differs from new (avoid polluting history with duplicates)
if prev_url != new_url or prev_key != new_key:
    data["last4"] = data.get("last3", {"base_url":"","api_key":""})
    data["last3"] = data.get("last2", {"base_url":"","api_key":""})
    data["last2"] = data.get("last1", {"base_url":"","api_key":""})
    data["last1"] = {"base_url": prev_url, "api_key": prev_key}
data["now"] = {"base_url": new_url, "api_key": new_key}
dump_yaml(data, yaml_path)

# --- apply to config.toml ---
if os.path.exists(toml_path):
    t = open(toml_path).read()
else:
    t = ""

# ensure required top-level keys exist
def ensure_top(text, key, value_literal):
    if re.search(rf'(?m)^\s*{re.escape(key)}\s*=', text):
        return re.sub(rf'(?m)^\s*{re.escape(key)}\s*=.*$', f'{key} = {value_literal}', text)
    return f'{key} = {value_literal}\n' + text

if not t.strip():
    t = (
        'model_provider = "crs"\n'
        'model = "gpt-5.4"\n'
        'preferred_auth_method = "apikey"\n'
        'disable_response_storage = true\n\n'
        '[model_providers.crs]\n'
        'name = "crs"\n'
        f'base_url = "{new_url}"\n'
        'wire_api = "responses"\n'
        'requires_openai_auth = true\n'
    )
else:
    # update base_url inside [model_providers.crs] block only
    def repl_block(m):
        block = m.group(0)
        if re.search(r'base_url\s*=\s*"[^"]*"', block):
            block = re.sub(r'base_url\s*=\s*"[^"]*"', f'base_url = "{new_url}"', block, count=1)
        else:
            # insert after the section header
            block = re.sub(r'(\[model_providers\.crs\]\n)', r'\1' + f'base_url = "{new_url}"\n', block, count=1)
        return block
    if re.search(r'\[model_providers\.crs\]', t):
        t = re.sub(r'\[model_providers\.crs\][^\[]*', repl_block, t, count=1)
    else:
        t = t.rstrip() + (
            '\n\n[model_providers.crs]\n'
            'name = "crs"\n'
            f'base_url = "{new_url}"\n'
            'wire_api = "responses"\n'
            'requires_openai_auth = true\n'
        )

with open(toml_path, "w") as f:
    f.write(t)

# --- apply to auth.json ---
auth = {}
if os.path.exists(auth_path):
    try:
        auth = json.load(open(auth_path))
    except Exception:
        auth = {}
auth["auth_mode"] = "apikey"
auth["OPENAI_API_KEY"] = new_key
with open(auth_path, "w") as f:
    json.dump(auth, f, indent=2)
    f.write("\n")

print(f"[07] Applied base_url={new_url}")
print(f"[07] Applied api_key={'*'*6}{new_key[-4:] if len(new_key)>=4 else ''}")
PYEOF

chmod 600 "$CONFIG_TOML" "$AUTH_JSON"

# --- clean OpenAI official env vars from .bashrc (prevent shell overrides from interfering) ---
BASHRC="$HOME/.bashrc"
if [ -f "$BASHRC" ]; then
  for var in OPENAI_API_KEY OPENAI_BASE_URL OPENAI_ORG_ID OPENAI_ORGANIZATION OPENAI_PROJECT_ID; do
    # --follow-symlinks: .bashrc may be a symlink (see commit a7f5ce0)
    sed -i --follow-symlinks "/^\s*export\s\+${var}=/d;/^\s*${var}=/d" "$BASHRC" || true
    unset "$var" || true
  done
fi

# --- preserve 02 script behaviors: sandbox bypass + tmux env cleanup ---
if ! grep -q "HUMANIZE_CODEX_BYPASS_SANDBOX" "$BASHRC" 2>/dev/null; then
  echo "" >> "$BASHRC"
  echo "# Codex sandbox bypass - bwrap not supported on this cluster (HPC/container)" >> "$BASHRC"
  echo "export HUMANIZE_CODEX_BYPASS_SANDBOX=true" >> "$BASHRC"
fi
export HUMANIZE_CODEX_BYPASS_SANDBOX=true

if [ -n "${TMUX:-}" ]; then
  tmux set-environment -g -u OPENAI_API_KEY 2>/dev/null || true
  tmux set-environment -g -u OPENAI_BASE_URL 2>/dev/null || true
  tmux set-environment -g -u MY_PROXY_BASE_URL 2>/dev/null || true
  tmux set-environment -g HUMANIZE_CODEX_BYPASS_SANDBOX true 2>/dev/null || true
fi

cat <<EOF
Codex custom setup complete.
  yaml:   $YAML_FILE
  config: $CONFIG_TOML
  auth:   $AUTH_JSON
  backup: $BACKUP_DIR
  sandbox bypass: enabled
EOF
