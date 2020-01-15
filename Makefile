LUACOMP_VERSION=1.2.0

all: clean build

clean:
	rm -r dest

build:
	if [ ! -d dest ]; then \
		mkdir dest; \
	fi
	cd src; \
	find . | while IFS= read -r ROW ; do \
		if [ -d $$ROW ]; then \
			mkdir ../dest/$$ROW; \
		else \
			../luacomp -O ../dest/$$ROW $$ROW; \
		fi; \
	done

luacomp:
	wget https://github.com/Adorable-Catgirl/LuaComp/releases/download/$(LUACOMP_VERSION)/luacomp-static
	mv luacomp-static luacomp
	chmod +x luacomp

install: luacomp
	mkdir dest
