import zipfile
import os
from xml.etree import ElementTree

def inspect_docx_images(docx_file):
    with zipfile.ZipFile(docx_file, 'r') as z:
        rels_xml = z.read('word/_rels/document.xml.rels')
        doc_xml = z.read('word/document.xml')
        
    root_rels = ElementTree.fromstring(rels_xml)
    rels = {}
    for rel in root_rels:
        rId = rel.get('Id')
        target = rel.get('Target')
        rels[rId] = target

    ns = {
        'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
        'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
        'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
        'pic': 'http://schemas.openxmlformats.org/drawingml/2006/picture',
        'wp': 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'
    }

    root_doc = ElementTree.fromstring(doc_xml)
    paragraphs = root_doc.findall('.//w:p', ns)
    
    print(f"=== Matching images under LAMPIRAN in {docx_file} ===")
    for idx, p in enumerate(paragraphs):
        if idx >= 460:
            p_text = ''.join(t.text for t in p.findall('.//w:t', ns) if t.text).strip()
            embed_elements = p.findall('.//*[@{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed]', ns)
            link_elements = p.findall('.//*[@{http://schemas.openxmlformats.org/officeDocument/2006/relationships}link]', ns)
            all_embeds = embed_elements + link_elements
            
            if p_text or all_embeds:
                print(f"P {idx}: '{p_text}'")
                for elem in all_embeds:
                    embed_id = elem.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed') or elem.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}link')
                    if embed_id in rels:
                        target = rels[embed_id]
                        print(f"  -> IMAGE: {os.path.basename(target)}")

if __name__ == '__main__':
    inspect_docx_images('Sulthan_Syahrul_Laporan_KMM_Revisi (1).docx')
