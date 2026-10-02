#!/usr/bin/env python3
"""Generate the sample's two images:
   docs/architecture.png  — the 7-container HA topology
   docs/verify-evidence.png — the real verification log, rendered
Run:  python3 docs/make_images.py
"""
import glob
import os
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
DOCS.mkdir(exist_ok=True)

MONO = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"
MONO_B = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"


def font(size, bold=False):
    path = MONO_B if bold else MONO
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


BG = (18, 20, 26)
FG = (230, 230, 230)
MUTED = (141, 147, 161)
ACCENT = (255, 209, 102)
GREEN = (6, 214, 160)
BLUE = (76, 201, 240)
RED = (255, 107, 107)
LINE = (60, 66, 80)


# ---------------------------------------------------------------- architecture
def architecture():
    W, H = 1500, 1000
    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    f_title = font(30, True)
    f_sub = font(17)
    f_box = font(19, True)
    f_small = font(15)
    f_tiny = font(13)

    def box(x, y, w, h, title, lines, border=LINE, fill=(26, 29, 36), dashed=False,
            title_color=FG):
        if dashed:
            # manual dashed rectangle
            step, seg = 14, 8
            for x0 in range(x, x + w, step):
                d.line([(x0, y), (min(x0 + seg, x + w), y)], fill=border, width=3)
                d.line([(x0, y + h), (min(x0 + seg, x + w), y + h)], fill=border, width=3)
            for y0 in range(y, y + h, step):
                d.line([(x, y0), (x, min(y0 + seg, y + h))], fill=border, width=3)
                d.line([(x + w, y0), (x + w, min(y0 + seg, y + h))], fill=border, width=3)
        else:
            d.rounded_rectangle([x, y, x + w, y + h], radius=10, fill=fill, outline=border, width=2)
        d.text((x + 14, y + 10), title, font=f_box, fill=title_color)
        for i, ln in enumerate(lines):
            d.text((x + 14, y + 40 + i * 20), ln, font=f_small, fill=MUTED)

    def arrow(x1, y1, x2, y2, color=BLUE, label=None, width=3, dashed=False):
        if dashed:
            steps = 22
            for i in range(steps):
                if i % 2:
                    continue
                ax = x1 + (x2 - x1) * i / steps
                ay = y1 + (y2 - y1) * i / steps
                bx = x1 + (x2 - x1) * (i + 1) / steps
                by = y1 + (y2 - y1) * (i + 1) / steps
                d.line([(ax, ay), (bx, by)], fill=color, width=width)
        else:
            d.line([(x1, y1), (x2, y2)], fill=color, width=width)
        # arrow head
        import math
        ang = math.atan2(y2 - y1, x2 - x1)
        for s in (2.6, -2.6):
            d.line([(x2, y2), (x2 - 16 * math.cos(ang + s / 6), y2 - 16 * math.sin(ang + s / 6))],
                   fill=color, width=width)
        if label:
            mx, my = (x1 + x2) / 2, (y1 + y2) / 2
            tw = d.textlength(label, font=f_tiny)
            d.rectangle([mx - tw / 2 - 5, my - 11, mx + tw / 2 + 5, my + 9], fill=BG)
            d.text((mx - tw / 2, my - 9), label, font=f_tiny, fill=color)

    d.text((40, 32), "Self-hosted HA web stack — 7 containers, one bridge network", font=f_title, fill=ACCENT)
    d.text((42, 74), "nginx L7 + L4  ·  keepalived VRRP VIP failover  ·  PHP-FPM  ·  Redis sessions  ·  MariaDB",
           font=f_sub, fill=MUTED)

    # clients
    box(40, 130, 300, 96, "clients", [
        "http  :8080  (L7)",
        "https :8443  (self-signed)",
        "ssh   :2222/:2223/:2224  (L4)",
    ], border=LINE)

    # VIP
    box(470, 130, 300, 96, "VIP  172.18.0.100", [
        "floats between the two LBs",
        "held by MASTER only",
    ], border=ACCENT, dashed=True, title_color=ACCENT)

    arrow(340, 178, 470, 178, BLUE, "ports")

    # LB pair
    box(400, 280, 220, 110, "nginx-lb", ["172.18.0.10", "keepalived MASTER", "nginx L7 + L4"],
        border=GREEN, title_color=GREEN)
    box(760, 280, 220, 110, "nginx-lb2", ["172.18.0.16", "keepalived BACKUP", "nginx L7 + L4"],
        border=GREEN, title_color=GREEN)
    arrow(620, 335, 760, 335, ACCENT, "VRRP unicast", dashed=True)
    arrow(470, 226, 480, 280, ACCENT, "")
    arrow(820, 226, 870, 280, ACCENT, "")

    # backends
    box(250, 470, 230, 120, "web1", ["172.18.0.11", "php-fpm 9000  ·  sshd 22", "pdo_mysql, redis ext"],
        border=BLUE)
    box(560, 470, 230, 120, "web2", ["172.18.0.12", "php-fpm 9000  ·  sshd 22", "pdo_mysql, redis ext"],
        border=BLUE)
    box(880, 470, 230, 120, "admin", ["172.18.0.15", "sshd 22  ·  docker-cli", "mgmt over docker.sock"],
        border=BLUE)
    arrow(480, 390, 380, 470, BLUE, "fastcgi 9000")
    arrow(560, 390, 660, 470, BLUE, "fastcgi 9000")
    arrow(880, 390, 960, 470, BLUE, "stream tcp 22")

    # data stores
    box(300, 690, 230, 110, "redis", ["172.18.0.13", "shared PHP sessions", "session.save_path"],
        border=(186, 134, 240))
    box(620, 690, 230, 110, "mariadb", ["172.18.0.14", "users · login_logs", "logger/logger123"],
        border=(186, 134, 240))
    arrow(340, 590, 400, 690, (186, 134, 240), "sessions")
    arrow(650, 590, 720, 690, (186, 134, 240), "pdo")

    # legend
    d.rectangle([1010, 690, 1460, 900], outline=LINE, width=2)
    d.text((1026, 704), "legend", font=f_box, fill=FG)
    d.line([(1026, 742), (1076, 742)], fill=BLUE, width=3)
    d.text((1088, 734), "L7 http (php-fpm fastcgi)", font=f_tiny, fill=MUTED)
    d.line([(1026, 772), (1076, 772)], fill=(186, 134, 240), width=3)
    d.text((1088, 764), "data path (redis / mariadb)", font=f_tiny, fill=MUTED)
    d.line([(1026, 802), (1076, 802)], fill=ACCENT, width=3)
    d.text((1088, 794), "VRRP failover (VIP 172.18.0.100)", font=f_tiny, fill=MUTED)
    d.text((1026, 826), "static IPs on bridge lbnet (172.18.0.0/16)", font=f_tiny, fill=MUTED)
    d.text((1026, 848), "keepalived = VRRP only → no ip_vs module", font=f_tiny, fill=MUTED)
    d.text((1026, 870), "needed (WSL2 kernels lack it)", font=f_tiny, fill=MUTED)

    out = DOCS / "architecture.png"
    img.save(out)
    print("wrote", out)


