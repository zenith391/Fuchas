LUACOMP_VERSION=1.2.0
COPY_TO=../d431f466-2b01-4469-a068-0579b32b7f96

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
	cp -rf dest/* $(COPY_TO)

luacomp:
	wget https://github.com/Adorable-Catgirl/LuaComp/releases/download/$(LUACOMP_VERSION)/luacomp-static
	mv luacomp-static luacomp
	chmod +x luacomp

install: luacomp
	mkdir dest
