import zipfile
import os

def extract_media(docx_file, output_dir):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    print(f"Extracting media from {docx_file} to {output_dir}...")
    with zipfile.ZipFile(docx_file, 'r') as z:
        for file_info in z.infolist():
            if file_info.filename.startswith('word/media/'):
                base_name = os.path.basename(file_info.filename)
                dest_path = os.path.join(output_dir, base_name)
                print(f"Saving {base_name}...")
                with open(dest_path, 'wb') as f:
                    f.write(z.read(file_info.filename))
    print("Extraction complete.")

if __name__ == '__main__':
    extract_media('Sulthan_Syahrul_Laporan_KMM_Revisi (1).docx', 'scripts/extracted_kmm_media')
