### 1. Подготовка окружения и зависимостей

``` bash
apt update && apt install python3-venv python3-pip git -y
cd /root
python3 -m venv .venv
source .venv/bin/activate
pip install fastapi uvicorn icalendar pytz pyrinium
```

### 2. Восстановление файлов

Нужно создать файл `server.py`

```bash
nano /root/server.py # Вставить код server.py
```

![[server.py]]


### 3. Создание системной службы (systemd)

Чтобы сервер запускался сам и работал в фоне, создать файл службы.

```bash
nano /etc/systemd/system/schedule-parser.service
```

```toml
[Unit]
Description=FastAPI Schedule Parser
After=network.target

[Service]
User=root
WorkingDirectory=/root
ExecStart=/root/.venv/bin/python3 /root/.venv/bin/uvicorn server:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 4. Запуск службы

```Bash
systemctl daemon-reload
systemctl enable schedule-parser.service
systemctl start schedule-parser.service
systemctl status schedule-parser.service
```

---

Если мало оперативки на сервере, то [[swap]]
