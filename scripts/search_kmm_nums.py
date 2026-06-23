import docx
import os

filename = 'Sulthan_Syahrul_Laporan_KMM_Revisi (1).docx'
if os.path.exists(filename):
    doc = docx.Document(filename)
    for idx, p in enumerate(doc.paragraphs):
        if '6.3' in p.text or '5.3' in p.text or '6.4' in p.text or '5.4' in p.text:
            print(f"P#{idx}: {p.text}")
else:
    print(f"File {filename} not found.")
