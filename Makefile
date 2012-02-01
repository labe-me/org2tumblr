ifeq ($(PREFIX), )
PREFIX=/usr
endif

all:
	haxe -cp src -main App -neko org2tumblr.n
	nekotools boot org2tumblr.n
	rm org2tumblr.n

clean:
	-rm org2tumblr*

install:
	cp org2tumblr $(PREFIX)/bin/

uninstall:
	-rm org2tumblr $(PREFIX)/bin/org2tumblr
