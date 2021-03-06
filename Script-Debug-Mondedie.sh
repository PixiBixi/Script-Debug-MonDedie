#!/bin/bash
#
# Envoie sur paste.debian.net désactivé le temps de tester...
# cd /tmp
# git clone https://github.com/PixiBixi/Script-Debug-MonDedie
# cd Script-Debug-MonDedie
# chmod a+x Script-Debug-Mondedie.sh & ./Script-Debug-Mondedie.sh
#

CSI="\033["
CEND="${CSI}0m"
CGREEN="${CSI}1;32m"
CRED="${CSI}1;31m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"

RAPPORT="/tmp/rapport.txt"
NOYAU=$(uname -r)
DATE=$(date +"%d-%m-%Y à %H:%M")
DOMAIN=$(hostname -d 2> /dev/null)
WANIP=$(dig o-o.myaddr.l.google.com @ns1.google.com txt +short | sed 's/"//g')
NGINX_VERSION=$(2>&1 nginx -v | grep -Eo "[0-9.+]{1,}")
RTORRENT_VERSION=$(rtorrent -h | grep -E -o "[0-9]\.[0-9].[0-9]{1,}")

# CONFIGURATION POUR LE SERVEUR DE MAIL
# #######################################################################################################

PORTS_MAIL=(25 110 143 587 993 995 4190)

SOFT_MAIL=(                                                                                   \
	postfix postfix-mysql                                                                     \
	dovecot-core dovecot-imapd dovecot-lmtpd dovecot-mysql dovecot-sieve dovecot-managesieved \
	opendkim opendkim-tools opendmarc                                                         \
	spamassassin spamc
)

OPENDKIM_CONF=(                  \
	"/etc/opendkim.conf"         \
	"/etc/opendkim/TrustedHosts" \
	"/etc/opendkim/KeyTable"     \
	"/etc/opendkim/SigningTable" \
	"/etc/opendmarc.conf"
)

DOVECOT_CONF=(                              \
	"/etc/dovecot/dovecot.conf"             \
	"/etc/dovecot/dovecot-sql.conf.ext"     \
	"/etc/dovecot/conf.d/auth-sql.conf.ext" \
	"/etc/dovecot/conf.d/10-auth.conf"      \
	"/etc/dovecot/conf.d/10-mail.conf"      \
	"/etc/dovecot/conf.d/10-master.conf"    \
	"/etc/dovecot/conf.d/10-ssl.conf"       \
	"/etc/dovecot/conf.d/20-lmtp.conf"      \
	"/etc/dovecot/conf.d/90-sieve.conf"
)

POSTFIX_CONF=(                                      \
	"/etc/postfix/main.cf"                          \
	"/etc/postfix/master.cf"                        \
	"/etc/postfix/mysql-virtual-mailbox-domains.cf" \
	"/etc/postfix/mysql-virtual-mailbox-maps.cf"    \
	"/etc/postfix/mysql-virtual-alias-maps.cf"
)

CLAMAV_CONF=("/etc/clamav/freshclam.conf" "/etc/clamav/clamd.conf")
SPAM_CONF=("/etc/spamassassin/local.cf" "/etc/default/spamassassin")
LOGS_CONF=("/var/log/mail.warn" "/var/log/mail.err")
VHOST_CONF=("/etc/nginx/sites-enabled/rainloop.conf" "/etc/nginx/sites-enabled/postfixadmin.conf")

# #######################################################################################################

if [[ $UID != 0 ]]; then
	echo -e "${CRED}Ce script doit être executé en tant que root${CEND}"
	exit
fi

function gen() {
	if [[ -f $RAPPORT ]]; then
		echo -e "${CRED}\nFichier de rapport détecté${CEND}"
		rm $RAPPORT
		echo -e "${CGREEN}Fichier de rapport supprimé${CEND}"
	fi
	touch $RAPPORT
	case $1 in
		ruTorrent )
				cat <<-EOF >> $RAPPORT

				### Rapport pour ruTorrent généré le $DATE ###

				Utilisateur ruTorrent => $USERNAME
				Kernel : $NOYAU
				nGinx : $NGINX_VERSION
				rTorrent Version : $RTORRENT_VERSION
				EOF
			;;

		mail )
				cat <<-EOF >> $RAPPORT

				### Rapport pour Mail généré le $DATE

				Kernel : $NOYAU
				nGinx : $NGINX_VERSION
				EOF
			;;
	esac
}

function checkBin() { # $2 => No installation
	if ! [[ $(dpkg -s "$1" | grep Status ) =~ "Status: install ok installed" ]]  &> /dev/null ; then # $1 = Nom du programme
		if [[ $2 = 1 ]]; then
			echo "Le programme $1 n'est pas installé" >> $RAPPORT
		else
			echo -e "${CGREEN}\nLe programme${CEND} ${CYELLOW}$1${CEND}${CGREEN} n'est pas installé\nIl va être installé pour la suite du script${CEND}"
			sleep 2
			apt-get -y install "$1" &>/dev/null
		fi
	else
		if [[ $2 = 1 ]]; then
			echo "Le programme $1 est installé" >> $RAPPORT
		fi
	fi
}

