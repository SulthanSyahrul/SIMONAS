import docx

def main():
    filename = 'Naskah TA Sulthan Syahrul BAB I-IV.docx'
    print(f"Loading {filename}...")
    doc = docx.Document(filename)
    
    modified_count = 0
    # We look at paragraphs 0 to 339 (main text before LAMPIRAN heading)
    for idx in range(340):
        p = doc.paragraphs[idx]
        text = p.text
        original_text = text
        
        # 1. Paragraph 120 (Remove BPMN and Flowchart references entirely)
        if "BPMN proses bisnis" in text and "flowchart proses autentikasi" in text:
            # We want to remove the sentence:
            # "Selain itu, rancangan diagram BPMN proses bisnis sistem diuraikan pada Lampiran A, sedangkan alur flowchart proses autentikasi pengguna disajikan pada Lampiran B."
            sentence_to_remove = " Selain itu, rancangan diagram BPMN proses bisnis sistem diuraikan pada Lampiran A, sedangkan alur flowchart proses autentikasi pengguna disajikan pada Lampiran B."
            text = text.replace(sentence_to_remove, "")
            # If the spacing differs, let's try direct replace without space as well
            sentence_to_remove_alt = "Selain itu, rancangan diagram BPMN proses bisnis sistem diuraikan pada Lampiran A, sedangkan alur flowchart proses autentikasi pengguna disajikan pada Lampiran B."
            text = text.replace(sentence_to_remove_alt, "")
            
        # 2. Paragraph 159 (Manual Penggunaan: was Lampiran C, now Lampiran A)
        if "Manual lengkap ditempatkan pada Lampiran C" in text:
            text = text.replace("Lampiran C", "Lampiran A")
            
        # 3. Paragraph 203 (ERD: was Lampiran D, now Lampiran B)
        if "dapat dilihat pada Lampiran D." in text:
            text = text.replace("Lampiran D", "Lampiran B")
            
        # 4. Paragraph 208 (SQL RLS: was Lampiran E, now Lampiran C)
        if "disajikan pada Lampiran E." in text:
            text = text.replace("Lampiran E", "Lampiran C")
            
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
