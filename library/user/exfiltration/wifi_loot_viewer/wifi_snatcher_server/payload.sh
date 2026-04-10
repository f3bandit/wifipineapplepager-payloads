#!/bin/bash

# Title: wifi_snatcher_server
# Author:f3bandit
# Description: First-run dependency bootstrap + local file server
# Version: 2.1

HTTP_PORT=42
BASE_DIR="/mmc/root/payloads/user/exfiltration/wifi_loot_viewer"
DEPS_DIR="$BASE_DIR/deps"
SERVE_DIR="/mmc/root/scripts"
UPLOAD_DIR="/mmc/root/loot/wifi"

LOG_FILE="/tmp/webserver.log"
PID_FILE="/tmp/webserver.pid"
PY_FILE="/tmp/upload_server.py"
STATE_FILE="/tmp/wifi_snatcher_bootstrap_done"

PYTHON_BIN="/mmc/usr/bin/python3"
LIB_DIR_PRIMARY="/mmc/usr/lib"
LIB_DIR_FALLBACK="/mmc/lib"

LED SETUP
mkdir -p "$SERVE_DIR" "$UPLOAD_DIR"
: > "$LOG_FILE"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

python_works() {
    export LD_LIBRARY_PATH="$LIB_DIR_PRIMARY:$LIB_DIR_FALLBACK:$LD_LIBRARY_PATH"
    "$PYTHON_BIN" --version >/dev/null 2>&1
}

