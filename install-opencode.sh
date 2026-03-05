#!/usr/bin/env bash
# SDD Custom Kit — OpenCode Installer
#
# USAGE: bash install-opencode.sh [--force]
#
# Copia el kit a ~/.config/opencode/skills/custom-sdd-kit/, registra los
# /sdd.* commands como skills de OpenCode, parchea opencode.json con los
# permisos necesarios, y agrega el bloque orquestador al AGENTS.md global.
#
# Compatibilidad: OpenCode busca skills en múltiples rutas, incluyendo
# ~/.claude/skills/ — si ya corriste install.sh (Claude Code), las skills
# están disponibles. Este script agrega lo específico de OpenCode.
#
# --force: sobreescribe wrappers de skills ya existentes (para actualizar)

set -euo pipefail

KIT_SOURCE="$(cd "$(dirname "$0")" && pwd)"
OPENCODE_DIR="$HOME/.config/opencode"
OPENCODE_SKILLS="$OPENCODE_DIR/skills"
KIT_DEST="$OPENCODE_SKILLS/custom-sdd-kit"
OPENCODE_JSON="$OPENCODE_DIR/opencode.json"
AGENTS_MD="$OPENCODE_DIR/AGENTS.md"
FORCE=false

if [[ "${1:-}" == "--force" ]]; then
  FORCE=true
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()    { echo -e "${CYAN}[sdd-kit]${NC} $1"; }
ok()     { echo -e "${GREEN}  ✓${NC} $1"; }
skip()   { echo -e "${YELLOW}  -${NC} $1 (sin cambios)"; }
update() { echo -e "${GREEN}  ↑${NC} $1 (actualizado)"; }
warn()   { echo -e "${YELLOW}  ⚠${NC} $1"; }

echo ""
log "SDD Custom Kit — OpenCode installer"
log "Fuente: $KIT_SOURCE"
log "Destino: $KIT_DEST"
echo ""

# ---------------------------------------------------------------------------
# 1. Verificar que el kit fuente está completo
# ---------------------------------------------------------------------------
for required in "_shared" "agents" "skills" "CLAUDE-INTEGRATION.md"; do
  if [[ ! -e "$KIT_SOURCE/$required" ]]; then
    echo "ERROR: Falta $KIT_SOURCE/$required — ¿estás ejecutando desde la raíz del repo?"
    exit 1
  fi
done

# ---------------------------------------------------------------------------
# 2. Copiar/sincronizar kit a ~/.config/opencode/skills/custom-sdd-kit/
# ---------------------------------------------------------------------------
log "Sincronizando kit a $KIT_DEST ..."
echo ""

mkdir -p "$KIT_DEST"

for dir in _shared agents skills; do
  if rsync -a --checksum "$KIT_SOURCE/$dir/" "$KIT_DEST/$dir/" 2>/dev/null; then
    ok "$dir/"
  else
    cp -r "$KIT_SOURCE/$dir/." "$KIT_DEST/$dir/"
    ok "$dir/ (cp)"
  fi
done

for file in CLAUDE-INTEGRATION.md README.md; do
  if [[ -f "$KIT_SOURCE/$file" ]]; then
    cp "$KIT_SOURCE/$file" "$KIT_DEST/$file"
    ok "$file"
  fi
done

echo ""

# ---------------------------------------------------------------------------
# 3. Registrar wrapper SKILL.md files en ~/.config/opencode/skills/sdd.*/
# ---------------------------------------------------------------------------

