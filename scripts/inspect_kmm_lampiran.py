import docx

def main():
    doc = docx.Document('Sulthan_Syahrul_Laporan_KMM_Revisi (1).docx')
    print("=== Paragraphs under LAMPIRAN in KMM ===")
    for idx, p in enumerate(doc.paragraphs):
        if idx >= 460:
            drawings = p._element.xpath('.//w:drawing')
            picts = p._element.xpath('.//w:pict')
            images_count = len(drawings) + len(picts)
            print(f'{idx}: "{p.text}" (images={images_count})')

if __name__ == '__main__':
    main()
