import docx

def main():
    doc = docx.Document('Naskah TA Sulthan Syahrul BAB I-IV.docx')
    print("=== Searching for BPMN, Flowchart, RLS, Trigger ===")
    for idx, p in enumerate(doc.paragraphs):
        p_text = p.text.lower()
        if "bpmn" in p_text or "flowchart" in p_text or "rls" in p_text or "trigger" in p_text or "keamanan" in p_text:
            print(f"P {idx}: '{p.text[:120]}'")

if __name__ == '__main__':
    main()
