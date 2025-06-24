# Bootscan

**Bootscan** est un script Bash pour automatiser l’ajout d’alias dans `/etc/hosts`, le scan de ports et l’énumération de services web et SMB lors d’un pentest, CTF ou audit.

## Fonctionnalités

- Ajout d’alias rapidement
- Scan Nmap (all ports, scripts, versions)
- Énumération web (curl, gobuster/dirb)
- Énumération SMB
- Résultats sauvegardés dans `/tmp/bootscan/<alias>/`

## Utilisation

./bootscan.sh -add <ip/alias> <alias>       # Ajoute un alias à une IP ou une entrée existante
./bootscan.sh <ip> <alias>                  # Scan et énum rapide
./bootscan.sh -scan <alias>                 # Affiche ou lance le scan nmap pour <alias>
./bootscan.sh -enum <alias>                 # Affiche ou lance l’énum web pour <alias>
./bootscan.sh -h                            # Affiche l’aide

Exemple :
sudo ./bootscan.sh 10.10.10.10 artificial.htb
./bootscan.sh -enum artificial.htb

Prérequis :
bash
nmap
curl
gobuster
smbclient (pour l’énum SMB)

Licence
MIT

Auteur
Ameco-dev
