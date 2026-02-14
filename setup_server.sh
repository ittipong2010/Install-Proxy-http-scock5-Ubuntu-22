#!/bin/bash

# ==========================================
# 📦 3PROXY AUTO INSTALLER (THE FINAL VERSION)
# by Gemini (For Boss)
# ==========================================

echo "🔥 กำลังติดตั้งระบบ Proxy ขาย (3proxy Enterprise)..."

# 1. เตรียมเครื่อง & ติดตั้งโปรแกรมจำเป็น
apt-get update
apt-get install -y build-essential git wget nano

# 2. ดาวน์โหลดและติดตั้ง 3proxy (จาก Source code)
cd ~
rm -rf 3proxy* # ลบของเก่าถ้ามี
wget https://github.com/z3APA3A/3proxy/archive/refs/tags/0.9.4.tar.gz
tar -xvf 0.9.4.tar.gz
cd 3proxy-0.9.4
make -f Makefile.Linux
make -f Makefile.Linux install

# 3. สร้าง User ระบบ
if ! id "proxy3" &>/dev/null; then
    useradd -s /usr/sbin/nologin -r proxy3
fi

# 4. สร้าง Config หลัก (ว่างๆ รอเติม)
mkdir -p /etc/3proxy
touch /etc/3proxy/passwd
touch /etc/3proxy/3proxy.cfg

cat <<EOF > /etc/3proxy/3proxy.cfg
# --- MAIN CONFIG ---
nserver 8.8.8.8
nserver 1.1.1.1
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
daemon
pidfile /etc/3proxy/3proxy.pid
config /etc/3proxy/3proxy.cfg
monitor /etc/3proxy/passwd

# Auth System
users \$/etc/3proxy/passwd

# Log (ปิด Log เพื่อความแรง)
log /dev/null

# --- RULES ---
auth strong
EOF

# 5. สร้าง Service (ให้เปิดเองตอนบูต)
cat <<EOF > /etc/systemd/system/3proxy.service
[Unit]
Description=3proxy Proxy Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/bin/3proxy /etc/3proxy/3proxy.cfg
PIDFile=/etc/3proxy/3proxy.pid
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 6. เปิด Firewall (6665-6666)
ufw allow 6665/tcp
ufw allow 6666/tcp
ufw allow 22/tcp

# ==========================================
# 🛠️ สร้างเครื่องมือ: ADD USER (สูตรสลับพอร์ต)
# ==========================================
cat << 'EOF' > /root/add_user.sh
#!/bin/bash
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
    echo "❌ วิธีใช้: ./add_user.sh [User] [Pass] [IP] [Speed]"
    echo "👉 ตัวอย่าง: ./add_user.sh somchai 5555 140.99.97.100 10m"
    exit 1
fi

USER=$1
PASS=$2
IP=$3
SPEED_STR=$4

# แปลง Speed
if [[ "$SPEED_STR" == *"m"* ]]; then
    NUM=${SPEED_STR%m}
    BANDWIDTH=$((NUM * 1000000))
else
    BANDWIDTH=10000000
fi

CONF="/etc/3proxy/3proxy.cfg"
PASS_FILE="/etc/3proxy/passwd"

echo "⚙️ เพิ่ม User: $USER @ $IP (Speed: $SPEED_STR)"

# 1. เพิ่ม User (ถ้ายังไม่มี)
if ! grep -q "^$USER:CL:" $PASS_FILE; then
    echo "$USER:CL:$PASS" >> $PASS_FILE
fi

# 2. เขียนกฎ (สลับพอร์ตเอาใจเว็บเช็ค)
# HTTP -> 6665 | SOCKS -> 6666
sed -i "/# --- IP: $IP ---/,/socks .*-i$IP/d" $CONF

cat <<RULE >> $CONF

# --- IP: $IP ---
flush
allow $USER
bandlimin $BANDWIDTH $USER
proxy -p6665 -i$IP -e$IP
socks -p6666 -i$IP -e$IP
RULE

systemctl kill -s USR1 3proxy
echo "✅ เสร็จ! ลูกค้า: $USER"
echo "   - HTTP  : $IP:6665"
echo "   - SOCKS : $IP:6666 (เช็คเว็บเขียวแน่นอน!)"
EOF

chmod +x /root/add_user.sh

# ==========================================
# 🛠️ สร้างเครื่องมือ: DEL USER (สูตรฉลาด)
# ==========================================
cat << 'EOF' > /root/del_user.sh
#!/bin/bash
if [ -z "$1" ]; then
    echo "❌ วิธีใช้: ./del_user.sh [IP]"
    exit 1
fi

IP=$1
CONF="/etc/3proxy/3proxy.cfg"
PASS_FILE="/etc/3proxy/passwd"

echo "💣 กำลังลบ IP: $IP ..."

# หาชื่อเจ้าของ
USER=$(grep -B 5 "\-i$IP" $CONF | grep "allow" | awk '{print $2}' | head -n 1)

# ลบกฎ IP
sed -i "/# --- IP: $IP ---/,/socks .*-i$IP/d" $CONF

# เช็คว่าหมดตัวยัง?
if [ ! -z "$USER" ]; then
    if grep -q "allow $USER" $CONF; then
        echo "🛡️ User [$USER] ยังมี IP อื่นเหลือ -> ไม่ลบ Account"
    else
        echo "🗑️ User [$USER] เกลี้ยงแล้ว -> ลบ Account ทิ้ง!"
        sed -i "/^$USER:CL:/d" $PASS_FILE
    fi
fi

systemctl kill -s USR1 3proxy
echo "✅ เรียบร้อย! IP $IP บินแล้ว"
EOF

chmod +x /root/del_user.sh

# 7. เริ่มระบบ
systemctl daemon-reload
systemctl enable 3proxy
systemctl start 3proxy

echo " "
echo "🎉 ติดตั้งเสร็จสมบูรณ์ 1!"
echo "👉 เพิ่มลูกค้า: ./add_user.sh"
echo "👉 ลบลูกค้า : ./del_user.sh"