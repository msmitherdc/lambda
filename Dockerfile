FROM lambci/lambda:build-python3.7 as builder

ARG http_proxy
ARG CURL_VERSION=7.64.1
ARG GDAL_VERSION=2.4.0
ARG GEOS_VERSION=3.7.1
ARG PROJ_VERSION=5.2.0
ARG LASZIP_VERSION=3.4.1
ARG GEOTIFF_VERSION=1.4.3
ARG PDAL_VERSION=1.9.0
ARG ZSTD_VERSION=1.4.0
ARG DESTDIR="/build"
ARG PREFIX="/usr"

RUN \
  rpm --rebuilddb && \
  yum makecache fast && \
  yum install -y \
    automake16 \
    libpng-devel \
    nasm wget tar gcc zlib-devel gcc-c++ curl-devel zip libjpeg-devel rsync git ssh bzip2 automake \
        glib2-devel libtiff-devel pkg-config libcurl-devel;\
  yum install -y cmake3 --enablerepo=epel

#RUN \
#    wget https://github.com/Kitware/CMake/releases/download/v3.13.2/cmake-3.13.2.tar.gz; \
#    tar -zxvf cmake-3.13.2.tar.gz; \
#    cd cmake-3.13.2; \
#    ./bootstrap --prefix=/usr ;\
#    make -j $NPROC;\
#    make install DESTDIR=/

RUN \
    wget https://github.com/LASzip/LASzip/releases/download/$LASZIP_VERSION/laszip-src-$LASZIP_VERSION.tar.gz; \
    tar -xzf laszip-src-$LASZIP_VERSION.tar.gz; \
    cd laszip-src-$LASZIP_VERSION;\
    cmake3 -G "Unix Makefiles" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$PREFIX \
        -DBUILD_SHARED_LIBS=ON \
        -DBUILD_STATIC_LIBS=OFF \
        -DCMAKE_INSTALL_LIBDIR=lib \
    ; \
    make -j$(nproc); make install; make install DESTDIR= ; cd ..; \
    rm -rf laszip-src-${LASZIP_VERSION} laszip-src-$LASZIP_VERSION.tar.gz;

RUN git clone  https://github.com/hobu/laz-perf.git; \
    cd laz-perf; \
    mkdir build; \
    cd build; \
    cmake3 .. \
        -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX=$PREFIX \
        -DCMAKE_BUILD_TYPE="Release" \
    ; \
    make -j$(nproc); \
    make install

RUN mkdir /nitro; cd /nitro; \
    git clone https://github.com/hobu/nitro; \
    cd nitro; \
    mkdir build; \
    cd build; \
    cmake3 ..\
        -G "Unix Makefiles" \
        -DCMAKE_INSTALL_PREFIX=$PREFIX \
        -DCMAKE_INSTALL_LIBDIR=lib \
    ; \
    make -j$(nproc); \
    make install   

# ZSTD
RUN \
    mkdir zstd; \
    wget -qO- https://github.com/facebook/zstd/archive/v${ZSTD_VERSION}.tar.gz \
        | tar -xz -C zstd --strip-components=1; cd zstd; \
    make -j$(nproc) install PREFIX=$PREFIX ZSTD_LEGACY_SUPPORT=0 CFLAGS=-O1 --silent; \
    cd ..; rm -rf zstd


RUN \
    wget http://download.osgeo.org/geos/geos-$GEOS_VERSION.tar.bz2; \
    tar xjf geos*bz2; \
    cd geos*; \
    ./configure --prefix=$PREFIX CFLAGS="-O2 -Os"; \
    make -j$(nproc); make install; make install DESTDIR= ;\
    cd ..; \
    rm -rf geos*;

RUN \
    wget http://download.osgeo.org/proj/proj-$PROJ_VERSION.tar.gz; \
    tar -zvxf proj-$PROJ_VERSION.tar.gz; \
    cd proj-$PROJ_VERSION; \
    ./configure --prefix=$PREFIX; \
    make -j$(nproc); make install; make install DESTDIR=; cd ..; \
    rm -rf proj-$PROJ_VERSION proj-$PROJ_VERSION.tar.gz

RUN \
    wget https://download.osgeo.org/geotiff/libgeotiff/libgeotiff-$GEOTIFF_VERSION.tar.gz; \
    tar -xzvf libgeotiff-$GEOTIFF_VERSION.tar.gz; \
    cd libgeotiff-$GEOTIFF_VERSION; \
    ./configure \
        --prefix=$PREFIX --with-proj=/build/usr ;\
    make -j$(nproc); make install; make install DESTDIR=; cd ..; \
    rm -rf libgeotiff-$GEOTIFF_VERSION.tar.gz libgeotiff-$GEOTIFF_VERSION;

# GDAL
RUN \
    wget http://download.osgeo.org/gdal/$GDAL_VERSION/gdal-$GDAL_VERSION.tar.gz; \
    tar -xzvf gdal-$GDAL_VERSION.tar.gz; \
    cd gdal-$GDAL_VERSION; \
    ./configure \
        --prefix=$PREFIX \
        --with-geotiff=$DESTDIR/usr \
        --with-tiff=/usr \
        --with-curl=yes \
        --without-python \
        --with-geos=$DESTDIR/usr/bin/geos-config \
        --with-hide-internal-symbols=yes \
        CFLAGS="-O2 -Os" CXXFLAGS="-O2 -Os"; \
    make -j$(nproc); make install; make install DESTDIR= ; \
    cd $BUILD; rm -rf gdal-$GDAL_VERSION*

RUN \
    git clone https://github.com/PDAL/PDAL.git; \
    cd PDAL; \
    mkdir -p _build; \
    cd _build; \
    cmake3 .. \
        -G "Unix Makefiles" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CXX_FLAGS="-std=c++11" \
        -DCMAKE_MAKE_PROGRAM=make \
        -DBUILD_PLUGIN_HEXBIN=ON \
        -DBUILD_PLUGIN_MRSID=OFF \
        -DBUILD_PLUGIN_NITF=ON \
        -DBUILD_PLUGIN_OCI=OFF \
        -DBUILD_PLUGIN_PCL=OFF \
        -DBUILD_PLUGIN_PGPOINTCLOUD=OFF \
        -DBUILD_PLUGIN_SQLITE=ON \
        -DBUILD_PLUGIN_RIVLIB=OFF \
        -DBUILD_PLUGIN_PYTHON=OFF \
        -DENABLE_CTEST=OFF \
        -DWITH_LAZPERF=ON \
        -DWITH_LASZIP=ON \
        -DWITH_ZLIB=ON \
        -DWITH_ZSTD=ON \
        -DCMAKE_LIBRARY_PATH:FILEPATH="$DESTDIR/usr/lib" \
        -DCMAKE_INCLUDE_PATH:FILEPATH="$DESTDIR/usr/include" \
        -DCMAKE_INSTALL_PREFIX=$PREFIX \
        -DWITH_TESTS=OFF \
        -DCMAKE_INSTALL_LIBDIR=lib \
    ; \
    make -j$(nproc); make install; make install DESTDIR= ;

RUN rm /build/usr/lib/*.la ; rm /build/usr/lib/*.a
RUN ldconfig
ADD package-pdal.sh /

