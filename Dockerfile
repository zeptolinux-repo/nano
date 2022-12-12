FROM ubuntu:latest AS build

RUN apt-get update && apt-get install -y automake git pkg-config gcc autopoint gettext texinfo make wget


# musl
WORKDIR /root
RUN git clone -n https://git.etalabs.net/git/musl
WORKDIR /root/musl
RUN git fetch && git checkout v1.2.3
RUN ./configure
RUN make -j$(nproc)
RUN make install


# ncurses (has no git repo)
WORKDIR /root
#RUN wget https://invisible-mirror.net/archives/ncurses/ncurses-6.3.tar.gz # doesn't work with ms azure / github actions
RUN wget https://mirrors.dotsrc.org/gnu/ncurses/ncurses-6.3.tar.gz
RUN tar -xf ncurses*.tar.gz
RUN mv ncurses-*/ ncurses
WORKDIR /root/ncurses
RUN bash -c "CC='/usr/local/musl/bin/musl-gcc -static' CFLAGS='-fPIC' ./configure --prefix=/usr --disable-shared --enable-static --with-normal \
  --with-default-terminfo=/usr/share/terminfo --with-terminfo-dirs="/etc/terminfo:/lib/terminfo:/usr/share/terminfo:/usr/lib/terminfo" \
  --without-debug --without-ada"
RUN mkdir build
RUN make DESTDIR="/root/ncurses/build" install.libs install.includes # ncurses' makefile is bad, don't use -j


# linux
WORKDIR /root
RUN wget https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.15.38.tar.xz
RUN tar -xf linux-*.*.*.tar.xz
RUN mv linux-*.*.*/ linux


# nano
WORKDIR /root
RUN git clone -n git://git.savannah.gnu.org/nano.git
WORKDIR /root/nano
RUN git fetch && git checkout v7.0
RUN ./autogen.sh
RUN bash -c "CC='/usr/local/musl/bin/musl-gcc -static' CFLAGS='-fPIC' CPPFLAGS='-I/root/ncurses/build/usr/include -I/root/linux/include' \
  LDFLAGS='-L/root/ncurses/build/usr/lib' ./configure --disable-dependency-tracking"
RUN make -j$(nproc)
RUN strip src/nano



# export
FROM scratch AS export
COPY --from=build /root/nano/src/nano /usr/bin/nano
