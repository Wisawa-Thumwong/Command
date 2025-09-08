import serial
import threading
import time
from collections import deque
from queue import Queue, Empty

import matplotlib
# ถ้าเปิดกราฟไม่ขึ้น ลอง uncomment บรรทัดต่อไป
# matplotlib.use("TkAgg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation

# ====================== DEFAULT CONFIG ======================
cfg = {
    # Serial
    "SERIAL_PORT": "COM3",
    "BAUD_RATE": 115200,
    "TIMEOUT": 1,

    # Frame
    "PACKET_LEN": 13,
    "ENDIAN": "big",        # "big" หรือ "little"

    # ตำแหน่ง X axis ภายในเฟรม (ตัวอย่าง xL=idx6, xM=idx7 !!False)
    "X_L_IDX": 7,                               #7        
    "X_M_IDX": 6,                               #6 X_MSB received before X_LSB

    # โหมดตีความ 16-bit เป็นค่าที่ต้องการ
    # 'msb_sign1'  : MSB เป็น sign (1=ลบ), 15 บิตเป็น magnitude
    # 'lsb_sign1'  : LSB เป็น sign (1=ลบ), magnitude = (raw >> 1)
    # 'twos'       : two's complement 16-bit มาตรฐาน
    "SIGN_MODE": "msb_sign1",

    # สเกลและ offset สำหรับ “ค่าที่จะพล็อต”
    # ตามเงื่อนไขที่คุณต้องการ:
    #   sign=1 -> (mag/273) - 120
    #   sign=0 -> (mag/273)
    "SCALE": 273.0,
    "OFFSET_POS": 0.0,      # offset เมื่อ sign=0 (บวก)
    "OFFSET_NEG": -120.0,   # offset เมื่อ sign=1 (ลบ)

    # Plot window & refresh
    "WINDOW_SAMPLES": 3000,
    "ANIM_INTERVAL_MS": 50,
}
cfg_lock = threading.Lock()
# ===========================================================


def _snap_cfg():
    """คืนค่าก๊อปปี้ของ cfg ปัจจุบัน (ป้องกันอ่านระหว่างอัปเดต)"""
    with cfg_lock:
        return dict(cfg)


def _ask_edit_int(prompt, cur):
    s = input(f"{prompt} [{cur}]: ").strip()
    return cur if s == "" else int(s, 0)  # รองรับ 10/16 เช่น 115200 หรือ 0x1C200

def _ask_edit_float(prompt, cur):
    s = input(f"{prompt} [{cur}]: ").strip()
    return cur if s == "" else float(s)

def _ask_edit_choice(prompt, cur, options):
    s = input(f"{prompt} {options} [{cur}]: ").strip().lower()
    return cur if s == "" else s

def _ask_edit_str(prompt, cur):
    s = input(f"{prompt} [{cur}]: ").strip()
    return cur if s == "" else s


def configure_menu_in_sender():
    """เมนูแก้ไข config — เรียกจากใน sender"""
    print("\n=== CONFIG MENU (กด Enter เพื่อคงค่าเดิม) ===")
    with cfg_lock:
        # Serial (เปลี่ยนพอร์ต/baud มีผลหลังรีสตาร์ตโปรแกรม เวอร์ชันนี้ยังไม่สลับพอร์ต runtime)
        cfg["SERIAL_PORT"] = cfg["SERIAL_PORT"]
        cfg["BAUD_RATE"]   = cfg["BAUD_RATE"]
        cfg["TIMEOUT"]     = cfg["TIMEOUT"]

        # Frame & parse
        cfg["PACKET_LEN"]  = cfg["PACKET_LEN"]
        cfg["ENDIAN"]      = cfg["ENDIAN"]
        cfg["X_L_IDX"]     = cfg["X_L_IDX"]
        cfg["X_M_IDX"]     = cfg["X_M_IDX"]

        cfg["SIGN_MODE"]   = cfg["SIGN_MODE"]
        cfg["SCALE"]       = cfg["SCALE"]
        cfg["OFFSET_POS"]  = cfg["OFFSET_POS"]
        cfg["OFFSET_NEG"]  = cfg["OFFSET_NEG"]

        cfg["WINDOW_SAMPLES"]   = cfg["WINDOW_SAMPLES"]
        cfg["ANIM_INTERVAL_MS"] = cfg["ANIM_INTERVAL_MS"]
    print("=== CONFIG UPDATED ===\n")


