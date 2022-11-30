FROM centos:7

RUN yum -y upgrade \
    && yum -y group install "Development Tools" \
    && yum -y install wget vim

WORKDIR /opt

RUN cd /opt/ \
    && wget http://igppweb.ucsd.edu/~agnew/Spotl/spotl.tar.gz --no-check-certificate\
    && tar -xzf spotl.tar.gz \
    && rm spotl.tar.gz \
    && cd spotl/src/ \
    && echo "FTN = gfortran" >> tempfile \
    && echo "FFLAGS = -O3 -Wuninitialized -fno-f2c -fno-automatic -fno-range-check -fno-backslash" >> tempfile \
    && echo "CC = /usr/bin/gcc" >> tempfile \
    && echo "CFLAGS = -c" >> tempfile \
    && cat Makefile >> tempfile \
    && mv tempfile Makefile \
    && cd ../ \
    && ./install.comp \
    && cd tidmod/ascii \
    && sed -i 's/gzcat/gunzip -c/g' Tobinary \
    && cd ../../ \
    && sed -i 's/Tobinary/.\/Tobinary/g' install.rest \
    && sed -i 's/gzcat/gunzip -c/g' install.rest \
    && sed -i 's/rm /rm -f /g' install.rest \
    && ./install.rest

RUN cd /opt/spotl/working/Exampl/ \
    && sed -i 's/spotl//g' ex1.scr \
    && sed -i 's/spotl//g' ex2.scr \
    && sed -i 's/spotl//g' ex3.scr \
    && sed -i 's/spotl//g' ex4.scr \
    && sed -i 's/spotl//g' ex5.scr \
    && sed -i 's/spotl//g' ex6.scr \
    && sed -i 's/ex5.scr/.\/ex5.scr/g' ex5.scr

RUN mkdir -p /opt/spotl/results


COPY working /opt/spotl/working/
ENV PATH="/opt/spotl/bin:/opt/spotl/working:${PATH}"

CMD ["echo", "enter 'docker run -it spotl_docker /bin/bash' to access interactive terminal"]
