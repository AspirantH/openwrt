#!/bin/bash
#=================================================
shopt -s extglob

sed -i '$a src-git AspirantH https://github.com/AspirantH/openwrt-packages.git;main' feeds.conf.default
sed -i "/telephony/d" feeds.conf.default

sed -i "s?targets/%S/packages?targets/%S/\$(LINUX_VERSION)?" include/feeds.mk

sed -i "s?git.openwrt.org/\(project\|feed\)?github.com/openwrt?g" feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install -a -p AspirantH -f
./scripts/feeds install -a

mkdir -p /tmp/decrypt
7z x -p"${DB_PASS}" feeds/AspirantH/openlist/files/data.db -o/tmp/decrypt/
cp /tmp/decrypt/data.db feeds/AspirantH/openlist/files/data.db
rm -rf /tmp/decrypt

sed -i "s/192.168.1/10.0.0/" package/base-files/files/bin/config_generate

sed -i "s#false; \\\#true; \\\#" include/download.mk

echo "$(date +"%s")" >version.date
sed -i "s/DEFAULT_PACKAGES:=/DEFAULT_PACKAGES:=luci-app-firewall luci-app-package-manager \
luci-base luci-compat luci-lib-ipkg kmod-nvme libcurl luci-lib-fs coreutils coreutils-stty shadow-utils shadow-useradd mount-utils smartd mdadm libuci-lua \
wget-ssl curl autocore htop nano kmod-lib-zstd kmod-tcp-bbr kmod-tun ca-bundle ip-full ruby ruby-yaml unzip bash block-mount resolveip ds-lite swconfig luci-app-footstrap-files /" include/target.mk

sed -i "s/^.*vermagic$/\techo '1' > \$(LINUX_DIR)\/.vermagic/" include/kernel-defaults.mk

status=$(curl -H "Authorization: token $REPO_TOKEN" -s "https://api.github.com/repos/AspirantH/openwrt-packages/actions/runs" | jq -r '.workflow_runs[0].status')
echo "$status"
while [[ "$status" == "in_progress" || "$status" == "queued" ]];do
	echo "wait 5s"
	sleep 5
	status=$(curl -H "Authorization: token $REPO_TOKEN" -s "https://api.github.com/repos/AspirantH/openwrt-packages/actions/runs" | jq -r '.workflow_runs[0].status')
done

sed -i 's/max_requests 3/max_requests 20/g' package/network/services/uhttpd/files/uhttpd.config
sed -i "s/tty\(0\|1\)::askfirst/tty\1::respawn/g" target/linux/*/base-files/etc/inittab

date=`date +%m.%d.%Y`
sed -i -e "/\(# \)\?REVISION:=/c\REVISION:=$date" -e '/VERSION_CODE:=/c\VERSION_CODE:=$(REVISION)' include/version.mk

sed -i 's/option timeout 30/option timeout 60/g' package/system/rpcd/files/rpcd.config

sed -i \
	-e "s/+\(luci\|luci-ssl\|uhttpd\)\( \|$\)/\2/" \
	-e "s/+nginx\( \|$\)/+nginx-ssl\1/" \
	-e 's/+python\( \|$\)/+python3/' \
	-e 's?../../lang?$(TOPDIR)/feeds/packages/lang?' \
	package/feeds/AspirantH/*/Makefile

sed -i -e "s/set \${s}.country='\${country || ''}'/set \${s}.country='\${country || \"CN\"}'/g" package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc

LUCI_MOD_SYSTEM="feeds/luci/modules/luci-mod-system"
if [ -d "$LUCI_MOD_SYSTEM" ]; then
    rm -rf "$LUCI_MOD_SYSTEM/htdocs/luci-static/resources/view/system/leds.js"
    rm -rf "$LUCI_MOD_SYSTEM/htdocs/luci-static/resources/view/system/led-trigger/"
    sed -i '/"admin\/system\/leds": {/,/^	},/d' \
        "$LUCI_MOD_SYSTEM/root/usr/share/luci/menu.d/luci-mod-system.json"
    sed -i '/"fs": { "\/sys\/class\/leds": "directory" }/,/^	},/d' \
        "$LUCI_MOD_SYSTEM/root/usr/share/luci/menu.d/luci-mod-system.json"
    sed -i '/"init": "led",/d' \
        "$LUCI_MOD_SYSTEM/root/usr/share/ucitrack/luci-mod-system-system.json"
    sed -i 's/"getLEDs", //g' \
        "$LUCI_MOD_SYSTEM/root/usr/share/rpcd/acl.d/luci-mod-system.json"
fi

rm -rf package/feeds/packages/jool package/feeds/routing/batman-adv
