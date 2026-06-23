import zipfile
from xml.etree import ElementTree

def inspect_docx(docx_file, output_f):
    output_f.write(f"\n=========================================\n")
    output_f.write(f"=== Inspecting {docx_file} ===\n")
    output_f.write(f"=========================================\n")
    try:
        with zipfile.ZipFile(docx_file, 'r') as z:
            rels_xml = z.read('word/_rels/document.xml.rels')
            doc_xml = z.read('word/document.xml')
    except Exception as e:
        output_f.write(f"Error reading docx: {e}\n")
        return

    # Parse relationships
    root_rels = ElementTree.fromstring(rels_xml)
    rels = {}
    for rel in root_rels:
        rId = rel.get('Id')
        target = rel.get('Target')
        rels[rId] = target

    # OxML namespaces
    ns = {
        'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
        'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
        'pic': 'http://schemas.openxmlformats.org/drawingml/2006/picture',
        'wp': 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'
    }

    root_doc = ElementTree.fromstring(doc_xml)

    # Find all paragraph elements
    paragraphs = root_doc.findall('.//w:p', ns)
    output_f.write(f"Parsed {len(paragraphs)} paragraphs from XML.\n")

    for idx, p in enumerate(paragraphs):
        p_text = ''.join(t.text for t in p.findall('.//w:t', ns) if t.text)
        
        embed_elements = p.findall('.//*[@{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed]', ns)
        link_elements = p.findall('.//*[@{http://schemas.openxmlformats.org/officeDocument/2006/relationships}link]', ns)
        all_embeds = embed_elements + link_elements
        
        # If it contains text or images
        if all_embeds or p_text.strip():
            output_f.write(f"\n[Paragraph {idx}] Text: '{p_text}'\n")
            if all_embeds:
                for elem in all_embeds:
                    embed_id = elem.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed') or elem.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}link')
                    if embed_id in rels:
                        output_f.write(f"  -> IMAGE: {embed_id} -> {rels[embed_id]}\n")
                    else:
                        output_f.write(f"  -> Unknown embed ID: {embed_id}\n")

if __name__ == "__main__":
    with open("scripts/inspect_results.txt", "w", encoding="utf-8") as f:
        inspect_docx("Sulthan_Syahrul_Laporan_KMM_Revisi (1).docx", f)
        inspect_docx("Naskah_TA_SinarBelajar_SMPN1Jenar_v3_cited.docx", f)
    print("Done inspecting. Saved to scripts/inspect_results.txt")

