#!/bin/sh
#
# Script that installs the various dependencies of invidious
#
# Dependencies:
# - crystal       => Language in which Invidious is developed
# - postgres      => Database server
# - git           => required to clone Invidious
# - librsvg2-bin  => For login captcha (provides 'rsvg-convert')
#
# - libssl-dev    => Used by Crystal's SSL module (standard library)
# - libxml2-dev   => Used by Crystal's XML module (standard library)
# - libyaml-dev   => Used by Crystal's YAML module (standard library)
# - libgmp-dev    => Used by Crystal's BigNumbers module (standard library)
# - libevent-dev  => Used by crystal's internal scheduler (?)
# - libpcre3-dev  => Used by Crystal's regex engine (?)
#
# - libsqlite3-dev   => Used to open .db files from NewPipe exports
# - zlib1g-dev       => TBD
# - libreadline-dev  => TBD
#
#
# Tested on:
# - OpenSUSE Leap 15.3

#
# Load system details
#

if [ -e /etc/os-release ]; then
	. /etc/os-release
elif [ -e /usr/lib/os-release ]; then
	. /usr/lib/os-release
else
	echo "Unsupported Linux system"
	exit 2
fi

#
# Some variables
#

repo_base_url="https://download.opensuse.org/repositories/devel:/languages:/crystal/"
repo_end_url="devel:languages:crystal.repo"

apt_gpg_key="/usr/share/keyrings/crystal.gpg"
apt_list_file="/etc/apt/sources.list.d/crystal.list"

yum_repo_file="/etc/yum.repos.d/crystal.repo"

#
# Major install functions
#

make_repo_url() {
	echo "${repo_base_url}/${1}/${repo_end_url}"
}


install_apt() {
	repo="$1"

	echo "Adding Crystal repository"

	curl -fsSL "${repo_base_url}/${repo}/Release.key" \
		| gpg --dearmor \
		| sudo tee "${apt_gpg_key}" > /dev/null

	echo "deb [signed-by=${apt_gpg_key}] ${repo_base_url}/${repo}/ /" \
		| sudo tee "$apt_list_file"

	sudo apt-get update

	sudo apt-get install --yes --no-install-recommends \
		libssl-dev libxml2-dev libyaml-dev libgmp-dev libevent-dev \
		libpcre3-dev libreadline-dev libsqlite3-dev zlib1g-dev \
		crystal postgresql-13 git librsvg2-bin make
}

install_yum() {
	repo=$(make_repo_url "$1")

	echo "Adding Crystal repository"

	cat << END | sudo tee "${yum_repo_file}" > /dev/null
[crystal]
name=Crystal
type=rpm-md
baseurl=${repo}/
gpgcheck=1
gpgkey=${repo}/repodata/repomd.xml.key
enabled=1
END

	sudo yum -y install \
		openssl-devel libxml2-devel libyaml-devel gmp-devel \
		readline-devel sqlite-devel \
		crystal postgresql postgresql-server git librsvg2-tools make
}

install_pacman() {
	# TODO: find an alternative to --no-confirm?
	sudo pacman -S --no-confirm \
		base-devel librsvg postgresql crystal
}

install_zypper()
{
	repo=$(make_repo_url "$1")

	echo "Adding Crystal repository"
	sudo zypper --non-interactive addrepo -f "$repo"

	sudo zypper --non-interactive --gpg-auto-import-keys install --no-recommends \
		libopenssl-devel libxml2-devel libyaml-devel gmp-devel libevent-devel \
		pcre-devel readline-devel sqlite3-devel zlib-devel \
		crystal postgresql postgresql-server git rsvg-convert make
}


#
# System-specific logic
#

case "$ID" in
	archlinux) install_pacman;;

	centos) install_dnf "CentOS_${VERSION_ID}";;

	debian)
		case "$VERSION_CODENAME" in
			sid)      install_apt "Debian_Unstable";;
			bookworm) install_apt "Debian_Testing";;
			*)        install_apt "Debian_${VERSION_ID}";;
		esac
	;;

	fedora)
		if [ "$VERSION" == *"Prerelease"* ]; then
			install_dnf "Fedora_Rawhide"
		else
			install_dnf "Fedora_${VERSION}"
		fi
	;;

	opensuse-leap) install_zypper "openSUSE_Leap_${VERSION}";;

	opensuse-tumbleweed) install_zypper "openSUSE_Tumbleweed";;

	rhel) install_dnf "RHEL_${VERSION_ID}";;

	ubuntu)
		# Small workaround for recently released 22.04
		case "$VERSION_ID" in
			22.04) install_apt "xUbuntu_21.04";;
			*)     install_apt "xUbuntu_${VERSION_ID}";;
		esac
	;;

	*)
		# Try to match on ID_LIKE instead
		# Not guaranteed to 100% work
		case "$ID_LIKE" in
			archlinux) install_pacman;;
			centos) install_dnf "CentOS_${VERSION_ID}";;
			debian) install_apt "Debian_${VERSION_ID}";;
			*)
				echo "Error: distribution ${CODENAME} is not supported"
				echo "Please install dependencies manually"
				exit 2
			;;
		esac
	;;
esac