install_deps_from_bundle() {
    log "Checking bundled dependencies in $DEPS_DIR"

    if [ ! -d "$DEPS_DIR" ]; then
        log "Deps directory not found: $DEPS_DIR"
        return 1
    fi

    mkdir -p "$LIB_DIR_PRIMARY" "$LIB_DIR_FALLBACK" "$(dirname "$PYTHON_BIN")"

    if [ -f "$DEPS_DIR/python3" ] && [ ! -f "$PYTHON_BIN" ]; then
        cp "$DEPS_DIR/python3" "$PYTHON_BIN" 2>>"$LOG_FILE"
        chmod 755 "$PYTHON_BIN"
        log "Installed bundled python3 to $PYTHON_BIN"
    fi

    if [ -f "$DEPS_DIR/libpython3.11.so.1.0" ] && [ ! -f "$LIB_DIR_PRIMARY/libpython3.11.so.1.0" ]; then
        cp "$DEPS_DIR/libpython3.11.so.1.0" "$LIB_DIR_PRIMARY/libpython3.11.so.1.0" 2>>"$LOG_FILE"
        chmod 644 "$LIB_DIR_PRIMARY/libpython3.11.so.1.0"
        log "Installed libpython3.11.so.1.0 to $LIB_DIR_PRIMARY"
    fi

    for sofile in "$DEPS_DIR"/*.so "$DEPS_DIR"/*.so.*; do
        [ -e "$sofile" ] || continue
        base="$(basename "$sofile")"
        if [ ! -f "$LIB_DIR_PRIMARY/$base" ]; then
            cp "$sofile" "$LIB_DIR_PRIMARY/$base" 2>>"$LOG_FILE"
            chmod 644 "$LIB_DIR_PRIMARY/$base"
            log "Installed shared library $base"
        fi
    done

    return 0
}

bootstrap_first_launch() {
    log "Starting dependency bootstrap"

    export LD_LIBRARY_PATH="$LIB_DIR_PRIMARY:$LIB_DIR_FALLBACK:$LD_LIBRARY_PATH"

    if python_works; then
        log "Python already working"
        touch "$STATE_FILE"
        return 0
    fi

    log "Python not working, attempting local dependency install"
    install_deps_from_bundle || log "Bundled dependency install did not complete cleanly"

    export LD_LIBRARY_PATH="$LIB_DIR_PRIMARY:$LIB_DIR_FALLBACK:$LD_LIBRARY_PATH"

    if python_works; then
        log "Python working after bootstrap"
        touch "$STATE_FILE"
        return 0
    fi

    log "Python still not working after bootstrap"
    return 1
}

write_python_server() {
cat > "$PY_FILE" <<EOF
#!/usr/bin/env python3
import http.server
import socketserver
import os
import traceback
from datetime import datetime
from urllib.parse import unquote

UPLOAD_DIR = "${UPLOAD_DIR}"
SERVE_DIR = "${SERVE_DIR}"
LOG_FILE = "${LOG_FILE}"
PORT = ${HTTP_PORT}

os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(SERVE_DIR, exist_ok=True)

def log(msg):
    with open(LOG_FILE, "a") as f:
        f.write(f"{datetime.now()}: {msg}\\n")

class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):
        log(fmt % args)

    def _send_text(self, text, code=200, content_type="text/plain; charset=utf-8"):
        data = text.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(data)

    def _send_html(self, html, code=200):
        self._send_text(html, code, "text/html; charset=utf-8")

    def do_GET(self):
        try:
            if self.path == "/":
                items = []
                for f in sorted(os.listdir(SERVE_DIR)):
                    full = os.path.join(SERVE_DIR, f)
                    if os.path.isfile(full):
                        items.append(f'<li><a href="/files/{f}">{f}</a></li>')

                self._send_html(f"""<html>
<head><title>wifi snatcher server</title></head>
<body>
<h2>Theme Transfer Server</h2>
<p>Upload with HTTP POST to <code>/upload</code> using header <code>X-Filename</code>.</p>
<p>Downloads are available below.</p>
<ul>{''.join(items)}</ul>
</body>
</html>""")
                return

            if self.path.startswith("/files/"):
                filename = os.path.basename(unquote(self.path[len("/files/"):]))
                filepath = os.path.join(SERVE_DIR, filename)

                if not os.path.isfile(filepath):
                    self._send_text("Not found\\n", 404)
                    return

                self.send_response(200)
                self.send_header("Content-Type", "application/octet-stream")
                self.send_header("Content-Disposition", f'attachment; filename="{filename}"')
                self.send_header("Content-Length", str(os.path.getsize(filepath)))
                self.send_header("Connection", "close")
                self.end_headers()

                with open(filepath, "rb") as f:
                    while True:
                        chunk = f.read(65536)
                        if not chunk:
                            break
                        self.wfile.write(chunk)

                log(f"Downloaded {filename}")
                return

            self._send_text("Not found\\n", 404)

        except Exception as e:
            log(f"GET error: {e}")
            log(traceback.format_exc())
            try:
                self._send_text("GET error\\n", 500)
            except:
                pass

    def do_POST(self):
        try:
            if self.path != "/upload":
                self._send_text("Not found\\n", 404)
                return

            filename = self.headers.get("X-Filename", "").strip()
            if not filename:
                self._send_text("Missing X-Filename header\\n", 400)
                return

            filename = os.path.basename(filename)

            cl = self.headers.get("Content-Length")
            if not cl:
                self._send_text("Missing Content-Length\\n", 411)
                return

            content_length = int(cl)
            if content_length < 0:
                self._send_text("Bad Content-Length\\n", 400)
                return

            filepath = os.path.join(UPLOAD_DIR, filename)

            remaining = content_length
            with open(filepath, "wb") as f:
                while remaining > 0:
                    chunk = self.rfile.read(min(65536, remaining))
                    if not chunk:
                        break
                    f.write(chunk)
                    remaining -= len(chunk)

            if remaining != 0:
                log(f"Upload incomplete for {filename}, {remaining} bytes missing")
                self._send_text("Incomplete upload\\n", 400)
                return

            log(f"Uploaded {filename} ({content_length} bytes)")
            self._send_text(f"Upload successful: {filename}\\n", 200)

        except Exception as e:
            log(f"POST error: {e}")
            log(traceback.format_exc())
            try:
                self._send_text("POST error\\n", 500)
            except:
                pass

if __name__ == "__main__":
    try:
        log(f"Starting Python HTTP server on port {PORT}")
        with ReusableTCPServer(("0.0.0.0", PORT), Handler) as httpd:
            log(f"Server running on port {PORT}")
            httpd.serve_forever()
    except Exception as e:
        log(f"Fatal server error: {e}")
        log(traceback.format_exc())
        raise
EOF

    chmod +x "$PY_FILE"
}

start_python_server() {
    export LD_LIBRARY_PATH="$LIB_DIR_PRIMARY:$LIB_DIR_FALLBACK:$LD_LIBRARY_PATH"
    write_python_server
    "$PYTHON_BIN" "$PY_FILE" >>"$LOG_FILE" 2>&1 &
    SERVER_PID=$!
    echo "$SERVER_PID" > "$PID_FILE"
    sleep 2
    kill -0 "$SERVER_PID" 2>/dev/null
}

start_busybox_fallback() {
    if have_cmd busybox; then
        log "Starting BusyBox fallback server on port $HTTP_PORT"
        busybox httpd -f -p "$HTTP_PORT" -h "$SERVE_DIR" >>"$LOG_FILE" 2>&1 &
        SERVER_PID=$!
        echo "$SERVER_PID" > "$PID_FILE"
        sleep 2
        kill -0 "$SERVER_PID" 2>/dev/null
        return $?
    fi
    return 1
}

cleanup() {
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE" 2>/dev/null)" 2>/dev/null
    fi
    rm -f "$PID_FILE" "$PY_FILE"
    LED OFF
}

LED SOLID GREEN
log "Starting file transfer server on port $HTTP_PORT"
log "Pager IP: 172.16.52.1"

MODE=""

if [ ! -f "$STATE_FILE" ]; then
    log "First launch detected"
    bootstrap_first_launch
else
    log "Bootstrap already completed previously"
fi

if python_works; then
    if start_python_server; then
        MODE="python"
        log "Python server started successfully"
    else
        log "Python server failed to start"
    fi
fi

if [ -z "$MODE" ]; then
    if start_busybox_fallback; then
        MODE="busybox"
        log "BusyBox fallback server started successfully"
    else
        log "BusyBox fallback failed"
        LED OFF
        ERROR_DIALOG "Server failed to start

Check:
$LOG_FILE"
        cleanup
        exit 1
    fi
fi

if [ "$MODE" = "python" ]; then
    PROMPT "Theme Transfer Server Running

Mode: $MODE
IP: 172.16.52.1
Port: $HTTP_PORT

Uploads: $UPLOAD_DIR
Downloads: $SERVE_DIR

Log: $LOG_FILE

Press OK when done"
else
    PROMPT "Theme Transfer Server Running

Mode: $MODE
IP: 172.16.52.1
Port: $HTTP_PORT

Downloads only: $SERVE_DIR
Uploads unavailable in fallback mode

Log: $LOG_FILE

Press OK when done"
fi

cleanup
exit 0
