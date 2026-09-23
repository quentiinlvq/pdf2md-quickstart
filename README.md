# pdf2md-setup

Script d'install pour convertir des PDF en Markdown en local, via
[OpenDataLoader PDF](https://github.com/opendataloader-project/opendataloader-pdf).

Rien d'envoyé sur internet, tout tourne sur ta machine (CPU, pas besoin de GPU).

## Ce que ça fait

- Installe Java 17 (pinné, n'interfère pas avec d'autres versions déjà présentes)
- Crée un venv Python isolé
- Installe `opendataloader-pdf`
- Ajoute une commande `pdf2md` dans ton shell

Testé sur macOS (zsh), Debian/Ubuntu (apt) et RHEL/Fedora (dnf).

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/quentiinlvq/pdf2md-quickstart/main/install.sh -o install.sh
cat install.sh   # vérifie ce que ça fait avant de lancer
chmod +x install.sh
./install.sh
source ~/.zshrc
```

## Utilisation

```bash
pdf2md document.pdf
pdf2md document.pdf ./dossier-sortie
```

Le markdown est généré dans le dossier de sortie (ou le dossier courant par
défaut).

## Pourquoi

`opendataloader-pdf` marche bien mais a deux frictions à l'install :
plusieurs Java sur la machine créent des conflits, et le venv Python doit
être isolé proprement. Ce script règle les deux une fois pour toutes.

## Prérequis

- Python 3.10+
- macOS : Homebrew installé
- Linux : `apt` (Debian/Ubuntu) ou `dnf` (RHEL/Fedora)

## Relancer / réinstaller

Le script est idempotent, tu peux le relancer sans risque ; il ne
réinstalle pas ce qui existe déjà et n'ajoute jamais deux fois l'alias.

## Licence

MIT