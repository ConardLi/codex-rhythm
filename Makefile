.PHONY: test build install package clean

test:
	./scripts/test.sh

build:
	./scripts/build.sh

install:
	./scripts/install.sh

package:
	./scripts/package.sh

clean:
	rm -rf build dist
