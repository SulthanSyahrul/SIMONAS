import docx

def main():
    doc = docx.Document('Naskah TA Sulthan Syahrul BAB I-IV.docx')
    print("=== Paragraphs under LAMPIRAN ===")
    for idx, p in enumerate(doc.paragraphs):
        if idx >= 346:
            drawings = p._element.xpath('.//w:drawing')
            picts = p._element.xpath('.//w:pict')
            images_count = len(drawings) + len(picts)
            print(f'{idx}: "{p.text}" (images={images_count})')

if __name__ == '__main__':
    main()
