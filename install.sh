#!/usr/bin/env bash
set -euo pipefail

INSTALL_DIR="$HOME/tools/opendataloader"
JAVA_VERSION="17"
OS="$(uname -s)"

echo "=== 1. Détection de l'OS ==="
case "$OS" in
  Darwin*) PLATFORM="macos" ;;
  Linux*)  PLATFORM="linux" ;;
  *) echo "OS non supporté : $OS"; exit 1 ;;
esac
echo "Plateforme : $PLATFORM"

echo ""
echo "=== 2. Java $JAVA_VERSION (pinné, indépendant du reste du PATH) ==="

if [ "$PLATFORM" = "macos" ]; then
  if ! command -v brew &> /dev/null; then
    echo "Homebrew requis mais absent : https://brew.sh"
    exit 1
  fi
  if ! brew list "openjdk@${JAVA_VERSION}" &> /dev/null; then
    echo "Installation d'openjdk@${JAVA_VERSION}..."
    brew install "openjdk@${JAVA_VERSION}"
  fi
  JAVA_HOME_RESOLVED="$(brew --prefix "openjdk@${JAVA_VERSION}")/libexec/openjdk.jdk/Contents/Home"

elif [ "$PLATFORM" = "linux" ]; then
  if command -v apt &> /dev/null; then
    PKG_MGR="apt"
    JAVA_PKG="openjdk-${JAVA_VERSION}-jdk"
    if ! dpkg -l 2>/dev/null | grep -q "openjdk-${JAVA_VERSION}-j"; then
      echo "Installation de ${JAVA_PKG} (apt)..."
      sudo apt update
      sudo apt install -y "$JAVA_PKG"
    fi
  elif command -v dnf &> /dev/null; then
    PKG_MGR="dnf"
    JAVA_PKG="java-${JAVA_VERSION}-openjdk-devel"
    if ! rpm -q "$JAVA_PKG" &> /dev/null; then
      echo "Installation de ${JAVA_PKG} (dnf)..."
      sudo dnf install -y "$JAVA_PKG"
    fi
  else
    echo "Aucun gestionnaire de paquets supporté trouvé (apt ou dnf requis)."
    exit 1
  fi

  JAVA_HOME_RESOLVED="$(dirname "$(dirname "$(readlink -f "$(command -v java || echo /usr/bin/java)")")")"
  if [ ! -x "$JAVA_HOME_RESOLVED/bin/java" ]; then
    # fallback : cherche le chemin standard selon le gestionnaire
    if [ "$PKG_MGR" = "apt" ]; then
      JAVA_HOME_RESOLVED="/usr/lib/jvm/java-${JAVA_VERSION}-openjdk-$(dpkg --print-architecture)"
    else
      JAVA_HOME_RESOLVED=$(dirname "$(dirname "$(update-alternatives --display java 2>/dev/null | grep "${JAVA_VERSION}" | head -1 | awk '{print $1}')")")
    fi
  fi
fi

if [ ! -x "$JAVA_HOME_RESOLVED/bin/java" ]; then
  echo "Binaire java introuvable dans $JAVA_HOME_RESOLVED"
  exit 1
fi
echo "JAVA_HOME : $JAVA_HOME_RESOLVED"
"$JAVA_HOME_RESOLVED/bin/java" -version

echo ""
echo "=== 3. Python >= 3.10 ==="
PYTHON_BIN="$(command -v python3)"
[ -z "$PYTHON_BIN" ] && { echo "python3 introuvable."; exit 1; }
echo "Python : $("$PYTHON_BIN" --version) ($PYTHON_BIN)"

echo ""
echo "=== 4. Environnement virtuel ==="
mkdir -p "$INSTALL_DIR"
if [ ! -d "$INSTALL_DIR/env" ]; then
  "$PYTHON_BIN" -m venv "$INSTALL_DIR/env"
fi

echo ""
echo "=== 5. Package opendataloader-pdf ==="
"$INSTALL_DIR/env/bin/pip" install -U pip -q
"$INSTALL_DIR/env/bin/pip" install -U opendataloader-pdf -q

echo ""
echo "=== 6. Script wrapper ==="
cat > "$INSTALL_DIR/pdf2md.py" << PYEOF
import os
import sys

os.environ["JAVA_HOME"] = "${JAVA_HOME_RESOLVED}"
os.environ["PATH"] = "${JAVA_HOME_RESOLVED}/bin:" + os.environ.get("PATH", "")

import opendataloader_pdf

if len(sys.argv) < 2:
    print("Usage: pdf2md <fichier.pdf> [dossier_sortie]")
    sys.exit(1)

input_path = sys.argv[1]
output_dir = sys.argv[2] if len(sys.argv) > 2 else "."

opendataloader_pdf.convert(
    input_path=input_path,
    output_dir=output_dir,
    format="markdown"
)

print(f"Converti dans {output_dir}")

# Check silencieux de mise à jour disponible (timeout court, jamais bloquant)
def check_update():
    try:
        import json
        import urllib.request
        from importlib.metadata import version as pkg_version

        current = pkg_version("opendataloader-pdf")
        with urllib.request.urlopen(
            "https://pypi.org/pypi/opendataloader-pdf/json", timeout=2
        ) as resp:
            latest = json.loads(resp.read())["info"]["version"]

        if current != latest:
            print(f"\\nMise à jour dispo : {current} -> {latest}")
            print("Lance : pdf2md-update")
    except Exception:
        pass  # pas de réseau, timeout, ou souci quelconque : on ignore silencieusement

check_update()
PYEOF

echo ""
echo "=== 7. Alias shell (append, ne touche pas au reste du fichier) ==="
case "$SHELL" in
  */zsh)  SHELL_RC="$HOME/.zshrc" ;;
  */bash) SHELL_RC="$HOME/.bashrc" ;;
  *)      SHELL_RC="$HOME/.profile" ;;
esac
MARKER="# >>> opendataloader pdf2md >>>"
END_MARKER="# <<< opendataloader pdf2md <<<"

if [ -f "$SHELL_RC" ] && grep -qF "$MARKER" "$SHELL_RC"; then
  echo "Alias déjà présent, rien à faire."
else
  {
    echo ""
    echo "$MARKER"
    echo "pdf2md() {"
    echo "  \"$INSTALL_DIR/env/bin/python3\" \"$INSTALL_DIR/pdf2md.py\" \"\$@\""
    echo "}"
    echo "pdf2md-update() {"
    echo "  \"$INSTALL_DIR/env/bin/pip\" install -U opendataloader-pdf"
    echo "}"
    echo "$END_MARKER"
  } >> "$SHELL_RC"
  echo "Alias ajouté à $SHELL_RC"
fi

echo ""
echo "Terminé. Recharge ton shell puis teste :"
echo "  source $SHELL_RC"
echo "  pdf2md mondocument.pdf"
echo ""
echo "Pour mettre à jour le package plus tard :"
echo "  pdf2md-update"