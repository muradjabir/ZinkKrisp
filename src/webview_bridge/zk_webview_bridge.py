import argparse
import urllib.request
import urllib.parse
import json
import base64
import ctypes
import hashlib
import threading
import socket
import subprocess
import signal
import sys
import time
import os
import mmap
import struct
import io


class SimpleWebSocket:
    """Minimal RFC 6455 client using only Python stdlib (no websocket-client needed)."""

    def __init__(self, sock):
        self._sock = sock

    @classmethod
    def connect(cls, url, timeout=2.0, keep_timeout=False):
        parsed = urllib.parse.urlparse(url)
        host = parsed.hostname or "127.0.0.1"
        port = parsed.port or 80
        path = parsed.path or "/"
        if parsed.query:
            path += "?" + parsed.query

        sock = socket.create_connection((host, port), timeout=timeout)
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        req = (
            f"GET {path} HTTP/1.1\r\n"
            f"Host: {host}:{port}\r\n"
            f"Upgrade: websocket\r\n"
            f"Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            f"Sec-WebSocket-Version: 13\r\n\r\n"
        )
        sock.sendall(req.encode("ascii"))

        buf = b""
        while b"\r\n\r\n" not in buf:
            chunk = sock.recv(4096)
            if not chunk:
                sock.close()
                raise ConnectionError("WebSocket handshake closed")
            buf += chunk
        header_end = buf.index(b"\r\n\r\n")
        status_line = buf[:header_end].split(b"\r\n", 1)[0]
        if b" 101 " not in status_line:
            sock.close()
            raise ConnectionError(f"WebSocket handshake failed: {status_line!r}")

        ws = cls(sock)
        ws._extra = buf[header_end + 4:]
        if not keep_timeout:
            sock.settimeout(None)
        return ws

    def _recv_exact(self, n):
        out = bytearray()
        if getattr(self, "_extra", b""):
            take = min(n, len(self._extra))
            out.extend(self._extra[:take])
            self._extra = self._extra[take:]
        while len(out) < n:
            chunk = self._sock.recv(n - len(out))
            if not chunk:
                raise EOFError("WebSocket closed")
            out.extend(chunk)
        return bytes(out)

    def send(self, text):
        payload = text.encode("utf-8") if isinstance(text, str) else text
        header = bytearray([0x81])  # FIN + text frame
        n = len(payload)
        if n < 126:
            header.append(0x80 | n)
        elif n < 65536:
            header.append(0x80 | 126)
            header.extend(struct.pack("!H", n))
        else:
            header.append(0x80 | 127)
            header.extend(struct.pack("!Q", n))
        mask = os.urandom(4)
        header.extend(mask)
        masked = bytes(b ^ mask[i & 3] for i, b in enumerate(payload))
        self._sock.sendall(bytes(header) + masked)

    def recv(self):
        chunks = []
        while True:
            b1, b2 = self._recv_exact(2)
            fin = (b1 & 0x80) != 0
            opcode = b1 & 0x0F
            masked = (b2 & 0x80) != 0
            length = b2 & 0x7F
            if length == 126:
                length = struct.unpack("!H", self._recv_exact(2))[0]
            elif length == 127:
                length = struct.unpack("!Q", self._recv_exact(8))[0]
            mask = self._recv_exact(4) if masked else None
            data = self._recv_exact(length) if length else b""
            if mask:
                data = bytes(b ^ mask[i & 3] for i, b in enumerate(data))
            if opcode == 0x8:  # Close
                return ""
            if opcode == 0x9:  # Ping -> send Pong
                try:
                    pmask = os.urandom(4)
                    hdr = bytes([0x8A, 0x80 | len(data)]) + pmask
                    self._sock.sendall(hdr + bytes(b ^ pmask[i & 3] for i, b in enumerate(data)))
                except Exception:
                    pass
                continue
            if opcode == 0xA:  # Pong
                continue
            chunks.append(data)
            if fin:
                return b"".join(chunks).decode("utf-8", errors="replace")

    def close(self):
        try:
            self._sock.close()
        except Exception:
            pass