register_skill() {
  local cmd="$1"
  local desc="$2"
  local skill_file="$3"

  local target_dir="$OPENCODE_SKILLS/$cmd"
  local target_file="$target_dir/SKILL.md"

  if [[ "$skill_file" == "inline" ]]; then
    local body="Command: /$cmd

Read the inline command instructions at \`$KIT_DEST/skills/sdd.inline.md\` and execute the section for \`/$cmd\`."
  else
    local body="Command: /$cmd

Read the full skill definition at \`$KIT_DEST/skills/$skill_file\` and execute it."
  fi

  local new_content="---
name: $cmd
description: >
  [SDD Custom Kit] $desc
  Trigger: /$cmd
license: MIT
metadata:
  author: sdd-custom-kit
  version: \"1.0\"
---

$body"

  if [[ -f "$target_file" ]] && [[ "$FORCE" == false ]]; then
    existing=$(cat "$target_file")
    if [[ "$existing" == "$new_content" ]]; then
      skip "$cmd"
      return
    else
      mkdir -p "$target_dir"
      echo "$new_content" > "$target_file"
      update "$cmd"
      return
    fi
  fi

  mkdir -p "$target_dir"
  echo "$new_content" > "$target_file"
  ok "$cmd"
}

log "Registrando /sdd.* skills en $OPENCODE_SKILLS ..."
echo ""

register_skill "sdd.init"        "Initialize SDD structure in the current project. Creates sdd/ dir and PROJECT.md."               "sdd.init.md"
register_skill "sdd.new"         "Start a new feature or change with an exploration and proposal."                                  "sdd.new.md"
register_skill "sdd.ff"          "Fast-forward: create all planning artifacts (spec + design + tasks) in one shot."                 "sdd.ff.md"
register_skill "sdd.spec"        "Write functional and technical specs for a feature."                                               "sdd.spec.md"
register_skill "sdd.design"      "Create technical design document with architecture decisions."                                     "sdd.design.md"
register_skill "sdd.plan"        "Break down a feature into a structured implementation task list."                                  "sdd.plan.md"
register_skill "sdd.build"       "Implement tasks from the plan with optional TDD and quality gates."                                "sdd.build.md"
register_skill "sdd.verify"      "Run tests and validate implementation against specs."                                              "sdd.verify.md"
register_skill "sdd.git"         "Code review + security scan + commit or PR workflow."                                              "sdd.git.md"
register_skill "sdd.finish"      "Full finish flow: verify + git + archive in sequence."                                             "sdd.finish.md"
register_skill "sdd.go"          "Express mode: full SDD workflow from idea to implementation without pauses."                       "sdd.go.md"
register_skill "sdd.check"       "Spec compliance check — non-blocking, shows COMPLIANT/PARTIAL/MISSING per scenario."               "sdd.check.md"
register_skill "sdd.fix"         "Debug and fix a reported issue using the sdd-debugger agent."                                      "sdd.fix.md"
register_skill "sdd.reverse-eng" "Reverse engineer existing code into SDD artifacts (spec + design)."                               "sdd.reverse-eng.md"
register_skill "sdd.backlog"     "Manage the feature backlog: add, list, done, remove items."                                        "sdd.backlog.md"
register_skill "sdd.archive"     "Archive a completed feature, moving it from wip/ to features/."                                    "sdd.archive.md"
register_skill "sdd.compact"     "Compact session context to save tokens using sdd-context-compactor."                               "sdd.compact.md"
register_skill "sdd.list"        "List all WIP and archived features in the current project."                                        "inline"
register_skill "sdd.cancel"      "Cancel a WIP feature, updating its meta.md status to cancelled."                                  "inline"
register_skill "sdd.rollback"    "Rollback a feature's git changes to its branching point."                                          "inline"
register_skill "sdd.help"        "Show available SDD commands with descriptions and usage examples."                                 "inline"

echo ""

# ---------------------------------------------------------------------------
# 4. Parchear AGENTS.md global con el bloque orquestador
# ---------------------------------------------------------------------------
log "Verificando AGENTS.md global ..."

mkdir -p "$OPENCODE_DIR"

ORCHESTRATOR_BLOCK='## SDD Custom Kit — Orchestrator'

# Extraer el bloque de CLAUDE-INTEGRATION.md y adaptar rutas para OpenCode
RAW_BLOCK=$(sed -n '/^```markdown$/,/^```$/p' "$KIT_DEST/CLAUDE-INTEGRATION.md" | sed '1d;$d')

if [[ -z "$RAW_BLOCK" ]]; then
  echo "ERROR: No se pudo extraer el bloque de CLAUDE-INTEGRATION.md"
  exit 1
fi

# Adaptar ruta del kit: ~/.claude/skills → ~/.config/opencode/skills
ADAPTED_BLOCK=$(echo "$RAW_BLOCK" | sed "s|~/.claude/skills/custom-sdd-kit/|$KIT_DEST/|g")

if grep -qF "$ORCHESTRATOR_BLOCK" "$AGENTS_MD" 2>/dev/null; then
  skip "AGENTS.md ya contiene el bloque orquestador"
else
  log "Agregando bloque orquestador a $AGENTS_MD ..."
  printf '\n%s\n' "$ADAPTED_BLOCK" >> "$AGENTS_MD"
  ok "AGENTS.md parcheado"
fi

echo ""

# ---------------------------------------------------------------------------
# 5. Parchear opencode.json con los permisos del kit
# ---------------------------------------------------------------------------
log "Verificando permisos en opencode.json ..."
echo ""

# Crear opencode.json mínimo si no existe
if [[ ! -f "$OPENCODE_JSON" ]]; then
  echo '{"$schema":"https://opencode.ai/config.json","permissions":{"allow":[]}}' > "$OPENCODE_JSON"
  ok "opencode.json creado"
fi

SDD_PERMISSIONS=(
  "Task(*)"
  "Read(~/.config/opencode/skills/custom-sdd-kit/**)"
  "Read(~/.config/opencode/skills/sdd.*/**)"
  "Skill(sdd.*)"
)

patch_permission() {
  local perm="$1"
  local settings="$2"

  if grep -qF "\"$perm\"" "$settings" 2>/dev/null; then
    skip "permissions: $perm"
    return
  fi

  if command -v jq &>/dev/null; then
    local tmp
    tmp=$(mktemp)
    jq --arg p "$perm" '.permissions.allow += [$p]' "$settings" > "$tmp" && mv "$tmp" "$settings"
  else
    python3 - "$settings" "$perm" <<'PYEOF'
import sys, json
path, perm = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
data.setdefault("permissions", {}).setdefault("allow", [])
if perm not in data["permissions"]["allow"]:
    data["permissions"]["allow"].append(perm)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PYEOF
  fi
  ok "permissions: $perm"
}

for perm in "${SDD_PERMISSIONS[@]}"; do
  patch_permission "$perm" "$OPENCODE_JSON"
done

echo ""

# ---------------------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------------------
log "Instalación completa."
echo ""
echo -e "  Kit instalado en: ${CYAN}$KIT_DEST${NC}"
echo -e "  Config:           ${CYAN}$OPENCODE_JSON${NC}"
echo -e "  Instrucciones:    ${CYAN}$AGENTS_MD${NC}"
echo -e "  Probar con:       ${CYAN}/sdd.help${NC}"
echo ""
echo "  NOTA: OpenCode también detecta skills en ~/.claude/skills/"
echo "  Si ya corriste install.sh (Claude Code), ambos herramientas"
echo "  comparten las mismas definiciones de agentes."
echo ""
echo "  Para actualizar después de cambios en el repo:"
echo "    bash $KIT_SOURCE/install-opencode.sh"
echo ""
