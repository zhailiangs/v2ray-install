#!/bin/bash
systemctl stop v2ray
echo "v2ray 已停止运行"
rm -rf /usr/bin/v2ray
rm -rf /etc/v2ray/config.json
systemctl disable v2ray
rm -rf /etc/systemd/system/v2ray.service
echo "v2ray 已卸载"
