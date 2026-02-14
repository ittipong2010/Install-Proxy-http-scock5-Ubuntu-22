เข้า SSH มาแล้วรันคำสั่งนี้
nano setup_server.sh
chmod +x setup_server.sh
./setup_server.sh

วิธีใช้งาน (หลังลงเสร็จ)
เพิ่มลูกค้าใหม่
./add_user.sh somchai 5555 xxx.xx.xx.xxx 10m

ลบลูกค้า (ยึด IP คืน)
./del_user.sh xxx.xx.xx.xxx