def decode_x_plot_from_raw16(raw16: int, c) -> float:
    """
    คืนค่า 'x_plot' ที่จะนำไปพล็อต ตามเงื่อนไข:
      sign=1 -> (mag/scale) + OFFSET_NEG  (เช่น -120)
      sign=0 -> (mag/scale) + OFFSET_POS  (เช่น 0)
    รองรับ 3 โหมด sign:
      - msb_sign1 : MSB เป็นบิตเครื่องหมาย
      - lsb_sign1 : LSB เป็นบิตเครื่องหมาย
      - twos      : two's complement 16-bit (กรณีนี้ x_plot = signed/scale)
    """
    raw16 &= 0xFFFF
    mode  = c["SIGN_MODE"]
    #print("raw16 =", raw16)
    if mode == 'msb_sign1':
        sign = 1 if (raw16 & 0x8000) else 0
        mag  = (raw16 & 0x7FFF)
        x_plot = (mag / c["SCALE"]) + (c["OFFSET_NEG"] if sign else c["OFFSET_POS"])
    elif mode == 'lsb_sign1':
        sign = 1 if (raw16 & 0x0001) else 0
        mag  = (raw16 >> 1) & 0x7FFF
        x_plot = (mag / c["SCALE"]) + (c["OFFSET_NEG"] if sign else c["OFFSET_POS"])
    elif mode == 'twos':
        signed = raw16 - 0x10000 if (raw16 & 0x8000) else raw16
        x_plot = signed / c["SCALE"]
    else:
        raise ValueError(f"Unknown SIGN_MODE: {mode}")
    print("x_plot =", x_plot)
    return x_plot


def parse_x_from_frame(frame: bytes, c) -> float:
    """ดึงค่า X จากเฟรม → คำนวณ x_plot ตามเงื่อนไขที่กำหนด"""
    if len(frame) != c["PACKET_LEN"]:
        raise ValueError("Frame length mismatch")
    lo = frame[c["X_L_IDX"]]                                                    #//
    hi = frame[c["X_M_IDX"]]
    raw16 = (hi << 8) | lo if c["ENDIAN"] == "big" else (lo << 8) | hi
    return decode_x_plot_from_raw16(raw16, c)


# ---------- Serial init ----------
def serial_open(c):
    ser = serial.Serial(
        c["SERIAL_PORT"],
        c["BAUD_RATE"],
        timeout=c["TIMEOUT"],
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE
    )
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    print(f"Connected to {c['SERIAL_PORT']} @ {c['BAUD_RATE']}")
    return ser


# ---------- Threads ----------
data_q = Queue()
ts_deque = deque(maxlen=5000)   # เก็บ timestamp เพื่อคำนวณ sampling rate

def serial_listener(ser):
    buf = bytearray()
    while True:
        try:
            c = _snap_cfg()  # อ่าน config ล่าสุด
            need = c["PACKET_LEN"] - len(buf)
            chunk = ser.read(need)
            if not chunk:
                continue
            buf.extend(chunk)

            if len(buf) == c["PACKET_LEN"]:
                frame = bytes(buf)

                # ถอดค่า X แล้วทำ "ค่าเพื่อพล็อต" ตามเงื่อนไข (รวม offset/scale)
                try:
                    x_plot = parse_x_from_frame(frame, c)
                    now = time.time()
                    data_q.put((now, x_plot))
                    ts_deque.append(now)
                except Exception as ex:
                    print("Parse error:", ex)

                buf.clear()
        except Exception as e:
            print("Serial error:", e)
            time.sleep(0.1)