# Native macOS ImageIO + CoreGraphics JPEG/PNG -> BGRA decoder (zero third-party deps)
_cf = ctypes.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
_cg = ctypes.CDLL("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
_iio = ctypes.CDLL("/System/Library/Frameworks/ImageIO.framework/ImageIO")

_cf.CFDataCreate.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_long]
_cf.CFDataCreate.restype = ctypes.c_void_p
_cf.CFRelease.argtypes = [ctypes.c_void_p]
_cf.CFRelease.restype = None

_iio.CGImageSourceCreateWithData.argtypes = [ctypes.c_void_p, ctypes.c_void_p]
_iio.CGImageSourceCreateWithData.restype = ctypes.c_void_p
_iio.CGImageSourceCreateImageAtIndex.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p]
_iio.CGImageSourceCreateImageAtIndex.restype = ctypes.c_void_p

_cg.CGImageGetWidth.argtypes = [ctypes.c_void_p]
_cg.CGImageGetWidth.restype = ctypes.c_size_t
_cg.CGImageGetHeight.argtypes = [ctypes.c_void_p]
_cg.CGImageGetHeight.restype = ctypes.c_size_t
_cg.CGColorSpaceCreateDeviceRGB.argtypes = []
_cg.CGColorSpaceCreateDeviceRGB.restype = ctypes.c_void_p
_cg.CGBitmapContextCreate.argtypes = [
    ctypes.c_void_p, ctypes.c_size_t, ctypes.c_size_t,
    ctypes.c_size_t, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_uint32
]
_cg.CGBitmapContextCreate.restype = ctypes.c_void_p


class _CGRect(ctypes.Structure):
    _fields_ = [("x", ctypes.c_double), ("y", ctypes.c_double),
                ("w", ctypes.c_double), ("h", ctypes.c_double)]


_cg.CGContextDrawImage.argtypes = [ctypes.c_void_p, _CGRect, ctypes.c_void_p]
_cg.CGContextDrawImage.restype = None

_COLORSPACE_RGB = _cg.CGColorSpaceCreateDeviceRGB()
_KCG_BGRA_BITMAP_INFO = (2 << 12) | 2  # kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst -> BGRA


def decode_image_to_bgra(img_bytes):
    cf_data = _cf.CFDataCreate(None, img_bytes, len(img_bytes))
    if not cf_data:
        raise ValueError("CFDataCreate failed")
    src = None
    cg_img = None
    ctx = None
    try:
        src = _iio.CGImageSourceCreateWithData(cf_data, None)
        if not src:
            raise ValueError("CGImageSourceCreateWithData failed")
        cg_img = _iio.CGImageSourceCreateImageAtIndex(src, 0, None)
        if not cg_img:
            raise ValueError("CGImageSourceCreateImageAtIndex failed")
        w = int(_cg.CGImageGetWidth(cg_img))
        h = int(_cg.CGImageGetHeight(cg_img))
        buf = ctypes.create_string_buffer(w * h * 4)
        ctx = _cg.CGBitmapContextCreate(buf, w, h, 8, w * 4, _COLORSPACE_RGB, _KCG_BGRA_BITMAP_INFO)
        if not ctx:
            raise ValueError("CGBitmapContextCreate failed")
        _cg.CGContextDrawImage(ctx, _CGRect(0.0, 0.0, float(w), float(h)), cg_img)
        return w, h, buf.raw
    finally:
        if ctx:
            _cf.CFRelease(ctx)
        if cg_img:
            _cf.CFRelease(cg_img)
        if src:
            _cf.CFRelease(src)
        _cf.CFRelease(cf_data)

