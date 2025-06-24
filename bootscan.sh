#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

STORE="/tmp/bootscan"
WORDLIST="/usr/share/dirb/wordlists/common.txt"

usage() {
    echo -e "${CYAN}Bootscan usage:${NC}"
    echo -e "  bootscan -add <ip/alias> <alias>       # Ajoute un alias à une IP ou à une entrée existante"
    echo -e "  bootscan <ip> <alias>                  # Ajoute dans /etc/hosts si besoin, scan nmap, enum rapide"
    echo -e "  bootscan -scan <alias>                 # Affiche ou lance le scan nmap pour <alias>"
    echo -e "  bootscan -enum <alias>                 # Affiche ou lance l'énum web pour <alias>"
    echo -e "  bootscan -h                            # Affiche cette aide"
}

add_hosts() {
    TARGET="$1"
    NEWALIAS="$2"
    if [[ $TARGET =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        IP="$TARGET"
    else
        IP=$(grep -w "$TARGET" /etc/hosts | awk '{print $1}' | head -n 1)
        if [ -z "$IP" ]; then
            echo -e "${RED}[!] Impossible de trouver l'IP liée à $TARGET dans /etc/hosts${NC}"
            exit 1
        fi
    fi

    LINE=$(grep -E "^$IP\s" /etc/hosts)
    if [ -z "$LINE" ]; then
        echo "$IP    $NEWALIAS" | sudo tee -a /etc/hosts
        echo -e "${GREEN}[+] Ajouté : $IP $NEWALIAS dans /etc/hosts${NC}"
    else
        CURRENT_ALIASES=$(echo "$LINE" | cut -d' ' -f2-)
        if ! echo "$CURRENT_ALIASES" | grep -wq "$NEWALIAS"; then
            UPDATED_ALIASES=$(echo "$CURRENT_ALIASES $NEWALIAS" | xargs -n1 | sort -u | xargs)
            TMPFILE=$(mktemp)
            awk -v ip="$IP" -v aliases="$UPDATED_ALIASES" \
                '{if($1==ip) print ip"\t"aliases; else print $0}' /etc/hosts > "$TMPFILE"
            if sudo sh -c "cat '$TMPFILE' > /etc/hosts"; then
                echo -e "${GREEN}[+] Ligne mise à jour : $IP $UPDATED_ALIASES${NC}"
            else
                echo -e "${RED}[!] Impossible de modifier automatiquement /etc/hosts !"
                echo -e "Ajoute manuellement cette ligne :\n$IP    $UPDATED_ALIASES${NC}"
            fi
            rm -f "$TMPFILE"
        else
            echo -e "${YELLOW}[!] L'alias est déjà présent pour $IP${NC}"
        fi
    fi
}

get_ip_from_alias() {
    ALIAS="$1"
    IP=$(grep -w "$ALIAS" /etc/hosts | awk '{print $1}' | head -n1)
    if [ -z "$IP" ]; then
        echo ""
    else
        echo "$IP"
    fi
}

scan() {
    IP="$1"
    ALIAS="$2"
    mkdir -p "$STORE/$ALIAS"

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}🚀 Bootscan - Pentest Quickstart : $ALIAS ($IP)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    add_hosts "$IP" "$ALIAS"

    echo -e "${YELLOW}[1/3]${NC} ${CYAN}Scan Nmap all ports...${NC}"
    nmap -p- -T5 --open "$IP" | tee "$STORE/$ALIAS/nmap-all.txt"

    OPEN_PORTS=$(grep -E '^[0-9]+/tcp' "$STORE/$ALIAS/nmap-all.txt" | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//')
    if [ -z "$OPEN_PORTS" ]; then
        echo -e "${RED}Aucun port ouvert trouvé.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}[2/3]${NC} ${CYAN}Nmap scripts/versions sur : $OPEN_PORTS${NC}"
    nmap -sC -sV -p "$OPEN_PORTS" "$IP" | tee "$STORE/$ALIAS/nmap-enum.txt"

    echo -e "${YELLOW}[3/3]${NC} ${CYAN}Énumération rapide:${NC}"

    ENUMFILE="$STORE/$ALIAS/enum.txt"
    echo -n "" > "$ENUMFILE"

    # ENUM WEB
    if echo "$OPEN_PORTS" | grep -q "80"; then
        echo -e "  ${GREEN}HTTP${NC} :" | tee -a "$ENUMFILE"
        echo -e "    [*] curl -I http://$ALIAS" | tee -a "$ENUMFILE"
        curl -sI "http://$ALIAS" | tee -a "$ENUMFILE"
        if command -v gobuster >/dev/null 2>&1; then
            echo -e "    [*] gobuster dir -u http://$ALIAS -w $WORDLIST" | tee -a "$ENUMFILE"
            gobuster dir -u "http://$ALIAS" -w "$WORDLIST" -q -t 20 2>&1 | tee -a "$ENUMFILE"
            if grep -q "the server returns a status code that matches the provided options" "$ENUMFILE"; then
                echo -e "${YELLOW}[!] 🟡 Attention : Gobuster a retourné une erreur, essayez d'utiliser un nom FQDN complet (ex : artificial.htb au lieu de artificial)${NC}"
            fi
        elif command -v dirb >/dev/null 2>&1; then
            echo -e "    [*] dirb http://$ALIAS $WORDLIST" | tee -a "$ENUMFILE"
            dirb "http://$ALIAS" "$WORDLIST" 2>&1 | tee -a "$ENUMFILE"
        else
            echo -e "${RED}Aucun outil d'énum web (gobuster/dirb) trouvé.${NC}" | tee -a "$ENUMFILE"
        fi
    fi

    # ENUM SMB
    if echo "$OPEN_PORTS" | grep -q "445"; then
        echo -e "  ${GREEN}SMB${NC} : smbclient -L //$IP/" | tee -a "$ENUMFILE"
        smbclient -L "//$IP/" -N 2>&1 | tee -a "$ENUMFILE"
    fi

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}[+] Résultats sauvegardés dans $STORE/$ALIAS/${NC}"
}

scan_only_if_needed() {
    ALIAS="$1"
    SCANFILE="$STORE/$ALIAS/nmap-all.txt"
    if [ -f "$SCANFILE" ]; then
        echo -e "${CYAN}==> Résultat du scan pour $ALIAS déjà existant :${NC}"
        cat "$SCANFILE"
    else
        IP=$(get_ip_from_alias "$ALIAS")
        if [ -z "$IP" ]; then
            echo -e "${RED}[!] Impossible de trouver l'IP pour $ALIAS dans /etc/hosts.${NC}"
            exit 1
        fi
        scan "$IP" "$ALIAS"
    fi
}

enum_only_if_needed() {
    ALIAS="$1"
    ENUMFILE="$STORE/$ALIAS/enum.txt"
    if [ -f "$ENUMFILE" ]; then
        echo -e "${CYAN}==> Résultat de l'énum déjà existant pour $ALIAS :${NC}"
        cat "$ENUMFILE"
        if grep -q "the server returns a status code that matches the provided options" "$ENUMFILE"; then
            echo -e "${YELLOW}[!] 🟡 Attention : Gobuster a retourné une erreur, essayez d'utiliser un nom FQDN complet (ex : artificial.htb au lieu de artificial)${NC}"
        fi
    else
        IP=$(get_ip_from_alias "$ALIAS")
        if [ -z "$IP" ]; then
            echo -e "${RED}[!] Impossible de trouver l'IP pour $ALIAS dans /etc/hosts. Ajoute l'alias avec -add ou lance un scan d'abord.${NC}"
            exit 1
        fi

        mkdir -p "$STORE/$ALIAS"
        OPEN_PORTS=""
        if [ -f "$STORE/$ALIAS/nmap-all.txt" ]; then
            OPEN_PORTS=$(grep -E '^[0-9]+/tcp' "$STORE/$ALIAS/nmap-all.txt" | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//')
        fi
        if [ -z "$OPEN_PORTS" ]; then
            echo -e "${YELLOW}[!] Aucun résultat de scan précédent, scan rapide sur 80 et 445...${NC}"
            nmap -p 80,445 --open "$IP" | tee "$STORE/$ALIAS/nmap-all.txt"
            OPEN_PORTS=$(grep -E '^[0-9]+/tcp' "$STORE/$ALIAS/nmap-all.txt" | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//')
        fi

        ENUMFILE="$STORE/$ALIAS/enum.txt"
        echo -n "" > "$ENUMFILE"

        # ENUM WEB
        if echo "$OPEN_PORTS" | grep -q "80"; then
            echo -e "  ${GREEN}HTTP${NC} :" | tee -a "$ENUMFILE"
            echo -e "    [*] curl -I http://$ALIAS" | tee -a "$ENUMFILE"
            curl -sI "http://$ALIAS" | tee -a "$ENUMFILE"
            if command -v gobuster >/dev/null 2>&1; then
                echo -e "    [*] gobuster dir -u http://$ALIAS -w $WORDLIST" | tee -a "$ENUMFILE"
                gobuster dir -u "http://$ALIAS" -w "$WORDLIST" -q -t 20 2>&1 | tee -a "$ENUMFILE"
                if grep -q "the server returns a status code that matches the provided options" "$ENUMFILE"; then
                    echo -e "${YELLOW}[!] 🟡 Attention : Gobuster a retourné une erreur, essayez d'utiliser un nom FQDN complet (ex : artificial.htb au lieu de artificial)${NC}"
                fi
            elif command -v dirb >/dev/null 2>&1; then
                echo -e "    [*] dirb http://$ALIAS $WORDLIST" | tee -a "$ENUMFILE"
                dirb "http://$ALIAS" "$WORDLIST" 2>&1 | tee -a "$ENUMFILE"
            else
                echo -e "${RED}Aucun outil d'énum web (gobuster/dirb) trouvé.${NC}" | tee -a "$ENUMFILE"
            fi
        fi

        # ENUM SMB
        if echo "$OPEN_PORTS" | grep -q "445"; then
            echo -e "  ${GREEN}SMB${NC} : smbclient -L //$IP/" | tee -a "$ENUMFILE"
            smbclient -L "//$IP/" -N 2>&1 | tee -a "$ENUMFILE"
        fi

        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}[+] Résultats sauvegardés dans $STORE/$ALIAS/${NC}"
    fi
}

case "$1" in
    -add)
        if [ $# -ne 3 ]; then usage; exit 1; fi
        add_hosts "$2" "$3"
        ;;
    -scan)
        if [ $# -ne 2 ]; then usage; exit 1; fi
        scan_only_if_needed "$2"
        ;;
    -enum)
        if [ $# -ne 2 ]; then usage; exit 1; fi
        enum_only_if_needed "$2"
        ;;
    -h|--help)
        usage
        ;;
    *)
        if [ $# -eq 2 ]; then
            scan "$1" "$2"
        else
            usage
            exit 1
        fi
        ;;
esac