function genRapport() {
	echo -e "${CBLUE}\nFichier de rapport terminé${CEND}\n"
	LINK=$(/usr/bin/pastebinit $RAPPORT)
	echo -e "Allez sur le topic adéquat et envoyez ce lien:\n${CYELLOW}$LINK${CEND}"
	echo -e "Rapport stocké dans le fichier : ${CYELLOW}$RAPPORT${CEND}"
}

function rapport() {
	# $1 = Fichier
	if ! [[ -z $1 ]]; then
		if [[ -f $1 ]]; then
			if [[ $(wc -l < "$1") == 0 ]]; then
				FILE="--> Fichier Vide"
			else
				FILE=$(cat "$1")
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
		cat <<-EOF >> $RAPPORT

		...................................
		## $NAME                  ##
		...................................
		EOF
	fi
	cat <<-EOF >> $RAPPORT

	##### ----------- File : $1 -----------------------------------------------------------------------------------------------------------------------------

	$FILE
	EOF
}

function remove() {
	echo -e -n "${CGREEN}\nVoulez vous désinstaller Pastebinit? (y/n):${CEND} "
	read -r PASTEBINIT
	if [[ ${PASTEBINIT^^} == "Y" ]]; then
		apt-get remove -y pastebinit &>/dev/null
		echo -e "${CBLUE}Pastebinit a bien été désinstallé${CEND}"
	else
		echo -e "${CBLUE}Pastebinit n'a pas été désinstallé${CEND}"
	fi
}

echo -e "${CBLUE}
#############################################
##    Afin d'aider les gens de mondedie    ##
##     Ce script a été mis en place        ##
## pour leur transmettre les bonnes infos  ##
#############################################${CEND}"

echo -e "${CGREEN}\nVoici les différentes options:${CEND}"
echo -e "${CYELLOW} 1${CEND} ruTorrent"
echo -e "${CYELLOW} 2${CEND} Serveur Mail"
echo -e -n "${CGREEN}Entrez votre choix :${CEND} "
read -r OPTION