parser = argparse.ArgumentParser(description="Generic WebView2 CDP SHM Overlay Daemon")
parser.add_argument("--cdp-port", type=int, default=9222, help="Remote debugging CDP port")
parser.add_argument("--udp-port", type=int, default=9223, help="Input UDP bridge port")
parser.add_argument("--shm-path", type=str, default="/tmp/zk_webview_fb.bin", help="Shared memory framebuffer file path")
args, _ = parser.parse_known_args()

CDP_PORT = args.cdp_port
UDP_PORT = args.udp_port
SHM_PATH = args.shm_path
SHM_SIZE = 16 * 1024 * 1024  # 16 MB

if not os.path.exists(SHM_PATH) or os.path.getsize(SHM_PATH) < SHM_SIZE:
    with open(SHM_PATH, "wb") as f:
        f.seek(SHM_SIZE - 1)
        f.write(b"\0")

shm_fd = os.open(SHM_PATH, os.O_RDWR)
shm = mmap.mmap(shm_fd, SHM_SIZE)

HEADER_FMT = "<Iiiii"
HEADER_SIZE = struct.calcsize(HEADER_FMT)

# Generic IE legacy window.event.srcElement polyfill + lightweight DOM MutationObserver
IE_EVENT_POLYFILL_JS = r"""
(function() {
  if (!window.__zkDomObserverInstalled) {
    window.__zkDomObserverInstalled = true;
    window.__zkDomVersion = 1;
    try {
      new MutationObserver(() => { window.__zkDomVersion++; })
        .observe(document, { subtree: true, childList: true, attributes: true, characterData: true });
    } catch (_) {}
  }
  if (window.__zkIeEventPolyfillInstalled) return;
  window.__zkIeEventPolyfillInstalled = true;
  let activeEvent = null;
  const ensureProps = (e) => {
    if (e && !('srcElement' in e)) {
      try { Object.defineProperty(e, 'srcElement', { get: () => e.target, configurable: true }); } catch (_) {}
    }
    return e;
  };
  ['mousedown', 'mouseup', 'click', 'dblclick', 'mousemove', 'mouseover', 'mouseout', 'keydown', 'keyup', 'keypress', 'change', 'input', 'submit'].forEach(type => {
    window.addEventListener(type, (e) => { activeEvent = ensureProps(e); }, true);
  });
  const origDispatch = EventTarget.prototype.dispatchEvent;
  EventTarget.prototype.dispatchEvent = function(e) {
    const prev = activeEvent;
    activeEvent = ensureProps(e);
    try { return origDispatch.call(this, e); }
    finally { activeEvent = prev; }
  };
  const nativeDesc = Object.getOwnPropertyDescriptor(Window.prototype, 'event');
  Object.defineProperty(window, 'event', {
    get: function() {
      const nativeEv = nativeDesc && nativeDesc.get ? nativeDesc.get.call(this) : undefined;
      return ensureProps(nativeEv || activeEvent);
    },
    set: function(v) { activeEvent = ensureProps(v); },
    configurable: true
  });
})();
"""

seq_counter = 0
active_target_id = None
active_ws = None
ws_lock = threading.Lock()
msg_id = 1
is_active_dialog = 0

current_img_dims = [800.0, 600.0]
active_win_geom = {"w": 0, "h": 0, "isDialog": 0, "ts": 0.0}
target_metrics = {}  # tid -> {"w": int, "h": int, "focus": bool}
injected_targets = set()

# Adaptive capture state
last_user_input_time = 0.0
last_capture_time = 0.0
last_dom_poll_time = 0.0
last_captured_dom_ver = -1
shot_in_flight = False
shot_in_flight_ts = 0.0
pending_dom_ver_id = None
pending_metrics_id = None


def send_cmd(s, method, params=None):
    global msg_id
    with ws_lock:
        mid = msg_id
        msg_id += 1
        d = {"id": mid, "method": method}
        if params is not None:
            d["params"] = params
        try:
            s.send(json.dumps(d))
        except Exception:
            return None
        return mid


