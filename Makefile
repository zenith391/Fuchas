LUACOMP=lua luacomp-static-5.3

all: clean build

clean:
	rm -r tmp

build:
	if [ ! -d tmp ]; then \
		mkdir tmp; \
	fi
	find Fuchas Users/Shared | while IFS= read -r ROW ; do \
		if [ -d $$ROW ]; then \
			mkdir tmp/$$ROW; \
		else \
			$(LUACOMP) -O tmp/$$ROW $$ROW; \
		fi; \
	done

luacomp:
	wget https://github.com/Adorable-Catgirl/LuaComp/releases/download/$(LUACOMP_VERSION)/luacomp-static
	mv luacomp-static luacomp
	chmod +x luacomp

install: luacomp
	mkdir tmp