def send_user_input(ser):
    """
    ฟังก์ชัน sender — มีเมนู config อยู่ในนี้
    คำสั่งพิเศษ:
      :config  -> เปิดเมนูตั้งค่า
      :show    -> แสดงค่าปัจจุบัน
      :help    -> ช่วยเหลือ
    นอกนั้นจะเข้าโหมดส่งคำสั่งแบบ bit ตามเดิม
    """
    # เปิดเมนู config ครั้งแรก
    configure_menu_in_sender()

    help_text = (
        "\nType ':config' แก้ไขตั้งค่า, ':show' ดูค่า, ':help' ดูวิธีใช้\n"
        "หรือกด Enter เพื่อเริ่มส่งคำสั่งตามโปรโตคอลเดิม\n"
    )
    print(help_text)

    while True:
        cmd = input("sender> ").strip().lower()

        if cmd == ":help":
            print(help_text)
            continue
        elif cmd == ":show":
            print("=== CURRENT CONFIG ===")
            print(_snap_cfg())
            print("======================")
            continue
        elif cmd == ":config":
            configure_menu_in_sender()
            continue
        elif cmd == "":
            # เข้าโหมดส่งคำสั่งตามเดิม
            pass
        else:
            print("ไม่รู้จักคำสั่ง (ลองใช้ :config / :show / :help หรือ Enter เพื่อส่งคำสั่ง)")
            continue

        try:
            # --- Command 1 ---
            target = int("52")
            RW_Mode = int("0")
            command1 = (target << 1) | RW_Mode
            ser.write((command1 & 0xFF).to_bytes(1, 'big'))
            print(f"Sent Command1 : 0x{command1:02X}")

            # --- Command 2 ---
            conv = int("1")
            reg  = int("0")
            command2 = (conv << 7) | reg
            ser.write((command2 & 0xFF).to_bytes(1, 'big'))
            print(f"Sent Command2 : 0x{command2:02X}")

            # --- Command 3 ---
            target1 = int("52")
            RW_Mode1 = int("1")
            command3 = (target1 << 1) | RW_Mode1
            ser.write((command3 & 0xFF).to_bytes(1, 'big'))
            print(f"Sent Command3 : 0x{command3:02X}")

            # --- Command 4 ---
            conv1 = 1
            reg1  = 12
            command4 = (conv1 << 7) | reg1
            ser.write((command4 & 0xFF).to_bytes(1, 'big'))
            print(f"Sent Command4 : 0x{command4:02X}")
        except ValueError:
            print("Invalid input, please enter numbers only.")
        except Exception as e:
            print(f"Error while sending command: {e}")


# ---------- Matplotlib real-time plot ----------
# หมายเหตุ: WINDOW_SAMPLES เปลี่ยน runtime ไม่ได้ใน deque (ต้องรีสตาร์ตโปรแกรม)
with cfg_lock:
    WINDOW_SAMPLES = cfg["WINDOW_SAMPLES"]
x_vals = deque(maxlen=WINDOW_SAMPLES)
idx_vals = deque(maxlen=WINDOW_SAMPLES)
sample_counter = 0

fig, ax = plt.subplots(figsize=(10, 5))
line_x, = ax.plot([], [], lw=1.5)
ax.set_title("X_Axis_Dec (real-time) — plotted value")
ax.set_xlabel("Sample index")
ax.set_ylabel("X_Axis_Dec (scaled by rule)")
ax.grid(True, alpha=0.3)
txt_fps = ax.text(0.02, 0.95, "", transform=ax.transAxes, va="top", ha="left")

def update_plot(_frame_id):
    global sample_counter

    pulled = 0
    while True:
        try:
            ts, x = data_q.get_nowait()
            sample_counter += 1
            idx_vals.append(sample_counter)
            x_vals.append(x)
            pulled += 1
        except Empty:
            break

    if pulled > 0:
        line_x.set_data(list(idx_vals), list(x_vals))
        ax.relim()
        ax.autoscale_view()

    # sampling rate ภายใน 1 วินาทีล่าสุด
    now = time.time()
    while ts_deque and (now - ts_deque[0]) > 1.0:
        ts_deque.popleft()
    fps = len(ts_deque)
    txt_fps.set_text(f"Sampling rate ~ {fps} fps")

    return line_x, txt_fps


def main():
    # เปิด serial จาก config ปัจจุบัน
    c0 = _snap_cfg()
    try:
        ser = serial_open(c0)
    except Exception as e:
        print(f"Could not connect: {e}")
        return

    # เริ่ม threads
    t_listener = threading.Thread(target=serial_listener, args=(ser,), daemon=True)
    t_sender   = threading.Thread(target=send_user_input, args=(ser,), daemon=True)
    t_listener.start()
    t_sender.start()

    # เริ่ม animation
    with cfg_lock:
        interval = cfg["ANIM_INTERVAL_MS"]
    ani = FuncAnimation(fig, update_plot, interval=interval, blit=False)

    try:
        plt.show()
    finally:
        ser.close()


if __name__ == "__main__":
    main()
