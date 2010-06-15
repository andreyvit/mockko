.PHONY: all clean optimize deploy watch
.DEFAULT_GOAL := all

# Per-system configuration
ifeq ($(shell uname -s),Darwin)
  COFFEE_ARGS=--growl
endif

CLOSURE=java -jar scripts/closure-compiler/compiler.jar
YUI=java -jar scripts/yuicompressor-2.4.2.jar
PREMIN=ruby scripts/preminifier/premin.rb

# Source code
COFFEE = $(wildcard web/static/*.coffee)
LESS = $(wildcard web/static/*/*.less)
HAML = $(wildcard web/*.haml)

# Compiled code
JS = $(patsubst %.coffee,%.js,${COFFEE})
CSS = $(patsubst %.less,%.css,${LESS})
HTML = $(patsubst %.haml,%.html,${HAML})

help:
	@echo
	@echo "Mockko"
	@echo
	@echo "Available targets:"
	@echo "  make all      -- process HAML, CoffeeScript and Less"
	@echo "  make watch    -- watch and re-process changed files"
	@echo "  make optimize -- prepare optimized and obfuscated version"
	@echo "  make run      -- run application using dev. appserver"
	@echo "  make deploy   -- upload application to GAE"
	@echo "  make clean    -- clean all generated files"

# Rule[sz]

all: ${HTML} ${JS} ${CSS}

%.js: %.coffee
	@echo "  COFFEE" $^
	@coffee -c ${COFFEE_ARGS} $^

%.css: %.less
	@echo "  LESSC" $^
	@lessc $^ $@

%.html: %.haml
	@echo "  HAML" $^
	@haml $^ $@

clean:
	@echo "  CLEAN"
	@rm -rf ${JS} ${CSS} ${HTML} ${OPT_DIR} ${SUM_FILES}

# Continuously compile

watch: watch-$(shell uname -s)

watch-Linux:
	@while true; do \
		f=$$(find . -regex '.*\.\(coffee\|haml\|less\)'); \
		echo "Watching "$$(echo $$f | wc -w)" files..."; \
		inotifywait -qq -t 30 -r $$f; \
		${MAKE}; \
	done

watch-Darwin:
	@echo "Not implemented yet"; false

# Optimization (and obfuscation)

OPT_DIR = web/minified

OPTIMIZED = $(addprefix ${OPT_DIR}/, \
	designer.min.html \
	iphone.min.css \
	theme.min.css \
	designer.min.js)

optimize: ${OPTIMIZED}

# --> Checksums

%.sum:
	@echo "  SUM" $@
	@cat $^ | openssl sha1 > $@

find_images = $(shell find $(1) -regex '.*\.\(png\|jpg\|gif\)')

THEME_IMAGES = $(call find_images, web/static/theme/images)
IPHONE_IMAGES = $(call find_images, web/static/iphone/images)
STOCK_IMAGES = $(call find_images, web/static/stock)

.theme-images.sum: ${THEME_IMAGES}
.stock-images.sum: ${STOCK_IMAGES}
.iphone-images.sum: ${IPHONE_IMAGES}
.designerjs.sum: web/minified/designer.min.js
.themecss.sum: web/minified/theme.min.css
.iphonecss.sum: web/minified/iphone.min.css

SUM_FILES = .designerjs.sum .themecss.sum .iphonecss.sum \
	.theme-images.sum .stock-images.sum .iphone-images.sum

# --> Optimization

${OPT_DIR}/designer.min.html: web/designer.html .designerjs.sum .themecss.sum .iphonecss.sum
	@echo "  HTML SED" $@
	grep -v 'designer-.*\.js\|jpicker\.js\|lib/.*\.js\|animations.css\|theme-designer.css\|theme-dashboard.css' < $< | perl -pe "s/designer\.js/designer.min."$$(cat .designerjs.sum)".js/g; s/iphone.css/iphone.min."$$(cat .iphonecss.sum)".css/g; s/theme-common.css/theme.min."$$(cat .themecss.sum)".css/g" > $@

${OPT_DIR}/iphone.min.css: web/static/iphone/iphone.css .iphone-images.sum
	@echo "  YUI " $<
	${YUI} $< | perl -pe "s,images/,images."$$(cat .iphone-images.sum)"/,g" > $@

THEME_CSS = web/static/lib/animations.css \
	web/static/theme/theme-common.css \
	web/static/theme/theme-dashboard.css \
	web/static/theme/theme-designer.css

${OPT_DIR}/theme.min.css: ${THEME_CSS} .theme-images.sum
	@echo "  YUI theme.css"
	(for i in $(filter %.css,$^); do ${YUI} $$i; done) | \
		perl -pe "s,images/,images."$$(cat .theme-images.sum)"/,g" > $@

JS_LIBS = $(addprefix web/static/lib/, \
	jquery-1.4.2.min.js \
	jquery-ui-1.8.custom.min.js \
	underscore.min.js \
	jquery.cookie.js)

${OPT_DIR}/designer.min.js: ${JS_LIBS} ${OPT_DIR}/designer.closure.js .stock-images.sum
	@echo "  YUI designer.js"
	(for i in $(filter %.js,$^); do ${YUI} $$i; done) | \
		perl -pe "s,images/,images."$$(cat .stock-images.sum)"/,g" > $@

%.closure.js: %.premin.js
	@echo "  CLOSURE" $^
	${CLOSURE} --compilation_level SIMPLE_OPTIMIZATIONS --js $^ --js_output_file $@

%.premin.js: %.combined.js
	@echo "  PREMIN" $^
	${PREMIN} < $^ > $@ 2>/dev/null

JS_SRC = $(addprefix web/static/, \
	designer-jqueryaddons.js \
	designer-components.js \
	designer-templates.js \
	jpicker.js \
	designer-image-directories.js \
	designer.js)

${OPT_DIR}/designer.combined.js: ${JS_SRC}
	@echo "  CAT >" $@
	@mkdir -p $(dir $@)
	cat $^ > $@

.INTERMEDIATE: \
	${OPT_DIR}/designer.combined.js \
	${OPT_DIR}/designer.closure.js

# Run

run: optimize
	dev_appserver.py web

# Deployment

deploy: deploy-$(shell id -un)

deploy-andreyvit: optimize
	appcfg.py -e andreyvit@gmail.com --passin update web < ~/.andreyvit_passwd
