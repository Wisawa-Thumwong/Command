import serial
import threading
import time
 
# ===== Serial Config =====
SERIAL_PORT = 'COM3'   # เปลี่ยนตามเครื่อง
BAUD_RATE   = 115200
TIMEOUT     = 1
PACKET_LEN  = 2       # ความยาวเฟรม (ปรับตามเซนเซอร์จริง)
 
try:
    ser = serial.Serial(
        SERIAL_PORT,
        BAUD_RATE,
        timeout=TIMEOUT,
        bytesize=serial.EIGHTBITS,
        parity=serial.PARITY_NONE,
        stopbits=serial.STOPBITS_ONE
    )
    ser.reset_input_buffer()
    ser.reset_output_buffer()
    print(f"Connected to {SERIAL_PORT} at {BAUD_RATE} baud")
except Exception as e:
    print(f"Could not connect to {SERIAL_PORT} : {e}")
    exit()
 
def format_frame_remove_spaces(buf, remove_between=None, sep=" "):
    #- remove_between: ชุดของตำแหน่งช่อง (0..len(buf)-2) ที่ 'ไม่ต้องการคั่น'
    
    if remove_between is None:
        remove_between = set()
 
    parts = []
    for i, b in enumerate(buf):
        parts.append(f"{b:02X}")
        if i < len(buf) - 1 and i not in remove_between:
            parts.append(sep)
    return "".join(parts)
 
# ===== Listener =====
def listen_to_serial():
    """อ่านข้อมูลจาก serial ทีละเฟรม"""
    buf = bytearray()
    while True:
        chunk = ser.read(PACKET_LEN - len(buf))
        if not chunk:
            continue
        buf.extend(chunk)
 
        if len(buf) == PACKET_LEN:
            # แสดงเฟรมแบบ hex

            hex_frame = " ".join(f"{x:02X}" for x in buf)
            print(f"[Frame] {hex_frame}")

            s = format_frame_remove_spaces(buf, remove_between={4,6,8,10}, sep=" ")

            X_Axis_16Bit = s[0:1]
            print("X_Axis_16Bit = ", X_Axis_16Bit)
            X_Axis_int = int(s[0:1],16) & 0b11111
            print("X_Axis_int = ", X_Axis_int)
            
            X_Axis_bin = f"{X_Axis_int:016b}"
            print("X_Axis_bin = ", X_Axis_bin)

            X_Axis_2com = X_Axis_bin[0]
            print("X_Axis_2com = ", X_Axis_2com)

            X_Axis_15bit = X_Axis_bin[1:]
            print("X_Axis_15bit = ", X_Axis_15bit)
            
            X_Axis_Dec = int(X_Axis_15bit, 2)
            print("X_Axis_Dec = ", X_Axis_Dec)
            if X_Axis_2com == '1':
                print("X_Axis_Dec/273 = ", (X_Axis_Dec/273)-120)
            else:
                print("X_Axis_Dec/273 = ", (X_Axis_Dec/273))


            # print(int(rs))
            # print(rs_dec)
            # 68 08 49 54 44 80 0020 00 FF D0F3
 
            # TODO: parse ตามโปรโตคอลจริง
            # ตัวอย่าง (ถ้า 13 ไบต์): Tar, Dev, Manu, Manufac, T_L, T_M, X_L, X_M, Y_L, Y_M, Z_L, Z_M, Status
            # tar, dev, manu, manufac, tL, tM, xL, xM, yL, yM, zL, zM, status = buf
            # print(f"Target={tar}, Device={dev}, X={(xM<<8)|xL}, Y={(yM<<8)|yL}, Z={(zM<<8)|zL}, Status={status}")
 
            buf.clear()
 
 
# ===== Sender =====
def send_user_input():
    """รับ input จากผู้ใช้และส่งคำสั่งไปยัง sensor"""
    while True:
        try:
            # --- Command 1 ---
            target = int(input("Target Address : "), 0)
            RW_Mode = int(input("Read 1 / Write 0 : "), 0)
            command1 = (target << 1) | RW_Mode
            ser.write((command1 & 0xFF).to_bytes(1, 'big'))
            print(f"Sent Command1 : 0x{command1:02X}")
 
            # --- Command 2 ---
            conv = int(input("Conversion : "), 0)
            reg  = int(input("Register Address : "), 0)
            command2 = (conv << 7) | reg
            ser.write((command2 & 0xFF).to_bytes(1, 'big'))
            print(f"Sent Command2 : 0x{command2:02X}")
 
            # --- Command 3 ---
            target1 = int(input("Target Address2 : "), 0)
            RW_Mode1 = int(input("Read 1 / Write 0 : "), 0)
            command3 = (target1 << 1) | RW_Mode1
            ser.write((command3 & 0xFF).to_bytes(1, 'big'))
            print(f"Sent Command3 : 0x{command3:02X}")
 
            # --- Command 4 ---
            conv1 = int(input("Conversion2 : "), 0)
            reg1  = int(input("Register Address2 : "), 0)
            command4 = (conv1 << 7) | reg1
            ser.write((command4 & 0xFF).to_bytes(1, 'big'))
            print(f"Sent Command4 : 0x{command4:02X}")
 
        except ValueError:
            print("Invalid input, please enter numbers only.")
        except Exception as e:
            print(f"Error while sending command: {e}")
 
 
# ===== Main =====
def main():
    listener_thread = threading.Thread(target=listen_to_serial, daemon=True)
    sender_thread   = threading.Thread(target=send_user_input, daemon=True)
 
    listener_thread.start()
    sender_thread.start()
 
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("Program terminated by user.")
    finally:
        ser.close()
 
 
if __name__ == "__main__":
    main()