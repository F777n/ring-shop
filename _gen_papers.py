# -*- coding: utf-8 -*-
"""Generate seven psychology coursework documents."""
from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt

OUT = Path(r"C:\Users\farid\OneDrive\Рабочий стол\Работы Димана")


def set_run_font(run, size=14, bold=False):
    run.bold = bold
    run.font.size = Pt(size)
    run.font.name = "Times New Roman"
    rPr = run._element.get_or_add_rPr()
    rFonts = rPr.get_or_add_rFonts()
    for attr in ("w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"):
        rFonts.set(qn(attr), "Times New Roman")
    lang = rPr.find(qn("w:lang"))
    if lang is None:
        lang = OxmlElement("w:lang")
        rPr.append(lang)
    lang.set(qn("w:val"), "ru-RU")
    lang.set(qn("w:eastAsia"), "ru-RU")


def add_page_number(paragraph):
    run = paragraph.add_run()
    set_run_font(run, 14)

    def fld(kind):
        el = OxmlElement("w:fldChar")
        el.set(qn("w:fldCharType"), kind)
        return el

    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = " PAGE "
    run._r.append(fld("begin"))
    run._r.append(instr)
    run._r.append(fld("end"))


def setup(doc):
    section = doc.sections[0]
    section.page_width = Cm(21.0)
    section.page_height = Cm(29.7)
    section.top_margin = Cm(2)
    section.bottom_margin = Cm(2)
    section.left_margin = Cm(3)
    section.right_margin = Cm(1.5)
    section.different_first_page_header_footer = True
    footer = section.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    add_page_number(footer)
    style = doc.styles["Normal"]
    style.font.name = "Times New Roman"
    style.font.size = Pt(14)
    style.paragraph_format.line_spacing = 1.5
    style.paragraph_format.space_after = Pt(0)
    style.paragraph_format.space_before = Pt(0)
    rPr = style.element.get_or_add_rPr()
    rFonts = rPr.get_or_add_rFonts()
    for attr in ("w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"):
        rFonts.set(qn(attr), "Times New Roman")


def add_p(doc, text, *, center=False, bold=False, indent=True, before=0, after=0):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER if center else WD_ALIGN_PARAGRAPH.JUSTIFY
    pf = p.paragraph_format
    pf.line_spacing = 1.5
    pf.space_before = Pt(before)
    pf.space_after = Pt(after)
    pf.first_line_indent = Cm(0) if center or not indent else Cm(1.25)
    run = p.add_run(text)
    set_run_font(run, 14, bold)
    return p


def add_title_page(doc, kind, title):
    for _ in range(5):
        add_p(doc, "", center=True, indent=False)
    add_p(doc, kind.upper(), center=True, bold=True, indent=False, after=12)
    add_p(doc, "по дисциплинам", center=True, indent=False)
    add_p(doc, "«Психология общения»", center=True, indent=False)
    add_p(doc, "«Основы психологии в профессиональной деятельности»", center=True, indent=False, after=18)
    add_p(doc, "Тема:", center=True, bold=True, indent=False, before=18)
    add_p(doc, "«" + title + "»", center=True, bold=True, indent=False)
    doc.add_page_break()


def build(paper):
    doc = Document()
    setup(doc)
    add_title_page(doc, paper["kind"], paper["title"])
    for kind, text in paper["blocks"]:
        if kind == "h":
            add_p(doc, text, center=True, bold=True, indent=False, before=12, after=6)
        elif kind == "r":
            p = add_p(doc, text, indent=False, before=2, after=2)
            p.paragraph_format.left_indent = Cm(1.25)
            p.paragraph_format.first_line_indent = Cm(-1.25)
        else:
            add_p(doc, text)
    path = OUT / paper["filename"]
    doc.save(path)
    chars = sum(len(text) for kind, text in paper["blocks"] if kind == "p")
    print(f"{paper['filename']}: body_chars={chars}")
    return path


def h(text):
    return ("h", text)


def p(text):
    return ("p", text)


def r(text):
    return ("r", text)
