import os
from PIL import Image, ImageDraw, ImageFont

def get_font(font_name="arial.ttf", size=16):
    paths = [
        f"C:\\Windows\\Fonts\\{font_name}",
        f"C:\\Windows\\Fonts\\Calibri.ttf",
        "arial.ttf"
    ]
    for p in paths:
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except:
                pass
    return ImageFont.load_default()

def draw_arrow(draw, start, end, color=(71, 85, 105), width=2):
    # Draw line
    draw.line([start, end], fill=color, width=width)
    # Draw arrowhead
    x1, y1 = start
    x2, y2 = end
    import math
    angle = math.atan2(y2 - y1, x2 - x1)
    arrow_len = 10
    arrow_angle = math.pi / 6
    px1 = x2 - arrow_len * math.cos(angle - arrow_angle)
    py1 = y2 - arrow_len * math.sin(angle - arrow_angle)
    px2 = x2 - arrow_len * math.cos(angle + arrow_angle)
    py2 = y2 - arrow_len * math.sin(angle + arrow_angle)
    draw.polygon([end, (px1, py1), (px2, py2)], fill=color)

def draw_capsule(draw, rect, fill_color, border_color, text, font, text_color=(15, 23, 42)):
    x1, y1, x2, y2 = rect
    r = (y2 - y1) // 2
    # Draw rounded rectangle
    draw.rounded_rectangle(rect, radius=r, fill=fill_color, outline=border_color, width=2)
    # Text
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    cx = (x1 + x2) // 2
    cy = (y1 + y2) // 2
    draw.text((cx - tw // 2, cy - th // 2 - 2), text, fill=text_color, font=font)

def draw_rectangle(draw, rect, fill_color, border_color, text, font, text_color=(15, 23, 42), radius=8):
    x1, y1, x2, y2 = rect
    draw.rounded_rectangle(rect, radius=radius, fill=fill_color, outline=border_color, width=2)
    # Multiline text center
    lines = text.split("\n")
    cy = (y1 + y2) // 2
    total_h = len(lines) * (font.size + 4)
    start_y = cy - total_h // 2
    for i, line in enumerate(lines):
        bbox = draw.textbbox((0, 0), line, font=font)
        tw = bbox[2] - bbox[0]
        cx = (x1 + x2) // 2
        draw.text((cx - tw // 2, start_y + i * (font.size + 4)), line, fill=text_color, font=font)

def draw_diamond(draw, rect, fill_color, border_color, text, font, text_color=(15, 23, 42)):
    x1, y1, x2, y2 = rect
    cx = (x1 + x2) // 2
    cy = (y1 + y2) // 2
    points = [(cx, y1), (x2, cy), (cx, y2), (x1, cy)]
    draw.polygon(points, fill=fill_color, outline=border_color, width=2)
    
    lines = text.split("\n")
    total_h = len(lines) * (font.size + 4)
    start_y = cy - total_h // 2
    for i, line in enumerate(lines):
        bbox = draw.textbbox((0, 0), line, font=font)
        tw = bbox[2] - bbox[0]
        draw.text((cx - tw // 2, start_y + i * (font.size + 4)), line, fill=text_color, font=font)

def draw_circle(draw, center, r, fill_color=(15, 23, 42), border_color=(15, 23, 42)):
    cx, cy = center
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill_color, outline=border_color)

def draw_bullseye(draw, center, r, fill_color=(15, 23, 42), border_color=(15, 23, 42)):
    cx, cy = center
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=None, outline=border_color, width=2)
    r2 = r - 4
    draw.ellipse([cx - r2, cy - r2, cx + r2, cy + r2], fill=fill_color, outline=border_color)

def generate_swimlane_bg(draw, title, lanes, width, height, header_h=60, title_h=50, font_title=None, font_lane=None):
    # Fill background
    draw.rectangle([0, 0, width, height], fill=(255, 255, 255))
    
    # Title bar
    draw.rectangle([0, 0, width, title_h], fill=(30, 41, 59))
    bbox = draw.textbbox((0, 0), title, font=font_title)
    tw = bbox[2] - bbox[0]
    draw.text((width // 2 - tw // 2, title_h // 2 - (bbox[3] - bbox[1]) // 2 - 2), title, fill=(255, 255, 255), font=font_title)
    
    # Lanes
    n_lanes = len(lanes)
    lane_w = width // n_lanes
    
    for i, lane in enumerate(lanes):
        lx1 = i * lane_w
        lx2 = lx1 + lane_w
        # Header box
        draw.rectangle([lx1, title_h, lx2, title_h + header_h], fill=(241, 245, 249), outline=(226, 232, 240), width=1)
        # Text
        bbox = draw.textbbox((0, 0), lane, font=font_lane)
        tw = bbox[2] - bbox[0]
        draw.text((lx1 + lane_w // 2 - tw // 2, title_h + header_h // 2 - (bbox[3] - bbox[1]) // 2 - 2), lane, fill=(15, 23, 42), font=font_lane)
        
        # Draw lane dividing vertical line
        if i > 0:
            draw.line([lx1, title_h, lx1, height], fill=(203, 213, 225), width=2)
            
    # Bottom border
    draw.line([0, height - 1, width, height - 1], fill=(203, 213, 225), width=1)
    draw.line([0, title_h + header_h, width, title_h + header_h], fill=(203, 213, 225), width=2)

def generate_gambar_1_1():
    print("Generating Gambar 1.1...")
    w, h = 1200, 750
    img = Image.new("RGB", (w, h), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    f_title = get_font("arial.ttf", 20)
    f_lane = get_font("arial.ttf", 16)
    f_text = get_font("arial.ttf", 13)
    
    generate_swimlane_bg(draw, "Gambar 1.1 Alur Administrasi dan Presensi Manual (Sebelum Digitalisasi)", 
                         ["Guru Kelas / Mapel", "Staf BK", "Kepala Sekolah"], w, h, font_title=f_title, font_lane=f_lane)
    
    lane_w = w // 3
    
    # Guru Lane
    cx0 = lane_w // 2
    draw_circle(draw, (cx0, 150), 12)
    draw_arrow(draw, (cx0, 162), (cx0, 200))
    
    draw_rectangle(draw, (cx0 - 150, 200, cx0 + 150, 260), (255, 255, 255), (71, 85, 105), 
                   "Mengisi berkas administrasi cetak\n(Silabus, RPP, Prota, Promes)", f_text)
    draw_arrow(draw, (cx0, 260), (cx0, 300))
    
    draw_rectangle(draw, (cx0 - 150, 300, cx0 + 150, 360), (255, 255, 255), (71, 85, 105), 
                   "Mencatat kehadiran siswa secara fisik\ndi Buku Absensi Kelas", f_text)
    draw_arrow(draw, (cx0, 360), (cx0, 400))
    
    draw_rectangle(draw, (cx0 - 150, 400, cx0 + 150, 460), (255, 255, 255), (71, 85, 105), 
                   "Menulis jurnal harian KBM\npada buku fisik kelas", f_text)
    draw_arrow(draw, (cx0, 460), (cx0, 500))
    
    draw_rectangle(draw, (cx0 - 150, 500, cx0 + 150, 560), (255, 255, 255), (71, 85, 105), 
                   "Menyerahkan rekap absen & berkas\nsecara fisik (Mingguan/Bulanan)", f_text)
    
    # Connector line to Staf BK
    cx1 = lane_w + lane_w // 2
    draw_arrow(draw, (cx0 + 150, 530), (cx1 - 150, 530))
    
    # Staf BK Lane
    draw_rectangle(draw, (cx1 - 150, 500, cx1 + 150, 560), (255, 255, 255), (71, 85, 105), 
                   "Menerima lembar fisik presensi\ndan berkas RPP", f_text)
    draw_arrow(draw, (cx1, 500), (cx1, 420))
    
    draw_rectangle(draw, (cx1 - 150, 360, cx1 + 150, 420), (255, 255, 255), (71, 85, 105), 
                   "Merekap absensi secara manual\nke spreadsheet / buku besar", f_text)
    draw_arrow(draw, (cx1, 360), (cx1, 280))
    
    draw_rectangle(draw, (cx1 - 150, 220, cx1 + 150, 280), (255, 255, 255), (71, 85, 105), 
                   "Menyusun dokumen laporan bulanan\ndan mencetaknya (printout)", f_text)
    
    cx2 = 2 * lane_w + lane_w // 2
    draw_arrow(draw, (cx1 + 150, 250), (cx2 - 150, 250))
    
    # Kepala Sekolah Lane
    draw_rectangle(draw, (cx2 - 150, 220, cx2 + 150, 280), (255, 255, 255), (71, 85, 105), 
                   "Menerima cetakan laporan\ndan menandatanganinya", f_text)
    draw_arrow(draw, (cx2, 280), (cx2, 340))
    
    draw_rectangle(draw, (cx2 - 150, 340, cx2 + 150, 400), (255, 255, 255), (71, 85, 105), 
                   "Melakukan pengawasan kelas\ndengan berkeliling secara fisik", f_text)
    draw_arrow(draw, (cx2, 400), (cx2, 460))
    
    draw_bullseye(draw, (cx2, 472), 12)
    
    img.save("scripts/extracted_images/diagram_manual_process.png")
    print("Saved Gambar 1.1")

def generate_gambar_2_1():
    print("Generating Gambar 2.1...")
    w, h = 1100, 700
    img = Image.new("RGB", (w, h), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    f_title = get_font("arial.ttf", 22)
    f_header = get_font("arial.ttf", 16)
    f_text = get_font("arial.ttf", 13)
    
    # Title
    draw.rectangle([0, 0, w, 50], fill=(30, 41, 59))
    bbox = draw.textbbox((0, 0), "Gambar 2.1 Gambaran Umum Fungsional Produk SinarBelajar", font=f_title)
    draw.text((w // 2 - (bbox[2] - bbox[0]) // 2, 25 - (bbox[3] - bbox[1]) // 2 - 2), 
              "Gambar 2.1 Gambaran Umum Fungsional Produk SinarBelajar", fill=(255, 255, 255), font=f_title)
    
    # Left column background: User Roles
    draw.rounded_rectangle((30, 90, 230, 660), radius=10, fill=(248, 250, 252), outline=(226, 232, 240), width=2)
    draw.text((55, 105), "Aktor Pengguna", fill=(30, 41, 59), font=f_header)
    
    roles = [
        ("Kepala Sekolah", 120, 210),
        ("Guru", 250, 340),
        ("BK", 380, 470),
        ("Siswa", 510, 600)
    ]
    for r, y1, y2 in roles:
        draw_rectangle(draw, (45, y1, 215, y2), (255, 255, 255), (148, 163, 184), r, f_header)
        
    # Center column: SinarBelajar app container
    draw.rounded_rectangle((300, 90, 800, 660), radius=12, fill=(240, 249, 255), outline=(186, 230, 253), width=2)
    draw.text((440, 105), "Aplikasi Mobile SinarBelajar (Flutter)", fill=(3, 105, 161), font=f_header)
    
    modules = [
        ("Modul Kepala Sekolah\n- Monitoring KBM Kelas (Jurnal & Absensi)\n- Verifikasi Dokumen Administrasi Guru\n- Manajemen (Akun Guru, Mapel, Tahun Ajaran)", 120, 210),
        ("Modul Guru\n- Pencatatan Jurnal Pembelajaran & Presensi Siswa\n- Pengelolaan Tugas & Nilai Akademik\n- Unggah Dokumen Administrasi (RPP/Silabus)", 250, 340),
        ("Modul BK\n- Manajemen Siswa (Akun, Mutasi, Histori)\n- Pengaturan Kelas & Kenaikan Kelas\n- Monitoring Siswa", 380, 470),
        ("Modul Siswa\n- Informasi Jadwal Pelajaran & Tugas\n- Histori Presensi Kehadiran Siswa\n- Informasi Nilai & Rapor Hasil Belajar", 510, 600)
    ]
    
    for text, y1, y2 in modules:
        draw_rectangle(draw, (320, y1, 780, y2), (255, 255, 255), (56, 189, 248), text, f_text)
        
    # Right column: Cloud DB (Supabase)
    draw.rounded_rectangle((860, 90, 1070, 660), radius=10, fill=(240, 253, 244), outline=(187, 247, 208), width=2)
    draw.text((895, 105), "Supabase Cloud", fill=(21, 128, 61), font=f_header)
    
    draw_rectangle(draw, (880, 180, 1050, 570), (255, 255, 255), (34, 197, 94), 
                   "Penyimpanan Data\n& Berkas Terpusat\n\n- PostgreSQL DB\n  (Absensi, Jurnal,\n   Nilai, Kelas, Jadwal)\n- Supabase Storage\n  (Silabus, Prota,\n   Promes, RPP)\n- Supabase Auth\n  (Autentikasi & RLS)", f_text)
                   
    # Draw Arrows
    # 1. From User Roles to SinarBelajar Modules (Direct mapping)
    for r, y1, y2 in roles:
        y_center = (y1 + y2) // 2
        draw_arrow(draw, (215, y_center), (320, y_center), color=(71, 85, 105), width=2)
        
    # 2. From SinarBelajar Modules to Supabase Cloud via a common bus for clean layout
    # Horizontal line from right of each module to x=825
    for text, y1, y2 in modules:
        y_center = (y1 + y2) // 2
        draw.line([(780, y_center), (825, y_center)], fill=(71, 85, 105), width=2)
        
    # Vertical backbone at x=825
    draw.line([(825, 165), (825, 555)], fill=(71, 85, 105), width=2)
    
    # Single arrow from backbone to Supabase block
    draw_arrow(draw, (825, 375), (880, 375), color=(34, 197, 94), width=3)
    
    img.save("scripts/extracted_images/diagram_sinarbelajar_overview.png")
    print("Saved Gambar 2.1")

def generate_gambar_3_3():
    print("Generating Gambar 3.3...")
    w, h = 1200, 900
    img = Image.new("RGB", (w, h), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    f_title = get_font("arial.ttf", 20)
    f_lane = get_font("arial.ttf", 16)
    f_text = get_font("arial.ttf", 13)
    
    generate_swimlane_bg(draw, "Gambar 3.3 Activity Diagram Autentikasi dan Pemilihan Peran (Login)", 
                         ["Pengguna / Client", "Sistem Aplikasi (Flutter)", "Supabase Backend"], w, h, font_title=f_title, font_lane=f_lane)
    
    lane_w = w // 3
    
    # Pengguna
    cx0 = lane_w // 2
    draw_circle(draw, (cx0, 150), 12)
    draw_arrow(draw, (cx0, 162), (cx0, 200))
    
    draw_rectangle(draw, (cx0 - 130, 200, cx0 + 130, 260), (255, 255, 255), (71, 85, 105), 
                   "Membuka aplikasi\ndan memasukkan kredensial", f_text)
    
    # Systems
    cx1 = lane_w + lane_w // 2
    draw_arrow(draw, (cx0, 260), (cx1, 260))
    draw_arrow(draw, (cx1, 260), (cx1, 300))
    
    draw_rectangle(draw, (cx1 - 130, 300, cx1 + 130, 360), (255, 255, 255), (71, 85, 105), 
                   "Mengirim email & password\nke Supabase API", f_text)
    
    cx2 = 2 * lane_w + lane_w // 2
    draw_arrow(draw, (cx1, 360), (cx2, 360))
    draw_arrow(draw, (cx2, 360), (cx2, 400))
    
    # Supabase
    draw_rectangle(draw, (cx2 - 130, 400, cx2 + 130, 460), (255, 255, 255), (71, 85, 105), 
                   "Memvalidasi kredensial\ndan data user_roles", f_text)
    draw_arrow(draw, (cx2, 460), (cx2, 500))
    
    draw_diamond(draw, (cx2 - 50, 500, cx2 + 50, 580), (255, 255, 255), (71, 85, 105), "Valid?", f_text)
    
    # Case: Invalid
    draw_arrow(draw, (cx2 - 50, 540), (cx1, 540))
    draw_arrow(draw, (cx1, 540), (cx1, 480))
    draw_rectangle(draw, (cx1 - 130, 420, cx1 + 130, 480), (255, 255, 255), (71, 85, 105), 
                   "Menampilkan pesan error\n'Invalid credentials'", f_text)
    draw_arrow(draw, (cx1 - 130, 450), (50, 450))
    draw.line([(50, 450), (50, 230)], fill=(71, 85, 105), width=2)
    draw_arrow(draw, (50, 230), (cx0 - 130, 230)) # loop back to input (left side)
    
    # Case: Valid
    draw_arrow(draw, (cx2, 580), (cx2, 640))
    draw_rectangle(draw, (cx2 - 130, 640, cx2 + 130, 700), (255, 255, 255), (71, 85, 105), 
                   "Mengembalikan sesi aktif\ndan daftar peran user", f_text)
    
    draw_arrow(draw, (cx2 - 130, 670), (cx1 + 130, 670))
    
    # Systems load roles
    draw_rectangle(draw, (cx1 - 130, 640, cx1 + 130, 700), (255, 255, 255), (71, 85, 105), 
                   "Memeriksa jumlah peran\nyang dimiliki user", f_text)
    draw_arrow(draw, (cx1, 700), (cx1, 750))
    
    draw_diamond(draw, (cx1 - 50, 750, cx1 + 50, 830), (255, 255, 255), (71, 85, 105), "Multi-role?", f_text)
    
    # Case: Yes (multi-role)
    draw_arrow(draw, (cx1 - 50, 790), (cx0, 790))
    draw_arrow(draw, (cx0, 790), (cx0, 730))
    draw_rectangle(draw, (cx0 - 130, 670, cx0 + 130, 730), (255, 255, 255), (71, 85, 105), 
                   "Memilih peran aktif di layar\npemilihan role", f_text)
    draw_arrow(draw, (cx0, 670), (cx0, 600))
    
    # Case: No (single role)
    draw_arrow(draw, (cx1, 830), (cx1, 860))
    draw.line([(cx1, 860), (cx0 + 150, 860)], fill=(71, 85, 105), width=2)
    draw.line([(cx0 + 150, 860), (cx0 + 150, 570)], fill=(71, 85, 105), width=2)
    draw_arrow(draw, (cx0 + 150, 570), (cx0 + 130, 570)) # enters right side of dashboard node
    
    draw_rectangle(draw, (cx0 - 130, 540, cx0 + 130, 600), (255, 255, 255), (71, 85, 105), 
                   "Mengakses Dashboard Utama\nsesuai dengan peran", f_text)
    draw_arrow(draw, (cx0, 540), (cx0, 500))
    
    draw_bullseye(draw, (cx0, 488), 12)
    
    img.save("scripts/extracted_images/diagram_activity_login.png")
    print("Saved Gambar 3.3")

def generate_gambar_3_4():
    print("Generating Gambar 3.4...")
    w, h = 1200, 900
    img = Image.new("RGB", (w, h), (255, 255, 255))
    draw = ImageDraw.Draw(img)
    
    f_title = get_font("arial.ttf", 20)
    f_lane = get_font("arial.ttf", 16)
    f_text = get_font("arial.ttf", 13)
    
    generate_swimlane_bg(draw, "Gambar 3.4 Activity Diagram Input Jurnal Pembelajaran dan Presensi Siswa", 
                         ["Guru (Client)", "Sistem Aplikasi (Flutter)", "Supabase Backend"], w, h, font_title=f_title, font_lane=f_lane)
    
    lane_w = w // 3
    
    # Guru
    cx0 = lane_w // 2
    draw_circle(draw, (cx0, 150), 12)
    draw_arrow(draw, (cx0, 162), (cx0, 200))
    
    draw_rectangle(draw, (cx0 - 130, 200, cx0 + 130, 260), (255, 255, 255), (71, 85, 105), 
                   "Memilih menu pengisian jurnal\ndan presensi siswa", f_text)
    
    # System loads list
    cx1 = lane_w + lane_w // 2
    draw_arrow(draw, (cx0, 260), (cx1, 260))
    draw_arrow(draw, (cx1, 260), (cx1, 300))
    
    draw_rectangle(draw, (cx1 - 130, 300, cx1 + 130, 360), (255, 255, 255), (71, 85, 105), 
                   "Mengambil jadwal mengajar guru\ndan daftar siswa kelas terkait", f_text)
    
    cx2 = 2 * lane_w + lane_w // 2
    draw_arrow(draw, (cx1, 360), (cx2, 360))
    draw_arrow(draw, (cx2, 360), (cx2, 400))
    
    # Backend
    draw_rectangle(draw, (cx2 - 130, 400, cx2 + 130, 460), (255, 255, 255), (71, 85, 105), 
                   "Mencari & mengirim data kelas,\nsiswa, dan mapel dari database", f_text)
    
    draw_arrow(draw, (cx2 - 130, 430), (cx1 + 130, 430))
    draw_arrow(draw, (cx1, 460), (cx0, 460))
    draw_arrow(draw, (cx0, 460), (cx0, 500))
    
    # Guru fills data
    draw_rectangle(draw, (cx0 - 130, 500, cx0 + 130, 560), (255, 255, 255), (71, 85, 105), 
                   "Memilih materi & jam pelajaran,\nserta mencentang kehadiran siswa", f_text)
    draw_arrow(draw, (cx0, 560), (cx0, 600))
    
    draw_rectangle(draw, (cx0 - 130, 600, cx0 + 130, 660), (255, 255, 255), (71, 85, 105), 
                   "Menekan tombol simpan jurnal", f_text)
    
    draw_arrow(draw, (cx0, 660), (cx1, 660))
    draw_arrow(draw, (cx1, 660), (cx1, 700))
    
    # System validate
    draw_rectangle(draw, (cx1 - 130, 700, cx1 + 130, 760), (255, 255, 255), (71, 85, 105), 
                   "Memvalidasi isian materi\ndan status presensi siswa", f_text)
    draw_arrow(draw, (cx1, 760), (cx1, 790))
    
    draw_diamond(draw, (cx1 - 50, 790, cx1 + 50, 870), (255, 255, 255), (71, 85, 105), "Lengkap?", f_text)
    
    # Case: No
    draw_arrow(draw, (cx1 - 50, 830), (cx0, 830))
    draw_arrow(draw, (cx0, 830), (cx0, 720))
    draw_rectangle(draw, (cx0 - 130, 660, cx0 + 130, 720), (255, 255, 255), (71, 85, 105), 
                   "Menampilkan pesan peringatan\n'Mohon isi materi & data presensi!'", f_text)
    draw_arrow(draw, (cx0, 660), (40, 660))
    draw.line([(40, 660), (40, 530)], fill=(71, 85, 105), width=2)
    draw_arrow(draw, (40, 530), (cx0 - 130, 530)) # loop back to input (left side)
    
    # Case: Yes
    draw_arrow(draw, (cx1 + 50, 830), (cx2, 830))
    draw_arrow(draw, (cx2, 830), (cx2, 760))
    
    # Symmetric box width (cx2 + 130)
    draw_rectangle(draw, (cx2 - 130, 700, cx2 + 130, 760), (255, 255, 255), (71, 85, 105), 
                   "Menyimpan data transaksi ke tabel\n'jurnal' dan 'absensi_jurnal'", f_text)
    draw_arrow(draw, (cx2, 700), (cx2, 640))
    
    draw_rectangle(draw, (cx2 - 130, 580, cx2 + 130, 640), (255, 255, 255), (71, 85, 105), 
                   "Mengembalikan status sukses kueri", f_text)
    
    # Continuous flow lines from backend directly to Notification Node at bottom of lane 0
    draw_arrow(draw, (cx2 - 130, 610), (cx0, 610))
    draw_arrow(draw, (cx0, 610), (cx0, 760))
    
    # Notification Node moved down to y=760..820 to avoid overlaps
    draw_rectangle(draw, (cx0 - 130, 760, cx0 + 130, 820), (255, 255, 255), (71, 85, 105), 
                   "Menampilkan dialog notifikasi\n'Data jurnal berhasil disimpan'", f_text)
    draw_arrow(draw, (cx0, 820), (cx0, 848))
    
    # Final node placed at the bottom y=860
    draw_bullseye(draw, (cx0, 860), 12)
    
    img.save("scripts/extracted_images/diagram_activity_jurnal.png")
    print("Saved Gambar 3.4")

def stitch_erd_diagrams():
    print("Stitching ERD diagrams...")
    # Load modular ERD images from KMM
    img_pengguna_path = "scripts/extracted_images/image9.png"
    img_jadwal_jurnal_path = "scripts/extracted_images/image10.png"
    img_penilaian_path = "scripts/extracted_images/image11.png"
    img_administrasi_path = "scripts/extracted_images/image12.png"
    
    if not (os.path.exists(img_pengguna_path) and os.path.exists(img_jadwal_jurnal_path) and 
            os.path.exists(img_penilaian_path) and os.path.exists(img_administrasi_path)):
        print("Error: One of the modular ERD images is missing in scripts/extracted_images")
        return
        
    img_pengguna = Image.open(img_pengguna_path)
    img_jadwal_jurnal = Image.open(img_jadwal_jurnal_path)
    img_penilaian = Image.open(img_penilaian_path)
    img_administrasi = Image.open(img_administrasi_path)
    
    # We want a 2x2 grid. Let's make all sub-images a standard height/width or just stitch them keeping spacing.
    # To keep the quality, let's resize them so they fit in a neat layout.
    # Standard size: 1000 x 1000 for each cell.
    cell_w, cell_h = 1000, 1000
    
    def fit_image(img, w, h):
        img_fit = img.copy()
        img_fit.thumbnail((w - 40, h - 40), Image.Resampling.LANCZOS)
        # Create a new white cell
        cell = Image.new("RGB", (w, h), (255, 255, 255))
        # Paste centered
        x = (w - img_fit.width) // 2
        y = (h - img_fit.height) // 2
        cell.paste(img_fit, (x, y))
        return cell
        
    cell_pengguna = fit_image(img_pengguna, cell_w, cell_h)
    cell_jadwal = fit_image(img_jadwal_jurnal, cell_w, cell_h)
    cell_penilaian = fit_image(img_penilaian, cell_w, cell_h)
    cell_admin = fit_image(img_administrasi, cell_w, cell_h)
    
    # Create combined image
    # We will leave a header for the stitched diagram
    header_h = 80
    combined_w = 2 * cell_w + 30
    combined_h = 2 * cell_h + header_h + 30
    
    combined = Image.new("RGB", (combined_w, combined_h), (255, 255, 255))
    draw = ImageDraw.Draw(combined)
    
    # Header bar
    draw.rectangle([0, 0, combined_w, header_h], fill=(30, 41, 59))
    f_title = get_font("arial.ttf", 24)
    bbox = draw.textbbox((0, 0), "Gambar 3.5 Entity Relationship Diagram (ERD) Modular SinarBelajar", font=f_title)
    draw.text((combined_w // 2 - (bbox[2] - bbox[0]) // 2, header_h // 2 - (bbox[3] - bbox[1]) // 2 - 2), 
              "Gambar 3.5 Entity Relationship Diagram (ERD) Modular SinarBelajar", fill=(255, 255, 255), font=f_title)
              
    # Paste cells
    # Row 1
    combined.paste(cell_pengguna, (10, header_h + 10))
    combined.paste(cell_jadwal, (cell_w + 20, header_h + 10))
    # Row 2
    combined.paste(cell_penilaian, (10, header_h + cell_h + 20))
    combined.paste(cell_admin, (cell_w + 20, header_h + cell_h + 20))
    
    # Draw dividers and borders
    draw.line([cell_w + 15, header_h, cell_w + 15, combined_h], fill=(203, 213, 225), width=4)
    draw.line([0, header_h + cell_h + 15, combined_w, header_h + cell_h + 15], fill=(203, 213, 225), width=4)
    
    # Add labels on the corners
    f_label = get_font("arial.ttf", 18)
    draw.text((30, header_h + 20), "MODUL PENGGUNA", fill=(15, 23, 42), font=f_label)
    draw.text((cell_w + 40, header_h + 20), "MODUL JADWAL DAN JURNAL", fill=(15, 23, 42), font=f_label)
    draw.text((30, header_h + cell_h + 30), "MODUL PENILAIAN", fill=(15, 23, 42), font=f_label)
    draw.text((cell_w + 40, header_h + cell_h + 30), "MODUL ADMINISTRASI PEMBELAJARAN", fill=(15, 23, 42), font=f_label)
    
    combined.save("scripts/extracted_images/diagram_erd_combined.png")
    print("Saved Gambar 3.5 combined ERD")

if __name__ == "__main__":
    os.makedirs("scripts/extracted_images", exist_ok=True)
    generate_gambar_1_1()
    generate_gambar_2_1()
    generate_gambar_3_3()
    generate_gambar_3_4()
    stitch_erd_diagrams()
    print("All diagrams generated successfully!")
