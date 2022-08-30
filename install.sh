#!/bin/bash
ZIPFILE="/root/v2ray-linux-64.zip"
SYSTEMCTL_CMD=$(command -v systemctl 2>/dev/null)
SERVICE_CMD=$(command -v service 2>/dev/null)

zipRoot() {
    unzip -lqq "$1" | awk -e '
        NR == 1 {
            prefix = $4;
        }
        NR != 1 {
            prefix_len = length(prefix);
            cur_len = length($4);

            for (len = prefix_len < cur_len ? prefix_len : cur_len; len >= 1; len -= 1) {
                sub_prefix = substr(prefix, 1, len);
                sub_cur = substr($4, 1, len);

                if (sub_prefix == sub_cur) {
                    prefix = sub_prefix;
                    break;
                }
            }

            if (len == 0) {
                prefix = "";
                nextfile;
            }
        }
        END {
            print prefix;
        }
    '
}

stopV2ray(){
    echo ${BLUE} "Shutting down V2Ray service."
    if [[ -n "${SYSTEMCTL_CMD}" ]] || [[ -f "/lib/systemd/system/v2ray.service" ]] || [[ -f "/etc/systemd/system/v2ray.service" ]]; then
        ${SYSTEMCTL_CMD} stop v2ray
    elif [[ -n "${SERVICE_CMD}" ]] || [[ -f "/etc/init.d/v2ray" ]]; then
        ${SERVICE_CMD} v2ray stop
    fi
    if [[ $? -ne 0 ]]; then
        echo ${YELLOW} "Failed to shutdown V2Ray service."
        return 2
    fi
    return 0
}
installV2Ray(){
    # Install V2Ray binary to /usr/bin/v2ray
    mkdir -p '/etc/v2ray' '/var/log/v2ray' && \
    unzip -oj "$1" "$2v2ray" "$2v2ctl" "$2geoip.dat" "$2geosite.dat" -d '/usr/bin/v2ray' && \
    chmod +x '/usr/bin/v2ray/v2ray' '/usr/bin/v2ray/v2ctl' || {
        echo "Failed to copy V2Ray binary and resources."
        return 1
    }

    # Install V2Ray server config to /etc/v2ray
    if [ ! -f '/etc/v2ray/config.json' ]; then
        local PORT="$(($RANDOM + 10000))"
        local UUID="$(cat '/proc/sys/kernel/random/uuid')"

        unzip -pq "$1" "$2vpoint_vmess_freedom.json" | \
        sed -e "s/10086/${PORT}/g; s/23ad6b10-8d1a-40f7-8ad0-e3e35cd38297/${UUID}/g;" - > \
        '/etc/v2ray/config.json' || {
            echo ${YELLOW} "Failed to create V2Ray configuration file. Please create it manually."
            return 1
        }
        echo "------记住下面的内容----------"
        echo "PORT:${PORT}"
        echo "UUID:${UUID}"
        echo "------记住上面的内容----------"
    fi
}


installInitScript(){
    if [[ -n "${SYSTEMCTL_CMD}" ]]; then
        if [[ ! -f "/etc/systemd/system/v2ray.service" && ! -f "/lib/systemd/system/v2ray.service" ]]; then
            unzip -oj "$1" "$2systemd/system/v2ray.service" -d '/etc/systemd/system' && \
            systemctl enable v2ray.service
        fi
    elif [[ -n "${SERVICE_CMD}" ]] && [[ ! -f "/etc/init.d/v2ray" ]]; then
        installSoftware 'daemon' && \
        unzip -oj "$1" "$2systemv/v2ray" -d '/etc/init.d' && \
        chmod +x '/etc/init.d/v2ray' && \
        update-rc.d v2ray defaults
    fi
}

startV2ray(){
    if [ -n "${SYSTEMCTL_CMD}" ] && [[ -f "/lib/systemd/system/v2ray.service" || -f "/etc/systemd/system/v2ray.service" ]]; then
        ${SYSTEMCTL_CMD} start v2ray
    elif [ -n "${SERVICE_CMD}" ] && [ -f "/etc/init.d/v2ray" ]; then
        ${SERVICE_CMD} v2ray start
    fi
    if [[ $? -ne 0 ]]; then
        echo "Failed to start V2Ray service."
        return 2
    fi
    return 0
}

if pgrep "v2ray" > /dev/null ; then
    V2RAY_RUNNING=1
    stopV2ray
fi
ZIPROOT="$(zipRoot "${ZIPFILE}")"
installV2Ray "${ZIPFILE}" "${ZIPROOT}"
installInitScript "${ZIPFILE}" "${ZIPROOT}"
echo "start V2Ray service."
startV2ray
echo "V2Ray is installed."
