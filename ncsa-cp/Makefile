all: ncsa-cacl-cp.pdf

%.pdf: %.tex
	pdflatex $*

%.bbl: biblio.bib %.aux
	bibtex $*

%.aux:
	pdflatex $*

again:
	\rm -f $(FILENAME).dvi $(FILENAME).ps $(FILENAME).pdf
	$(MAKE) -s

clean:
	\rm -f *.aux *.inx *.srt *.toc *.dvi *.log *.bbl *.blg *.eps *~

reallyclean: clean
	\rm -f $(FILENAME).ps $(FILENAME).pdf

wc:
	detex $(FILENAME).tex | wc -w

.PRECIOUS: %.dvi %.bbl
