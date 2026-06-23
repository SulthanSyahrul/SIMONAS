import zipfile
from xml.etree import ElementTree

pptx_file = '../Presentasi_Laporan_KMM_Sulthan last.pptx'
with zipfile.ZipFile(pptx_file, 'r') as z:
    for i in range(1, 14):
        slide_name = f'ppt/slides/slide{i}.xml'
        rels_name = f'ppt/slides/_rels/slide{i}.xml.rels'
        try:
            slide_xml = z.read(slide_name)
            root_slide = ElementTree.fromstring(slide_xml)
            texts = [t.text for t in root_slide.findall('.//{http://schemas.openxmlformats.org/drawingml/2006/main}t') if t.text]
            print(f"Slide {i} Text: {' | '.join(texts[:3])}")
            
            # Read slide relationships to find media files
            rels_xml = z.read(rels_name)
            root_rels = ElementTree.fromstring(rels_xml)
            rels = {r.get('Id'): r.get('Target') for r in root_rels}
            
            # Find image embeds
            embeds = root_slide.findall('.//*[@{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed]')
            for e in embeds:
                emb_id = e.get('{http://schemas.openxmlformats.org/officeDocument/2006/relationships}embed')
                if emb_id in rels:
                    print(f"  -> IMAGE: {emb_id} -> {rels[emb_id]}")
        except KeyError:
            pass
        except Exception as e:
            print(f"Error slide {i}: {e}")
