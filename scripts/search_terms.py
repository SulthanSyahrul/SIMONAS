import docx

def main():
    doc = docx.Document('Naskah TA Sulthan Syahrul BAB I-IV.docx')
    terms = ["kemahasiswaan", "pengujian lapangan", "gambar aktual", "finalisasi", "saran pengujian", "sitasi"]
    print("=== Searching for WIP Terms ===")
    for idx, p in enumerate(doc.paragraphs):
        text_lower = p.text.lower()
        found = [t for t in terms if t in text_lower]
        if found:
            print(f"P {idx} (matches {found}): '{p.text[:140]}'")

if __name__ == '__main__':
    main()
