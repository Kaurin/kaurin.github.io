all: lint bundle_update bundle_install serve

lint:
	echo TODO

bundle_update:
	bundle lock --update

bundle_install:
	bundle install

serve:
	bundle exec jekyll serve

.PHONY: all lint bundle_update bundle_install serve
