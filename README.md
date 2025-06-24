# Bootscan

**Bootscan** est un script Bash conçu pour automatiser les tâches répétitives du début d'un pentest ou d'un challenge CTF, comme l'ajout d'alias dans `/etc/hosts`, les scans de ports et l’énumération des services web et SMB.  
Je l'ai créé pour gagner du temps et éviter de retaper sans cesse les mêmes commandes à chaque nouveau challenge ou audit.

---

## 🚀 Fonctionnalités

- **Ajout rapide d'alias** dans `/etc/hosts`
- **Scan Nmap** (tous ports, scripts, versions)
- **Énumération web** (`curl`, `gobuster`)
- **Énumération SMB**
- **Résultats sauvegardés** dans `/tmp/bootscan/<alias>/`

---

## 💻 Utilisation

```
./bootscan.sh -add <ip/alias> <alias>       # Ajoute un alias à une IP ou une entrée existante
./bootscan.sh <ip> <alias>                  # Scan et énum rapide
./bootscan.sh -scan <alias>                 # Affiche ou lance le scan nmap pour <alias>
./bootscan.sh -enum <alias>                 # Affiche ou lance l’énum web pour <alias>
./bootscan.sh -h                            # Affiche l’aide
```

## Exemple
```
sudo ./bootscan.sh 10.10.10.10 artificial.htb
./bootscan.sh -enum artificial.htb
./bootscan.sh -add artificial artificial.htb
```

### 🛠️ Prérequis
- bash
- nmap
- curl
- gobuster ou dirb
- smbclient (pour l’énum SMB)
  
### 📄 Licence
MIT

### 👤 Auteur
Ameco-dev
