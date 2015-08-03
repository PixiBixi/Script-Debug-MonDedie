#!/bin/bash

CSI="\033["
CEND="${CSI}0m"
CGREEN="${CSI}1;32m"
CRED="${CSI}1;31m"

RAPPORT="/tmp/rapport.txt"
NOYAU=$(uname -r);

# Pour le serveur mail
PORTS_MAIL=(25 110 143 587 993 995 4190);
SOFT_MAIL=(opendkim opendkim-tools opendmarc spamassassin spamc dovecot-sieve dovecot-managesieved postfix postfix-mysql dovecot-core dovecot-imapd dovecot-lmtpd dovecot-mysql);
OPENDKIM_CONF=("/etc/opendkim.conf" "/etc/opendkim/TrustedHosts"\
			"/etc/opendkim/KeyTable" "/etc/opendkim/SigningTable"\
			"/etc/opendmarc.conf")
DOVECOT_CONF=("/etc/dovecot/dovecot.conf" "/etc/dovecot/dovecot-sql.conf.ext"\
			"/etc/dovecot/conf.d/10-auth.conf" "/etc/dovecot/conf.d/auth-sql.conf.ext"\
			"/etc/dovecot/conf.d/10-master.conf" "/etc/dovecot/conf.d/10-ssl.conf"\
			"/etc/dovecot/conf.d/90-sieve.conf" "/etc/dovecot/conf.d/10-mail.conf")
POSTFIX_CONF=("/etc/postfix/main.cf" "/etc/postfix/master.cf"\
				"/etc/postfix/mysql-virtual-mailbox-domains.cf"\
				"/etc/postfix/mysql-virtual-mailbox-maps.cf" "/etc/postfix/mysql-virtual-alias-maps.cf")
DIVERS_CONF=("/etc/spamassassin/local.cf" "/var/www/postfixadmin/config.inc.php"\
			"/var/log/mail.warn" "/var/log/mail.err"\
			"/etc/nginx/sites-enabled/rainloop.conf" "/etc/nginx/sites-enabled/postfixadmin.conf")

if [[ $UID != 0 ]]; then
	echo -e "Ce script doit être executé en tant que root";
	exit;
fi

function gen()
{
	if [[ -f $RAPPORT ]]; then
		echo -e "Fichier de rapport ${CRED}détecté${CEND}";
		rm $RAPPORT;
		echo -e "Fichier de rapport ${CGREEN}supprimé${CEND}";
	fi
	touch $RAPPORT;
	case $1 in
		ruTorrent )
				echo -e "###################################" >> $RAPPORT
				echo -e "## Rapport pour ruTorrent        ##" >> $RAPPORT
				echo -e "###################################" >> $RAPPORT
				echo -e "Utilisateur ruTorrent => $USERNAME" >> $RAPPORT
				echo -e "Kernel : $NOYAU" >> $RAPPORT
			;;

		mail )
				echo -e "###################################" >> $RAPPORT
				echo -e "## Rapport pour Mail             ##" >> $RAPPORT
				echo -e "###################################" >> $RAPPORT
				echo -e "Kernel : $NOYAU" >> $RAPPORT
			;;
	esac
}

function checkBin() # $2 utile pour faire une redirection dans $RAPPORT + Pas d'installation
{
	if ! [[ $(dpkg -s $1 | grep Status ) =~ "Status: install ok installed" ]]; then # $1 = Nom du programme
		if [[ $2 = 1 ]]; then
			echo -e "Le programme "$1" n'est pas installé" >> $RAPPORT;
		else
			echo -e "Le programme "$1" n'est pas installé";
			echo -e "Il va être installer pour la suite du script";
			sleep 2;
			apt-get -y install "$1";
		fi
	else
		if [[ $2 = 1 ]]; then
			echo -e "Le programme "$1" est installé" >> $RAPPORT;
		fi
	fi
}

function genRapport()
{
	echo -e "${CGREEN}\nFichier de rapport terminé${CEND}\n";
	LINK=$(/usr/bin/pastebinit $RAPPORT);
	echo -e "Sur le topic adéquat, envoyez ce lien $LINK";
	echo -e "Fichier stocké dans ${CGREEN}$RAPPORT${CEND}";
}

function rapport()
{
	# $1 = Fichier
	if ! [[ -z $1 ]]; then
		if [[ -f $1 ]]; then
			if [[ $(cat "$1" | wc -l) == 0 ]]; then
				FILE="--> Fichier Vide"
			else
				FILE=$(cat $1)
			fi
		else
			FILE="--> Fichier Invalide"
		fi
	else
		FILE="--> Fichier Invalide"
	fi
	# $2 = Nom à afficher
	if [[ -z $2 ]]; then
		NAME="Aucun nom donné"
	else
		NAME=$2
	fi

	# $3 = Affichage header
	if [[ $3 == 1 ]]; then
		echo -e "\n..................................." >> $RAPPORT;	
		echo -e "## $NAME                  ##" >> $RAPPORT;
		echo -e "..................................." >> $RAPPORT;
	fi
	echo -e "File : $1" >> $RAPPORT;
	echo -e "$FILE\n" >> $RAPPORT;
	echo -e "-----------------------------\n" >> $RAPPORT;
}

echo -e "#############################################";
echo -e "##    Afin d'aider les gens de mondedie   ##";
echo -e "##     Ce script a été mit en place       ##";
echo -e "## pour leur transmettre les bonnes infos ##";
echo -e "#############################################\n";

echo -e "Voici les différentes options :";
echo -e "1. ruTorrent";
echo -e "2. Serveur Mail";
read -r -p "Entrez votre choix : " OPTION;

