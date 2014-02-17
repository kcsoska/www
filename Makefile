SITE?=databrary datavyu

WWW=/home/www
APACHE=/etc/apache2/vhosts.d/www.conf

PORT_databrary=8001
PORT_datavyu=8002

PY=python3
PELICAN=$(PY) $(shell which pelican)
PELICANOPTS=

CONF=pelicanconf.py

ifeq ($(DEBUG), 1)
	PELICANOPTS += -D
endif

help:
	@echo 'Makefile for a pelican Web site                                        '
	@echo '                                                                       '
	@echo 'Usage:                                                                 '
	@echo '   make html [SITE=all]     (re)generate the web site          '
	@echo '   make clean               remove the generated files         '
	@echo '   make regenerate          regenerate files upon modification '
	@echo '   make stanging            publish to $(WWW)/staging'
	@echo '   make production          publish to $(WWW)'
	@echo '   make deploy              update and publish to $(WWW)'
	@echo '   make start [SITE=]       start/restart develop_server.sh    '
	@echo '   make stop                stop local server                  '
	@echo '                                                                       '
	@echo 'Set the DEBUG variable to 1 to enable debugging, e.g. make DEBUG=1 html'
	@echo '                                                                       '

regenerate: PELICANOPTS+=-r
publish: CONF=publishconf.py

ifneq ($(filter staging,$(MAKECMDGOALS)),)
OUTDIR=$(WWW)/staging
else ifneq ($(filter production deploy,$(MAKECMDGOALS)),)
OUTDIR=$(WWW)
else
OUTDIR=output
endif
ifneq ($(filter deploy,$(MAKECMDGOALS)),)
UPDATE:=FORCE
else
STAMP:=FORCE
endif

html: generate
regenerate: generate
publish: generate
staging: publish
production: publish
deploy: production
	@diff etc/apache.conf $(APACHE) || echo "Apache config (above) needs updating."

generate: $(SITE:%=$(OUTDIR)/%/index.html)
$(OUTDIR)/%/index.html: ../www/.git/refs/heads/master $(STAMP)
	$(PELICAN) -o $(OUTDIR)/$* -s $*/$(CONF) $(PELICANOPTS)

$(OUTDIR)/datavyu/index.html: datavyu/input/pages/user-guide/index.html datavyu/input/docs/user-guide.pdf ../datavyu/version.txt ../datavyu/pre_version.txt
$(OUTDIR)/databrary/index.html: databrary/input/policies

../%/.git/refs/heads/master: $(UPDATE)
	cd ../$* && [[ `git symbolic-ref HEAD` = refs/heads/master ]] && git pull

datavyu/input/pages/user-guide/index.html: ../datavyu-docs/.git/refs/heads/master
	$(MAKE) -C ../datavyu-docs html-pelican
datavyu/input/docs/user-guide.pdf: ../datavyu-docs/.git/refs/heads/master
	$(MAKE) -C ../datavyu-docs latexpdf
	mkdir -p $(dir $@)
	ln -f ../datavyu-docs/build/latex/DatavyuManual.pdf $@
../datavyu/version.txt ../datavyu/pre_version.txt: ../datavyu/.git/refs/heads/master
databrary/input/policies: ../policies/.git/refs/heads/master
	$(MAKE) -C ../policies all
	ln -sfT ../../../policies/doc $@

clean:
	rm -rf output

start: generate $(addprefix start-,$(SITE))
start-%:
	./devserver.sh restart $(PORT_$*) $* &

stop: $(addprefix stop-,$(SITE))
stop-%:
	./devserver.sh stop $(PORT_$*) $*
	@echo 'Stopped Pelican and SimpleHTTPServer processes running in background.'

.PHONY: FORCE html help clean generate regenerate start stop publish staging production deploy