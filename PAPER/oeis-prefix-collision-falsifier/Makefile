# Compile main.pdf with bibtex (3-pass cross-ref resolution).
# `make`           — produce main.pdf
# `make clean`     — remove intermediates (PDF preserved)
# `make distclean` — also remove the PDF
#
# The single figure (figures/fig01_funnel.png) is generated out-of-band via
# the `/imagine` skill (fal.ai gpt-image-2) and committed; no figure build
# step is required here.

DOC = main
LATEX = pdflatex -interaction=nonstopmode -halt-on-error
BIBTEX = bibtex

.PHONY: all clean distclean

all: $(DOC).pdf

$(DOC).pdf: $(DOC).tex references.bib figures/fig01_funnel.png
	$(LATEX) $(DOC).tex
	$(BIBTEX) $(DOC) || true
	$(LATEX) $(DOC).tex
	$(LATEX) $(DOC).tex
	@echo "[paper] $(DOC).pdf built at $$(date '+%Y-%m-%d %H:%M:%S')"

clean:
	rm -f $(DOC).aux $(DOC).bbl $(DOC).blg $(DOC).log $(DOC).out \
	      $(DOC).toc $(DOC).synctex.gz
	@echo "[paper] intermediates cleaned (PDF preserved)"

distclean: clean
	rm -f $(DOC).pdf
