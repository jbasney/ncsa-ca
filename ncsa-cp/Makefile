
M4=m4

TIMESTAMP=`date`

TEX_FILES=ncsa-ca-policy.tex ncsa-slcs-policy.tex ncsa-gridshib-policy.tex ncsa-2fca-policy.tex

PDF_FILES=$(TEX_FILES:.tex=.pdf)
DVI_FILES=$(TEX_FILES:.tex=.dvi)
AUX_FILES=$(TEX_FILES:.tex=.aux)
PS_FILES=$(TEX_FILES:.tex=.ps)


all: pdf

pdf: $(PDF_FILES)

tex: $(TEX_FILES)

%.pdf: %.tex
	pdflatex $*

%.bbl: biblio.bib %.aux
	bibtex $*

%.aux:
	pdflatex $*

again:
	\rm -f $(DVI_FILES) $(PS_FILES) $(PDF_FILES)
	$(MAKE) -s

clean:
	\rm -f *.aux *.inx *.srt *.toc *.dvi *.log *.bbl *.blg *.eps *~
	\rm -f *.out
	\rm -f $(TEX_FILES)

reallyclean: clean
	\rm -f $(PS_FILES) $(PDF_FILES)

.PRECIOUS: %.dvi %.bbl

ncsa-ca-policy.tex: ncsa-master-cp.tex.m4
	$(M4) -DM4_NCSA_CA $< > $@

ncsa-slcs-policy.tex: ncsa-master-cp.tex.m4
	$(M4) -DM4_NCSA_SLCS $< > $@

ncsa-2fca-policy.tex: ncsa-master-cp.tex.m4
	$(M4) -DM4_NCSA_2FCA $< > $@

publish: pdf
	rsync $(PDF_FILES) public-linux.ncsa.uiuc.edu:/afs/ncsa.uiuc.edu/web/security.ncsa.uiuc.edu/htdocs/CA
