#!/bin/bash
#=================================================
shopt -s extglob

sed -i '$a src-git AspirantH https://github.com/AspirantH/openwrt-packages.git;main' feeds.conf.default
sed -i "/telephony/d" feeds.conf.default

sed -i "s?targets/%S/packages?targets/%S/\$(LINUX_VERSION)?" include/feeds.mk

sed -i '/	refresh_config();/d' scripts/feeds

sed -i "s?git.openwrt.org/\(project\|feed\)?github.com/openwrt?g" feeds.conf.default

./scripts/feeds update -a
./scripts/feeds install -a -p AspirantH -f
./scripts/feeds install -a

if [ -f "feeds/AspirantH/openlist/files/data.db" ]; then
    if 7z t -p"${DB_PASS}" feeds/AspirantH/openlist/files/data.db >/dev/null 2>&1; then
        echo "🔓 Decrypting data.db (7z archive) from openlist package..."
        mkdir -p /tmp/decrypt_openlist
        7z x -p"${DB_PASS}" feeds/AspirantH/openlist/files/data.db -o/tmp/decrypt_openlist/
        if [ $? -eq 0 ]; then
            if [ -f /tmp/decrypt_openlist/data.db ]; then
                cp /tmp/decrypt_openlist/data.db feeds/AspirantH/openlist/files/data.db
                echo "✅ data.db decrypted and replaced."
            else
                echo "❌ Decrypted archive does not contain data.db!"
                exit 1
            fi
        else
            echo "❌ Decryption failed for data.db!"
            exit 1
        fi
        rm -rf /tmp/decrypt_openlist
    else
        echo "ℹ️ data.db is not a 7z archive (or password incorrect), skipping decryption."
    fi
fi

sed -i -e '$a /etc/bench.log' \
        -e '/\/etc\/profile/d' \
        -e '/\/etc\/shinit/d' \
        package/base-files/files/lib/upgrade/keep.d/base-files-essential
sed -i -e '/^\/etc\/profile/d' \
        -e '/^\/etc\/shinit/d' \
        package/base-files/Makefile
sed -i "s/192.168.1/10.0.0/" package/base-files/files/bin/config_generate

sed -i "s#false; \\\#true; \\\#" include/download.mk

echo "$(date +"%s")" >version.date
# sed -i '/$(curdir)\/compile:/c\$(curdir)/compile: package/opkg/host/compile' package/Makefile
sed -i "s/DEFAULT_PACKAGES:=/DEFAULT_PACKAGES:=luci-app-firewall luci-app-package-manager \
luci-base luci-compat kmod-nvme libcurl luci-lib-fs \
wget-ssl curl autocore htop nano kmod-lib-zstd kmod-tcp-bbr kmod-tun ca-bundle ip-full ruby ruby-yaml unzip bash tar block-mount resolveip ds-lite swconfig luci-app-filemanager /" include/target.mk

sed -i "s/^.*vermagic$/\techo '1' > \$(LINUX_DIR)\/.vermagic/" include/kernel-defaults.mk

status=$(curl -H "Authorization: token $REPO_TOKEN" -s "https://api.github.com/repos/AspirantH/openwrt-packages/actions/runs" | jq -r '.workflow_runs[0].status')
echo "$status"
while [[ "$status" == "in_progress" || "$status" == "queued" ]];do
	echo "wait 5s"
	sleep 5
	status=$(curl -H "Authorization: token $REPO_TOKEN" -s "https://api.github.com/repos/AspirantH/openwrt-packages/actions/runs" | jq -r '.workflow_runs[0].status')
done

wget -N https://raw.githubusercontent.com/openwrt/packages/master/lang/golang/golang/Makefile -P feeds/packages/lang/golang/golang/

#sed -i "/call Build\/check-size,\$\$(KERNEL_SIZE)/d" include/image.mk

sed -i "/+= targz/d" include/image.mk


# find target/linux/x86 -name "config*" -exec bash -c 'cat kernel.conf >> "{}"' \;
sed -i 's/max_requests 3/max_requests 20/g' package/network/services/uhttpd/files/uhttpd.config
#rm -rf ./feeds/packages/lang/{golang,node}
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


sed -i -e "s/set \${s}.country='\${country || ''}'/set \${s}.country='\${country || \"CN\"}'/g" -e "s/set \${s}.disabled=.*/set \${s}.disabled='0'/" package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc

rm -rf package/feeds/packages/jool
