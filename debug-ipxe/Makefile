IP ?= $(shell curl -s ifconfig.me)
SERVER ?= http://$(IP)

FILES = web/index.html web/boot.ipxe web/undionly.kpxe

default: $(FILES)
	docker-compose up -d --wait
	curl -s $(SERVER)
	curl -s $(SERVER)/boot.ipxe
	@echo
	@echo Target to use: $(SERVER)

web/index.html: web/chain.ipxe
	mkdir -p web
	rm -f $@
	ln -s $(notdir $<) $@

web/%.ipxe: %.template
	mkdir -p web
	sed -e 's|IP|$(IP)|g;s|SERVER|$(SERVER)|g' $< > $@

web/undionly.kpxe: ../binary/undionly.kpxe
	mkdir -p web
	cp $< $@

.PHONY: clean files
clean:
	rm -rf web
files: clean $(FILES)

destroy: clean
	docker-compose down