case $OPTION in
	1 )
		echo -e -n "${CGREEN}Rentrez le nom de votre utilisateur rTorrent:${CEND} "
		read -r USERNAME
		echo -e "\nVous avez sélectionné ${CYELLOW}ruTorrent${CEND}\n"

		gen ruTorrent "$USERNAME"
		checkBin pastebinit

		cat <<-EOF >> $RAPPORT
		...................................
		## Utilisateur                  ##
		...................................
		EOF

		if [[ $(grep "$USERNAME:" -c /etc/shadow) != "1" ]]; then
			echo -e "--> Utilisateur inexistant" >> $RAPPORT
			VALID_USER=0
		else
			echo -e "--> Utilisateur $USERNAME existant" >> $RAPPORT
		fi

		cat <<-EOF >> $RAPPORT

		...................................
		## .rtorrent.rc                  ##
		...................................
		EOF
		if [[ $VALID_USER = 0 ]]; then
			echo "--> Fichier introuvable (Utilisateur inexistant)" >> $RAPPORT
		else
			if ! [[ -f "/home/$USERNAME/.rtorrent.rc" ]]; then
				echo "--> Fichier introuvable" >> $RAPPORT
			else
				cat "/home/$USERNAME/.rtorrent.rc" >> $RAPPORT
			fi
		fi

		rapport /var/log/nginx/rutorrent-error.log nGinx.Logs 1
		rapport /etc/nginx/nginx.conf nGinx.Conf 1
		rapport /etc/nginx/sites-enabled/rutorrent.conf ruTorrent.Conf.nGinx 1
		rapport /var/www/rutorrent/conf/config.php ruTorrent.Config.Php 1

		cat <<-EOF >> $RAPPORT

		...................................
		## ruTorrent Conf Perso (config) ##
		...................................
		EOF
		if [[ $VALID_USER = 0 ]]; then
			echo "--> Fichier introuvable (Utilisateur Invalide)" >> $RAPPORT
		else
			if ! [[ -f "/var/www/rutorrent/conf/users/$USERNAME/config.php" ]]; then
				echo "--> Fichier introuvable" >> $RAPPORT
			else
				cat /var/www/rutorrent/conf/users/"$USERNAME"/config.php >> $RAPPORT
			fi
		fi

		cat <<-EOF >> $RAPPORT

		...................................
		## rTorrent Activity             ##
		...................................
		EOF
		if [[ $VALID_USER = 0 ]]; then
			echo -e "--> Utilisateur inexistant" >> $RAPPORT
		else
			echo -e "$(/bin/ps uU "$USERNAME" | grep -e rtorrent)" >> $RAPPORT
		fi

		genRapport
		remove
		;;

	2 )
		echo -e "Vous avez sélectionné ${CYELLOW}Serveur Mail${CEND}"
		gen mail
		checkBin pastebinit
		cat <<-EOF >> $RAPPORT

		...................................
		## Check Ports                  ##
		...................................
		EOF
		for PORT in "${PORTS_MAIL[@]}"
		do
			cat <<-EOF >> $RAPPORT
			$PORT :
			$(netstat -atlnp | awk '{print $4,$7}' | grep ":$PORT ")
			EOF
		done

		cat <<-EOF >> $RAPPORT

		...................................
		## Check Softs                   ##
		...................................
		EOF
		for SOFT in "${SOFT_MAIL[@]}"
		do
			checkBin "$SOFT" 1
		done > /dev/null 2>&1

		cat <<-EOF >> $RAPPORT

		...................................
		## OpenDKIM Confs               ##
		...................................
		EOF
		for OPENDKIM_CONF_FILE in "${OPENDKIM_CONF[@]}"
		do
			rapport "$OPENDKIM_CONF_FILE"
		done > /dev/null 2>&1

		cat <<-EOF >> $RAPPORT

		...................................
		## DoveCot Confs                ##
		...................................
		EOF
		for DOVECOT_CONF_FILE in "${DOVECOT_CONF[@]}"
		do
			rapport "$DOVECOT_CONF_FILE"
		done > /dev/null 2>&1

		cat <<-EOF >> $RAPPORT

		...................................
		## PostFix Confs                ##
		...................................
		EOF
		for POSTFIX_CONF_FILE in "${POSTFIX_CONF[@]}"
		do
			rapport "$POSTFIX_CONF_FILE"
		done > /dev/null 2>&1

		cat <<-EOF >> $RAPPORT

		...................................
		## ClamAV Confs                ##
		...................................
		EOF
		for CLAMAV_CONF_FILES in "${CLAMAV_CONF[@]}"
		do
			rapport "$CLAMAV_CONF_FILES"
		done > /dev/null 2>&1

		cat <<-EOF >> $RAPPORT

		...................................
		## Spamassassin Confs            ##
		...................................
		EOF
		for SPAM_CONF_FILES in "${SPAM_CONF[@]}"
		do
			rapport "$SPAM_CONF_FILES"
		done > /dev/null 2>&1

		cat <<-EOF >> $RAPPORT

		...................................
		## Logs                          ##
		...................................
		EOF
		for LOGS_FILES in "${LOGS_CONF[@]}"
		do
			rapport "$LOGS_FILES"
		done > /dev/null 2>&1

		cat <<-EOF >> $RAPPORT

		...................................
		## Vhost Confs                   ##
		...................................
		EOF
		for VHOST_CONF_FILES in "${VHOST_CONF[@]}"
		do
			rapport "$VHOST_CONF_FILES"
		done > /dev/null 2>&1

		cat <<-EOF >> $RAPPORT

		...................................
		## DNS                           ##
		...................................

		- MX       : $(dig +nocmd +noall +answer MX    ${DOMAIN})
		- SPF      : $(dig +nocmd +noall +answer TXT   ${DOMAIN})
		- DKIM     : $(dig +nocmd +noall +answer TXT   mail._domainkey.${DOMAIN})
		- DMARC    : $(dig +nocmd +noall +answer TXT   _dmarc.${DOMAIN})
		- PFA      : $(dig +nocmd +noall +answer CNAME postfixadmin.${DOMAIN})
		- RAINLOOP : $(dig +nocmd +noall +answer CNAME rainloop.${DOMAIN})
		- REVERSE  : $(dig +short -x ${WANIP})

		EOF

		echo ""
		read -rp "> Veuillez saisir une adresse mail paramétrée sur ce serveur : " EMAIL

		cat <<-EOF >> $RAPPORT

		...................................
		## DOVEADM                       ##
		...................................

		- User Info --------------------
		$(doveadm user ${EMAIL})
		--------------------------------

		- Dovecot errors ---------------
		$(doveadm log errors)
		--------------------------------

		EOF

		# Purge Passwords
		sed -i -e "s/user=postfix password=[a-zA-Z0-9]*/user=postfix password=monpass/g;" \
		       -e "s/\\\$CONF\['database_password'\] = '[^']*';$/\\\$CONF\['database_password'\] = 'monpass';/g" \
		       -e "s/\\\$CONF\['setup_password'\] = '[^']*';$/\\\$CONF\['setup_password'\] = 'monpass';/g" \
		       -e "s/password = [a-zA-Z0-9]*/password = monpass/g;" $RAPPORT

		genRapport
		remove
		;;

	* )
		echo -e "${CRED}Choix Invalide${CEND}"
		exit
		;;
esac