def install_polyfill_on_ws(sock):
    send_cmd(sock, "Page.enable")
    send_cmd(sock, "Page.addScriptToEvaluateOnNewDocument", {"source": IE_EVENT_POLYFILL_JS})
    send_cmd(sock, "Runtime.evaluate", {"expression": IE_EVENT_POLYFILL_JS})


def write_frame_shm(img_bytes, is_dialog):
    global seq_counter, current_img_dims
    try:
        w, h, bgra_data = decode_image_to_bgra(img_bytes)
        current_img_dims = [float(w), float(h)]

        seq_counter += 1
        header = struct.pack(
            HEADER_FMT,
            0x5A4B4642,
            seq_counter,
            1 if is_dialog else 0,
            int(w),
            int(h)
        )
        shm.seek(0)
        shm.write(header)
        shm.write(bgra_data)
    except Exception as e:
        print("[SHM Error]", e)


def trigger_shot(sock=None):
    global shot_in_flight, shot_in_flight_ts, last_capture_time
    s = sock or active_ws
    if not s:
        return
    shot_in_flight = True
    shot_in_flight_ts = time.time()
    last_capture_time = shot_in_flight_ts
    mid = send_cmd(s, "Page.captureScreenshot", {"format": "jpeg", "quality": 90})
    if mid is None:
        shot_in_flight = False


def schedule_burst_shots(sock=None):
    s = sock or active_ws
    if not s:
        return
    trigger_shot(s)
    for delay in (0.12, 0.35, 0.80):
        threading.Timer(delay, trigger_shot, args=(s,)).start()


def stream_listener(sock, tid, is_dialog):
    global active_target_id, active_ws, shot_in_flight
    global last_captured_dom_ver, pending_dom_ver_id, pending_metrics_id
    while True:
        try:
            data = sock.recv()
            if not data:
                break
            msg = json.loads(data)
            method = msg.get("method")
            if method in ("Page.frameNavigated", "Page.loadEventFired"):
                send_cmd(sock, "Runtime.evaluate", {"expression": IE_EVENT_POLYFILL_JS})
                pending_metrics_id = send_cmd(sock, "Runtime.evaluate", {
                    "expression": "JSON.stringify({innerW: window.innerWidth, innerH: window.innerHeight, focus: document.hasFocus()})"
                })
                last_captured_dom_ver = -1
                schedule_burst_shots(sock)
            elif msg.get("id") and "result" in msg:
                rid = msg["id"]
                res = msg["result"]
                if "data" in res:
                    shot_in_flight = False
                    raw_bytes = base64.b64decode(res["data"])
                    write_frame_shm(raw_bytes, is_dialog)
                elif rid == pending_dom_ver_id:
                    pending_dom_ver_id = None
                    val = res.get("result", {}).get("value")
                    if isinstance(val, (int, float)):
                        dom_ver = int(val)
                        if dom_ver != last_captured_dom_ver and not shot_in_flight:
                            last_captured_dom_ver = dom_ver
                            trigger_shot(sock)
                elif rid == pending_metrics_id:
                    pending_metrics_id = None
                    val = res.get("result", {}).get("value", "")
                    if isinstance(val, str) and val.startswith("{"):
                        try:
                            m = json.loads(val)
                            target_metrics[tid] = {
                                "w": int(m.get("innerW", 0)),
                                "h": int(m.get("innerH", 0)),
                                "focus": bool(m.get("focus", False)),
                                "ts": time.time(),
                            }
                        except Exception:
                            pass
            elif msg.get("id") and "error" in msg:
                if shot_in_flight:
                    shot_in_flight = False
        except Exception:
            break

    if active_target_id == tid:
        active_target_id = None
        active_ws = None
        shot_in_flight = False


