import docx

def main():
    filename = 'Naskah TA Sulthan Syahrul BAB I-IV.docx'
    print(f"Loading {filename}...")
    doc = docx.Document(filename)
    
    modified_count = 0
    # We will look at paragraphs 0 to 339 (main text before LAMPIRAN heading)
    for idx in range(340):
        p = doc.paragraphs[idx]
        text = p.text
        original_text = text
        
        # 1. Paragraph 120 (BPMN & Flowchart)
        if "Lampiran A" in text and "Lampiran C" in text:
            text = text.replace("Lampiran C", "Lampiran B")
            
        # 2. Paragraph 159 (Manual Penggunaan)
        if "Manual lengkap ditempatkan pada Lampiran B" in text:
            text = text.replace("Lampiran B", "Lampiran C")
            
        # 3. Paragraph 203 (ERD)
        if "dapat dilihat pada Lampiran E." in text:
            text = text.replace("Lampiran E", "Lampiran D")
            
        # 4. Paragraph 208 (SQL RLS)
        if "disajikan pada Lampiran D." in text:
            text = text.replace("Lampiran D", "Lampiran E")
            
        if text != original_text:
            p.text = text
            p.paragraph_format.line_spacing = 1.5
            p.paragraph_format.space_after = docx.shared.Pt(6)
            for run in p.runs:
                run.font.name = "Times New Roman"
                run.font.size = docx.shared.Pt(12)
            print(f"Updated P {idx}: '{text[:120]}...'")
            modified_count += 1
            
    if modified_count > 0:
        print(f"Saving changes to {filename}...")
        doc.save(filename)
        print("Document saved successfully!")
    else:
        print("No references needed updates or they were not found.")

if __name__ == '__main__':
    main()
