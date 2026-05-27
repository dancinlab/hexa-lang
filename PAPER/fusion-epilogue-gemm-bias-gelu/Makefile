# Compile main.pdf with bibtex (3-pass cross-ref resolution).
# `make`           — produce main.pdf
# `make figures`   — regenerate figures/*.pdf from figures/_scripts/*.py
# `make clean`     — remove intermediates (PDF preserved)
# `make distclean` — also remove the PDF

DOC = main
LATEX = pdflatex -interaction=nonstopmode -halt-on-error
BIBTEX = bibtex
PYTHON = python3

FIG_SCRIPTS = $(wildcard figures/_scripts/*.py)
FIG_PDFS    = $(patsubst figures/_scripts/%.py,figures/%.pdf,$(FIG_SCRIPTS))

.PHONY: all figures clean distclean

all: $(DOC).pdf

$(DOC).pdf: $(DOC).tex references.bib $(FIG_PDFS)
	$(LATEX) $(DOC).tex
	$(BIBTEX) $(DOC) || true
	$(LATEX) $(DOC).tex
	$(LATEX) $(DOC).tex
	@echo "[paper] $(DOC).pdf built at $$(date '+%Y-%m-%d %H:%M:%S')"

# Regenerate any figure whose .py is newer than its .pdf. Idempotent — safe to
# re-run. Add new figs by dropping figures/_scripts/figNN_<name>.py; they'll be
# picked up automatically by the wildcard above.
figures: $(FIG_PDFS)

figures/%.pdf: figures/_scripts/%.py
	$(PYTHON) $<

clean:
	rm -f $(DOC).aux $(DOC).bbl $(DOC).blg $(DOC).log $(DOC).out \
	      $(DOC).toc $(DOC).synctex.gz
	@echo "[paper] intermediates cleaned (PDF preserved)"

distclean: clean
	rm -f $(DOC).pdf