def adaptive_capture_worker():
    global last_dom_poll_time, pending_dom_ver_id, shot_in_flight
    while True:
        now = time.time()
        s = active_ws
        if s:
            if shot_in_flight and (now - shot_in_flight_ts >= 2.0):
                shot_in_flight = False

            if (now - last_user_input_time) < 0.6:
                # Interactive Mode: up to ~28-30 FPS
                if not shot_in_flight and (now - last_capture_time >= 0.035):
                    trigger_shot(s)
                time.sleep(0.025)
                continue
            else:
                # Background / File-Transfer Mode: poll DOM version at 2 Hz, 0 FPS if static
                if (now - last_dom_poll_time >= 0.5) and not shot_in_flight:
                    last_dom_poll_time = now
                    pending_dom_ver_id = send_cmd(s, "Runtime.evaluate", {
                        "expression": "window.__zkDomVersion || 0"
                    })
                time.sleep(0.1)
                continue
        time.sleep(0.2)


def udp_worker(udp):
    global last_user_input_time

    while True:
        try:
            data, _ = udp.recvfrom(4096)
            cmd = json.loads(data.decode("utf-8"))
            ev = cmd.get("type")

            if ev == "windows":
                act = cmd.get("active", {})
                if act:
                    nw = int(act.get("w", 0))
                    nh = int(act.get("h", 0))
                    if nw != active_win_geom["w"] or nh != active_win_geom["h"]:
                        if active_target_id and active_target_id in target_metrics:
                            target_metrics[active_target_id]["ts"] = 0
                    active_win_geom["w"] = nw
                    active_win_geom["h"] = nh
                    active_win_geom["isDialog"] = int(act.get("isDialog", 0))
                    active_win_geom["ts"] = time.time()
                continue

            if not active_ws:
                continue

            last_user_input_time = time.time()

            win_w = float(cmd.get("winW", current_img_dims[0]) or current_img_dims[0])
            win_h = float(cmd.get("winH", current_img_dims[1]) or current_img_dims[1])
            raw_x = float(cmd.get("x", 0))
            raw_y = float(cmd.get("y", 0))

            tm = target_metrics.get(active_target_id) or {}
            css_w = float(tm.get("w") or win_w)
            css_h = float(tm.get("h") or win_h)
            cx = round(raw_x * (css_w / win_w), 1)
            cy = round(raw_y * (css_h / win_h), 1)

            if ev == "mouseMoved":
                send_cmd(active_ws, "Input.dispatchMouseEvent", {
                    "type": "mouseMoved", "x": cx, "y": cy, "button": "none", "buttons": 0
                })

            elif ev == "mousePressed":
                send_cmd(active_ws, "Input.dispatchMouseEvent", {
                    "type": "mouseMoved", "x": cx, "y": cy, "button": "none", "buttons": 0
                })
                send_cmd(active_ws, "Input.dispatchMouseEvent", {
                    "type": "mousePressed", "x": cx, "y": cy, "button": "left", "buttons": 1, "clickCount": 1
                })

            elif ev == "mouseReleased":
                send_cmd(active_ws, "Input.dispatchMouseEvent", {
                    "type": "mouseReleased", "x": cx, "y": cy, "button": "left", "buttons": 0, "clickCount": 1
                })
                schedule_burst_shots(active_ws)

            elif ev == "mouseWheel":
                send_cmd(active_ws, "Input.dispatchMouseEvent", {
                    "type": "mouseWheel", "x": cx, "y": cy, "deltaX": 0, "deltaY": cmd.get("deltaY", 0)
                })

            elif ev == "insertText":
                send_cmd(active_ws, "Input.insertText", {"text": cmd.get("text", "")})
                schedule_burst_shots(active_ws)

            elif ev == "dispatchKeyEvent":
                send_cmd(active_ws, "Input.dispatchKeyEvent", cmd.get("params", {}))
                schedule_burst_shots(active_ws)

        except Exception:
            pass


