.PHONY: all clean optimize deploy watch upload-stock
.DEFAULT_GOAL := all

DEVAPPSERVER_PORT = 7000

DEVAPPSERVER_ARGS=--show_mail_body \
	--datastore_path=$(CURDIR)/.dev_appserver.datastore \
	--history_path=$(CURDIR)/.dev_appserver.datastore.history \
	--disable_task_running \
	--port $(DEVAPPSERVER_PORT)

YUI=java -jar scripts/yuicompressor-2.4.7.jar

# Source code
COFFEE = $(wildcard web/static/*.coffee) $(wildcard web/webios/webios/*.coffee)
LESS = $(wildcard web/static/*.less) $(wildcard web/static/*/*.less) $(wildcard web/webios/webios/*.less)
JADE = $(wildcard web/*.jade) $(wildcard web/static/*/*.jade) $(wildcard web/webios/*.jade)

# Compiled code
JS = $(patsubst %.coffee,%.js,${COFFEE})
CSS = $(patsubst %.less,%.css,${LESS})
HTML = $(patsubst %.jade,%.html,${JADE})

help:
	@echo
	@echo "Mockko"
	@echo
	@echo "Available targets:"
	@echo "  make all      -- process JADE, CoffeeScript and Less"
	@echo "  make watch    -- watch and re-process changed files"
	@echo "  make optimize -- prepare optimized and obfuscated version"
	@echo "  make run      -- run application using dev. appserver (non-optimized, /dev only)"
	@echo "  make run-opt  -- run application using dev. appserver (optimized)"
	@echo "  make deploy-production -- upload application to GAE"
	@echo "  make deploy   -- upload 'playground' version to GAE"
	@echo "  make quick-deploy -- upload 'playground' version to GAE without running 'optimize' step"
	@echo "  make upload-stock -- upload 'stock' images to local devserver or GAE"
	@echo "  make clean    -- clean all generated files"

# Rule[sz]

all:
	@echo "  COFFEE/LESSC/JADE  ALL"
	@grunt coffee less jade

clean:
	@echo "  CLEAN"
	@rm -rf ${JS} ${CSS} ${HTML} ${OPT_DIR} ${SUM_FILES}

# Continuously compile

watch: all
	@while true; do \
		scripts/watchfiles '**/*.coffee' '**/*.jade' '**/*.less'; \
		${MAKE} && ( which growlnotify >/dev/null && growlnotify -n Mockko -p 0 -t "OK" -m "Mockko built." || true ) \
		    || ( which growlnotify >/dev/null && growlnotify -n Mockko -p 2 -t "Build FAILED" -m "Failed. Dunno which file and line, sorry." || true ); \
	done

# Optimization (and obfuscation)

OPT_DIR = web/minified

OPTIMIZED = $(addprefix ${OPT_DIR}/, \
	designer.min.html \
	iphone.min.css \
	theme.min.css \
	designer.min.js)

optimize: all ${OPTIMIZED}

# --> Checksums

%.sum:
	@echo "  SUM" $@
	@cat $^ | openssl sha1 | perl -ne 'print $$1 if /([0-9a-f]{40})/' > $@ || (rm -f $@; false)

find_images = $(shell find $(1) -name '*.png' -o -name '*.gif' -o -name '*.jpg')

THEME_IMAGES = $(call find_images, web/static/theme/images)
IPHONE_IMAGES = $(call find_images, web/static/iphone/images)

.theme-images.sum: ${THEME_IMAGES}
.iphone-images.sum: ${IPHONE_IMAGES}
.designerjs.sum: web/minified/designer.min.js
.themecss.sum: web/minified/theme.min.css
.iphonecss.sum: web/minified/iphone.min.css

SUM_FILES = .designerjs.sum .themecss.sum .iphonecss.sum \
	.theme-images.sum .iphone-images.sum

# --> Optimization

${OPT_DIR}/designer.min.html: web/designer.html .designerjs.sum .themecss.sum .iphonecss.sum
	@echo "  HTML PERL" $@
	@mkdir -p $(dir $@)
	grep -v 'designer-.*\.js\|geometry\.js\|jpicker\.js\|lib/.*\.js\|animations.css\|theme-designer.css\|theme-dashboard.css' < $< | perl -pe "s/designer\.js/designer.min.js?"$$(cat .designerjs.sum)"/g; s/iphone.css/iphone.min.css?"$$(cat .iphonecss.sum)"/g; s/theme-common.css/theme.min.css?"$$(cat .themecss.sum)"/g" > $@ || (rm -f $@; false)

${OPT_DIR}/iphone.min.css: web/static/iphone/iphone.css .iphone-images.sum
	@echo "  YUI " $<
	@mkdir -p $(dir $@)
	${YUI} $< | perl -pe "s,(images/[^\"]+),\1?"$$(cat .iphone-images.sum)",g" > $@ || (rm -f $@; false)

THEME_CSS = web/static/lib/animations.css \
	web/static/theme/theme-common.css \
	web/static/theme/theme-dashboard.css \
	web/static/theme/theme-designer.css

${OPT_DIR}/theme.min.css: ${THEME_CSS} .theme-images.sum
	@echo "  YUI theme.css"
	@mkdir -p $(dir $@)
	(for i in $(filter %.css,$^); do ${YUI} $$i; done) | \
		perl -pe "s,(images/[^\"]+),\1?"$$(cat .theme-images.sum)",g" > $@ || (rm -f $@; false)

${OPT_DIR}/designer.min.js: ${OPT_DIR}/designer.uglify.js
	@grunt min concat

${OPT_DIR}/designer.uglify.js: all

.INTERMEDIATE: \
	${OPT_DIR}/designer.uglify.js

# Run

run: all
	dev_appserver.py ${DEVAPPSERVER_ARGS} web

run-opt: optimize
	dev_appserver.py ${DEVAPPSERVER_ARGS} web

# Deployment

deploy-production: check-branches optimize do-deploy

check-branches:
	@echo "  CHECK BRANCHES"
	@git fetch origin
	@CUR_BRANCH=$$(git branch | awk '/^\*/ { print $$2 }'); \
	HEAD=$$(git show-ref -s refs/heads/$$CUR_BRANCH); \
	REMOTE_HEAD=$$(git show-ref -s refs/remotes/origin/$$CUR_BRANCH); \
	if [ x"$$HEAD" != x"$$REMOTE_HEAD" ]; then \
		echo "Please push your changes *before* deployment."; false; \
	fi

do-deploy: VER_ARG=$(if $(APP_VERSION),-V $(APP_VERSION))
do-deploy: all do-deploy-$(shell id -un)

do-deploy-andreyvit:
	appcfg.py $(VER_ARG) -e andreyvit@gmail.com --passin update web < ~/.andreyvit_passwd

do-deploy-dottedmag:
	appcfg.py $(VER_ARG) -e dottedmag@dottedmag.net update web

do-deploy-next:
	appcfg.py $(VER_ARG) -e timofey.vasenin@gmail.com update web

deploy: APP_VERSION=$(shell id -un)-playground
deploy: optimize do-deploy

quick-deploy: APP_VERSION=$(shell id -un)-playground
quick-deploy: do-deploy

upload-stock:
	python scripts/upload_stock --no-auth -s localhost:$(DEVAPPSERVER_PORT) mockkodesigner-hrd
