import docx

def main():
    doc = docx.Document('Naskah TA Sulthan Syahrul BAB I-IV.docx')
    terms = ["bpmn", "flowchart", "activity", "sequence", "use case", "manual", "lampiran"]
    for idx, p in enumerate(doc.paragraphs):
        p_text = p.text.lower()
        matched = [t for t in terms if t in p_text]
        if matched:
            print(f"P {idx} (matches {matched}): {p.text}")

if __name__ == '__main__':
    main()
