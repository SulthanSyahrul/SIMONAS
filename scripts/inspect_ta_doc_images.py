import docx

def main():
    doc = docx.Document('Naskah TA Sulthan Syahrul BAB I-IV.docx')
    print("=== Analyzing doc paragraphs for text and inline shapes ===")
    
    # Check paragraph by paragraph
    for idx, p in enumerate(doc.paragraphs):
        # Check if paragraph has text or contains inline shapes
        has_shapes = len(p.runs) > 0 and any(run.element.xpath('.//w:drawing') or run.element.xpath('.//w:pict') for run in p.runs)
        text = p.text.strip()
        if has_shapes or text.startswith("Gambar") or text.startswith("Tabel"):
            print(f"P {idx:03d}: text='{text[:120]}' (has_images={has_shapes})")

if __name__ == '__main__':
    main()