def probe_target_metrics(t):
    tid = t.get("id")
    ws_url = t.get("webSocketDebuggerUrl")
    if not ws_url:
        return None
    try:
        pws = SimpleWebSocket.connect(ws_url, timeout=0.4, keep_timeout=True)
        if tid not in injected_targets:
            pws.send(json.dumps({"id": 101, "method": "Page.enable"}))
            pws.send(json.dumps({"id": 102, "method": "Page.addScriptToEvaluateOnNewDocument", "params": {"source": IE_EVENT_POLYFILL_JS}}))
            pws.send(json.dumps({"id": 103, "method": "Runtime.evaluate", "params": {"expression": IE_EVENT_POLYFILL_JS}}))
            injected_targets.add(tid)
        pws.send(json.dumps({
            "id": 104,
            "method": "Runtime.evaluate",
            "params": {"expression": "JSON.stringify({innerW: window.innerWidth, innerH: window.innerHeight, focus: document.hasFocus()})"}
        }))
        deadline = time.time() + 0.4
        while time.time() < deadline:
            raw = pws.recv()
            msg = json.loads(raw)
            if msg.get("id") == 104:
                val = msg.get("result", {}).get("result", {}).get("value", "")
                if val:
                    m = json.loads(val)
                    target_metrics[tid] = {
                        "w": int(m.get("innerW", 0)),
                        "h": int(m.get("innerH", 0)),
                        "focus": bool(m.get("focus", False)),
                        "ts": time.time(),
                    }
                break
        pws.close()
    except Exception:
        pass
    return target_metrics.get(tid)


def select_best_page_target(page_targets):
    global pending_metrics_id
    if not page_targets:
        return None, 0

    if len(page_targets) == 1:
        t0 = page_targets[0]
        tid0 = t0.get("id")
        cached0 = target_metrics.get(tid0)
        if tid0 == active_target_id and active_ws and pending_metrics_id is None:
            if not cached0 or cached0.get("w", 0) <= 0 or (time.time() - cached0.get("ts", 0) >= 1.5):
                pending_metrics_id = send_cmd(active_ws, "Runtime.evaluate", {
                    "expression": "JSON.stringify({innerW: window.innerWidth, innerH: window.innerHeight, focus: document.hasFocus()})"
                })
        is_dlg = active_win_geom["isDialog"] if (time.time() - active_win_geom["ts"] < 2.0) else 0
        return t0, is_dlg

    for t in page_targets:
        tid = t.get("id")
        if tid != active_target_id:
            cached = target_metrics.get(tid)
            if not cached or cached.get("w", 0) <= 0:
                probe_target_metrics(t)
        elif active_ws and pending_metrics_id is None:
            pending_metrics_id = send_cmd(active_ws, "Runtime.evaluate", {
                "expression": "JSON.stringify({innerW: window.innerWidth, innerH: window.innerHeight, focus: document.hasFocus()})"
            })

    has_geom = (time.time() - active_win_geom["ts"] < 2.0) and active_win_geom["w"] > 10 and active_win_geom["h"] > 10
    if has_geom:
        gw, gh = active_win_geom["w"], active_win_geom["h"]
        is_dlg = active_win_geom.get("isDialog", 0)
        best_t = None
        best_score = 10**9
        for t in page_targets:
            url_str = t.get("url", "").lower()
            m = target_metrics.get(t.get("id"))
            if m and m.get("w", 0) > 0 and m.get("h", 0) > 0:
                mw, mh = m["w"], m["h"]
                diff1 = abs(mw - gw) + abs(mh - gh)
                diff2 = abs(mw * 2 - gw) + abs(mh * 2 - gh)
                diff = min(diff1, diff2)
                score = diff * 10
            else:
                # Fallback score when metrics are not ready yet (never skip a newly opened dialog!)
                score = 2000

            # Strongly match modal dialog targets (e.g. HtmlDialog.html) when is_dlg == 1
            is_dialog_url = ("dialog" in url_str or "modal" in url_str)
            if is_dlg and is_dialog_url:
                score -= 10000
            elif not is_dlg and is_dialog_url:
                score += 10000

            if m and m.get("focus"):
                score -= 5

            if score < best_score:
                best_score = score
                best_t = t
        if best_t is not None:
            return best_t, active_win_geom["isDialog"]

    for t in page_targets:
        m = target_metrics.get(t.get("id"))
        if m and m.get("focus"):
            return t, 0
    return page_targets[-1], 0


