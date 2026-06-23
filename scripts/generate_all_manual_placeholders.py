import os
from PIL import Image, ImageDraw

def make_placeholder(filename, title, subtitle):
    w, h = 360, 640
    img = Image.new('RGB', (w, h), color='#F4F5F7')
    draw = ImageDraw.Draw(img)
    
    # Draw device outer border
    draw.rectangle([(0, 0), (w - 1, h - 1)], outline='#A0AEC0', width=4)
    
    # Draw a simulated mobile status bar
    draw.rectangle([(0, 0), (w - 1, 28)], fill='#E2E8F0')
    draw.text((12, 8), "SIMONAS APP", fill='#4A5568')
    
    # Draw Title and Subtitle
    draw.text((24, 60), "[ SCREENSHOT PLACEHOLDER ]", fill='#2D3748')
    draw.text((24, 95), "Target Halaman:", fill='#4A5568')
    draw.text((24, 115), title, fill='#1A202C')
    draw.text((24, 145), "Keterangan Langkah:", fill='#4A5568')
    draw.text((24, 165), subtitle, fill='#2D3748')
    
    # Draw status info
    draw.text((24, 215), "* Status: Menggunakan Placeholder", fill='#E53E3E')
    draw.text((24, 235), "* Catatan: Akan diganti screenshot", fill='#718096')
    draw.text((32, 255), "aktual dengan kotak merah", fill='#718096')
    
    # Draw simulated red box ("kotak merah") to illustrate the guide focus
    draw.rectangle([(24, 300), (w - 24, 480)], outline='#E53E3E', width=3)
    draw.text((35, 310), "[ AREA FOKUS PANDUAN ]", fill='#E53E3E')
    draw.text((35, 340), "Simulasi highlight fitur", fill='#E53E3E')
    draw.text((35, 360), "dengan kotak merah", fill='#E53E3E')
    
    # Draw a mock button inside
    draw.rectangle([(100, 410), (w - 100, 450)], fill='#E53E3E')
    draw.text((120, 422), "Tombol Sorotan", fill='#FFFFFF')
    
    # Bottom home indicator bar
    draw.rectangle([(w // 2 - 40, h - 12), (w // 2 + 40, h - 8)], fill='#A0AEC0', width=2)
    
    # Save image
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    img.save(filename)
    print(f"Generated: {filename}")

def main():
    placeholders = {
        # Login and Roles
        "scripts/placeholders/placeholder_login.png": ("Halaman Login", "Form login email & password"),
        "scripts/placeholders/placeholder_role_selection.png": ("Seleksi Peran", "Pilihan Multi-role pengguna"),
        
        # Kepala Sekolah
        "scripts/placeholders/placeholder_dashboard_kepsek.png": ("Dashboard Kepala Sekolah", "Rangkuman status KBM harian"),
        "scripts/placeholders/placeholder_monitoring_kelas.png": ("Monitoring Kelas", "Pemantauan kelas real-time"),
        "scripts/placeholders/placeholder_monitoring_jurnal.png": ("Monitoring Jurnal", "Melihat riwayat jurnal mengajar guru"),
        "scripts/placeholders/placeholder_verifikasi_administrasi.png": ("Verifikasi Administrasi", "Persetujuan berkas RPP guru"),
        
        # Guru
        "scripts/placeholders/placeholder_jadwal_mengajar.png": ("Jadwal Mengajar", "Daftar jadwal mengajar aktif"),
        "scripts/placeholders/placeholder_jurnal_absensi.png": ("Jurnal & Absensi", "Pengisian KBM & presensi kelas"),
        "scripts/placeholders/placeholder_kelola_nilai.png": ("Kelola Nilai", "Form input nilai tugas & ujian"),
        "scripts/placeholders/placeholder_kelola_tugas.png": ("Kelola Tugas", "Form publikasi tugas baru"),
        "scripts/placeholders/placeholder_administrasi.png": ("Administrasi Pembelajaran", "Unggah berkas perangkat ajar"),
        
        # BK
        "scripts/placeholders/placeholder_kelola_siswa.png": ("Kelola Siswa", "Form tambah/edit data siswa"),
        "scripts/placeholders/placeholder_pengaturan_kelas.png": ("Pengaturan Kelas", "Pemetaan kelas siswa aktif"),
        "scripts/placeholders/placeholder_kenaikan_kelas.png": ("Kenaikan Kelas", "Form proses kenaikan kelas periodik"),
        "scripts/placeholders/placeholder_catatan_pembinaan.png": ("Catatan Pembinaan", "Pencatatan konseling siswa"),
        
        # Siswa
        "scripts/placeholders/placeholder_jadwal_pelajaran.png": ("Jadwal Pelajaran", "Jadwal pelajaran mingguan"),
        "scripts/placeholders/placeholder_nilai_siswa.png": ("Nilai Siswa", "Tampilan nilai tugas & ujian"),
        "scripts/placeholders/placeholder_tugas_kelas.png": ("Tugas Kelas", "Daftar & pengumpulan tugas"),
        "scripts/placeholders/placeholder_histori_kelas.png": ("Histori Kelas", "Riwayat kelas siswa di masa lalu")
    }
    
    for filename, (title, subtitle) in placeholders.items():
        make_placeholder(filename, title, subtitle)

if __name__ == '__main__':
    main()