# ---------------------------------------------------------------- evidence
def evidence():
    logs = sorted(glob.glob(str(ROOT / "logs" / "verify-*.log")))
    if not logs:
        print("no verify log yet")
        return
    text = Path(logs[-1]).read_text(errors="replace")
    lines = [ln.rstrip() for ln in text.splitlines() if ln.strip()]

    f = font(18)
    f_head = font(22, True)
    line_h = 26
    W = 1280
    H = 120 + line_h * len(lines) + 90

    img = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(img)

    d.text((36, 30), "scripts/verify.sh — real output", font=f_head, fill=ACCENT)
    d.text((36, 64), f"source: {Path(logs[-1]).name}", font=font(15), fill=MUTED)

    y = 108
    for ln in lines:
        color = FG
        if "[PASS]" in ln:
            color = GREEN
        elif "[FAIL]" in ln:
            color = RED
        elif ln.strip().startswith("=="):
            color = ACCENT
        elif ln.startswith("  request") or ln.startswith("    "):
            color = MUTED
        if "RESULT:" in ln:
            color = GREEN if "0 failed" in ln else RED
        d.text((36, y), ln, font=f, fill=color)
        y += line_h

    out = DOCS / "verify-evidence.png"
    img.save(out)
    print("wrote", out, f"({len(lines)} lines)")


if __name__ == "__main__":
    architecture()
    evidence()