def cleanup_existing_daemons(udp_port):
    my_pid = os.getpid()
    my_ppid = os.getppid()
    try:
        out = subprocess.check_output(["ps", "-eo", "pid,args"], text=True)
        for line in out.splitlines():
            parts = line.strip().split(None, 1)
            if len(parts) < 2:
                continue
            try:
                pid = int(parts[0])
            except ValueError:
                continue
            if pid in (my_pid, my_ppid):
                continue
            cmd = parts[1]
            tokens = cmd.split()
            if len(tokens) < 2:
                continue
            if "python" not in os.path.basename(tokens[0]).lower():
                continue
            if not any(os.path.basename(t) == "zk_webview_bridge.py" for t in tokens[1:]):
                continue
            port_val = 9223
            for idx, tok in enumerate(tokens):
                if tok == "--udp-port" and idx + 1 < len(tokens):
                    try:
                        port_val = int(tokens[idx + 1])
                    except ValueError:
                        pass
                elif tok.startswith("--udp-port="):
                    try:
                        port_val = int(tok.split("=", 1)[1])
                    except ValueError:
                        pass
            if port_val == udp_port:
                try:
                    os.kill(pid, signal.SIGKILL)
                except OSError:
                    pass
    except Exception:
        pass


cleanup_existing_daemons(UDP_PORT)
udp_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
udp_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    udp_sock.bind(("127.0.0.1", UDP_PORT))
except OSError:
    time.sleep(0.2)
    try:
        udp_sock.bind(("127.0.0.1", UDP_PORT))
    except OSError as e:
        print(f"[Fatal] Failed to bind UDP port {UDP_PORT}: {e}", file=sys.stderr)
        sys.exit(1)

threading.Thread(target=udp_worker, args=(udp_sock,), daemon=True).start()
threading.Thread(target=adaptive_capture_worker, daemon=True).start()

ever_connected = False
last_cdp_ok = time.time()

while True:
    try:
        req = urllib.request.urlopen(f"http://127.0.0.1:{CDP_PORT}/json", timeout=0.5)
        targets = json.loads(req.read().decode())
        last_cdp_ok = time.time()
        page_targets = [t for t in targets if t.get("type") == "page"]
        if page_targets:
            ever_connected = True

        active_page, new_is_dialog = select_best_page_target(page_targets)
        if active_page:
            tid = active_page["id"]
            if tid != active_target_id:
                ws_url = active_page.get("webSocketDebuggerUrl")
                if active_ws:
                    try:
                        active_ws.close()
                    except Exception:
                        pass

                sock = SimpleWebSocket.connect(ws_url, timeout=2.0)
                active_target_id = tid
                active_ws = sock
                is_active_dialog = new_is_dialog
                last_captured_dom_ver = -1
                shot_in_flight = False
                pending_dom_ver_id = None
                pending_metrics_id = None

                install_polyfill_on_ws(sock)
                injected_targets.add(tid)

                send_cmd(sock, "Page.bringToFront")
                send_cmd(sock, "Emulation.setFocusEmulationEnabled", {"enabled": True})
                pending_metrics_id = send_cmd(sock, "Runtime.evaluate", {
                    "expression": "JSON.stringify({innerW: window.innerWidth, innerH: window.innerHeight, focus: document.hasFocus()})"
                })
                schedule_burst_shots(sock)

                threading.Thread(target=stream_listener, args=(sock, tid, is_active_dialog), daemon=True).start()

    except Exception:
        if ever_connected and (time.time() - last_cdp_ok > 180.0):
            os._exit(0)
    time.sleep(0.20)