case $OPTION in
	1 )
		read -r -p "Rentrez le nom de votre utilisateur rTorrent : " USERNAME;
		echo -e "Vous avez sélectionné ${CGREEN}ruTorrent${CEND}\n";

		gen ruTorrent "$USERNAME";
		checkBin pastebinit;

		echo -e "\n..................................." >> $RAPPORT;	
		echo -e "## Utilisateur                  ##" >> $RAPPORT;
		echo -e "..................................." >> $RAPPORT;

		if [[ $(grep "$USERNAME:" -c /etc/shadow) != "1" ]]; then
			echo -e "--> Utilisateur inexistant" >> $RAPPORT;
			VALID_USER=0;
		else
			echo -e "--> Utilisateur $USERNAME existant" >> $RAPPORT;
		fi

		echo -e "\n..................................." >> $RAPPORT;	
		echo -e "## .rtorrent.rc                  ##" >> $RAPPORT;
		echo -e "..................................." >> $RAPPORT;
		if [[ $VALID_USER = 0 ]]; then
			echo "--> Fichier introuvable (Utilisateur inexistant)" >> $RAPPORT;
		else
			if ! [[ -f "/home/$USERNAME/.rtorrent.rc" ]]; then
				echo "--> Fichier introuvable" >> $RAPPORT;
			else
				cat "/home/$USERNAME/.rtorrent.rc" >> $RAPPORT;
			fi
		fi

		rapport /var/log/nginx/rutorrent-error.log nGinx.Logs 1
		rapport /etc/nginx/nginx.conf nGinx.Conf 1
		rapport /etc/nginx/sites-enabled/rutorrent.conf ruTorrent.Conf.nGinx 1
		rapport /var/www/rutorrent/conf/config.php ruTorrent.Config.Php 1

		echo -e "\n..................................." >> $RAPPORT;	
		echo -e "## ruTorrent Conf Perso (config) ##" >> $RAPPORT
		echo -e "..................................." >> $RAPPORT
		if [[ $VALID_USER = 0 ]]; then
			echo "--> Fichier introuvable (Utilisateur Invalide)" >> $RAPPORT;
		else
			if ! [[ -f "/var/www/rutorrent/conf/users/$USERNAME/config.php" ]]; then
				echo "--> Fichier introuvable" >> $RAPPORT;
			else
				cat /var/www/rutorrent/conf/users/"$USERNAME"/config.php >> $RAPPORT;
			fi
		fi

		echo -e "\n..................................." >> $RAPPORT;	
		echo -e "## rTorrent Activity             ##" >> $RAPPORT;
		echo -e "..................................." >> $RAPPORT;	
		if [[ $VALID_USER = 0 ]]; then
			echo -e "--> Utilisateur inexistant" >> $RAPPORT;
		else
			echo -e "$(/bin/ps uU "$USERNAME" | grep -e rtorrent)" >> $RAPPORT;
		fi

		genRapport;

		;;

	2 )
		echo -e "Vous avez sélectionné ${CGREEN}Serveur Mail${CEND}";
		gen mail;
		checkBin pastebinit;
		echo -e "\n..................................." >> $RAPPORT;	
		echo -e "## Check Ports                  ##" >> $RAPPORT;
		echo -e "..................................." >> $RAPPORT;
		for PORT in "${PORTS_MAIL[@]}"
		do
			echo -e "$PORT :" >> $RAPPORT;
			echo -e "$(netstat -atlnp | awk '{print $4,$7}' | grep ":$PORT ")\n" >> $RAPPORT;
		done


		echo -e "\n..................................." >> $RAPPORT;	
		echo -e "## Check Softs                   ##" >> $RAPPORT;
		echo -e "..................................." >> $RAPPORT;
		for SOFT in "${SOFT_MAIL[@]}"
		do
			checkBin "$SOFT" 1
		done

		echo -e "\n..................................." >> $RAPPORT;	
		echo -e "## OpenDKIM Confs               ##" >> $RAPPORT;
		echo -e "..................................." >> $RAPPORT;
		for OPENDKIM_CONF_FILE  in "${OPENDKIM_CONF[@]}"
		do
			rapport "$OPENDKIM_CONF_FILE"
		done

		echo -e "\n..................................." >> $RAPPORT;	
		echo -e "## DoveCot Confs                ##" >> $RAPPORT;
		echo -e "..................................." >> $RAPPORT;
		for DOVECOT_CONF_FILE  in "${DOVECOT_CONF[@]}"
		do
			rapport "$DOVECOT_CONF_FILE"
		done

		echo -e "\n..................................." >> $RAPPORT;	
		echo -e "## PostFix Confs                ##" >> $RAPPORT;
		echo -e "..................................." >> $RAPPORT;
		for POSTFIX_CONF_FILE  in "${POSTFIX_CONF[@]}"
		do
			rapport "$POSTFIX_CONF_FILE"
		done

		echo -e "\n..................................." >> $RAPPORT;	
		echo -e "## Divers Confs                ##" >> $RAPPORT;
		echo -e "..................................." >> $RAPPORT;
		for DIVERS_CONF_FILES  in "${DIVERS_CONF[@]}"
		do
			rapport "$DIVERS_CONF_FILES"
		done

		# Purge Passwords
		sed -i  s/"user=postfix password=[a-zA-Z0-9]*"/"user=postfix password=monpass"/ $RAPPORT
		sed -i -e "s/\\\$CONF\['database_password'\] = '[^']*';$/\\\$CONF\['database_password'\] = 'monpass';/g" $RAPPORT
		sed -i -e "s/\\\$CONF\['setup_password'\] = '[^']*';$/\\\$CONF\['setup_password'\] = 'monpass';/g" $RAPPORT
		sed -i s/"password = [a-zA-Z0-9]*"/"password = monpass"/ $RAPPORT

		genRapport
		;;

	* )
		echo -e "Choix Invalide";
		exit;
		;;
esac

