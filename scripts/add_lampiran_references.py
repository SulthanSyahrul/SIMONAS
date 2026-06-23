import docx

def main():
    filename = 'Naskah TA Sulthan Syahrul BAB I-IV.docx'
    print(f"Loading {filename}...")
    doc = docx.Document(filename)
    
    modified_120 = False
    modified_208 = False
    
    for idx, p in enumerate(doc.paragraphs):
        p_text = p.text
        # Identify Paragraph 120 (stages of development)
        if "Pada tahap pengumpulan kebutuhan, data diperoleh" in p_text and "black-box" in p_text:
            if "Lampiran A" not in p_text:
                target_str = "kesesuaian fungsi terhadap kebutuhan."
                new_str = (
                    "kesesuaian fungsi terhadap kebutuhan. "
                    "Selain itu, rancangan diagram BPMN proses bisnis sistem diuraikan pada Lampiran A, "
                    "sedangkan alur flowchart proses autentikasi pengguna disajikan pada Lampiran C."
                )
                p.text = p_text.replace(target_str, new_str)
                # Re-apply Times New Roman 12pt format
                p.paragraph_format.line_spacing = 1.5
                p.paragraph_format.space_after = docx.shared.Pt(6)
                for run in p.runs:
                    run.font.name = "Times New Roman"
                    run.font.size = docx.shared.Pt(12)
                modified_120 = True
                print(f"Added Lampiran A & C references to paragraph {idx}.")
                
        # Identify Paragraph 208 (desain keamanan RLS)
        if "Keamanan data dirancang pada level database" in p_text and "Row-Level Security" in p_text:
            if "Lampiran D" not in p_text:
                target_str = "maupun DELETE."
                new_str = (
                    "maupun DELETE. Detail skrip SQL untuk kebijakan Row Level Security (RLS) "
                    "dan trigger database Supabase yang diimplementasikan disajikan pada Lampiran D."
                )
                p.text = p_text.replace(target_str, new_str)
                p.paragraph_format.line_spacing = 1.5
                p.paragraph_format.space_after = docx.shared.Pt(6)
                for run in p.runs:
                    run.font.name = "Times New Roman"
                    run.font.size = docx.shared.Pt(12)
                modified_208 = True
                print(f"Added Lampiran D reference to paragraph {idx}.")
                
    if modified_120 or modified_208:
        print(f"Saving changes to {filename}...")
        doc.save(filename)
        print("Document saved successfully!")
    else:
        print("References are already present or paragraphs were not found.")

if __name__ == '__main__':
    main()
