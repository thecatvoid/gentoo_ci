#!/bin/bash
set -e
source /etc/environment

# Setup portage configs and update system
rm -rf /etc/portage/ /var/db/repos/* 
cp -af ./portage /etc/
sed -i "s/^J=.*/J=\"$(nproc --all)\"/" /etc/portage/make.conf
ln -sf /var/db/repos/gentoo/profiles/default/linux/amd64/17.1/desktop/systemd /etc/portage/make.profile
emerge --sync

# Compile the packages
pkgs=()
while read -r pkg
do
ver="$(grep -HEo 'KEYWORDS=.*[^~]amd64[^-]' /var/db/repos/*/${pkg}/*.ebuild | grep -o '/var/db/.*/.*ebuild' | sort -n | tail -1 | sed 's/.ebuild//g' | xargs -I{} basename {} | grep -o -- '-[0-9].*')" || true
if [[ $ver == *-[0-9]* ]]; then tmp="=${pkg}${ver}"; else tmp="${pkg}${ver}"; fi
pkgs+=("$tmp")
done < "./package_list"

emerge -uN "${pkgs[@]}" || exit 1

# Create binary packages
rm -rf /var/cache/binpkgs/*
curl -sS "https://raw.githubusercontent.com/thecatvoid/gentoo-bin/main/Packages" \
        -o /var/cache/binpkgs/Packages

qlist -I | grep -Ev -- 'acct-user/.*|acct-group/.*|virtual/.*|sys-kernel/.*-sources|.*/.*-bin' |
        xargs quickpkg --include-config=y

fixpackages
emaint --fix binhost

# Upload binaries to repository
bin="${HOME}/binpkgs"
sudo cp -af "${HOME}/gentoo/var/cache/binpkgs/" "$bin"
sudo chown -R "${USER}:${USER}" "$bin"
cd "$bin" || exit
git config --global user.email "voidcat@tutanota.com"
git config --global user.name "thecatvoid"
git init -b main
git add -A
git commit -m 'commit'
git push --set-upstream "https://oauth2:${GIT_TOKEN}@gitlab.com/thecatvoid/gentoo-bin" main -f 2>&1 |
        sed "s/$GIT_TOKEN/token/"

