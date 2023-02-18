# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: Copyright © 2021 Erez Geva <ErezGeva2@gmail.com>
#
# Makefile Create libptpmgmt and pmc for testing
#
# @author Erez Geva <ErezGeva2@@gmail.com>
# @copyright © 2021 Erez Geva
#
###############################################################################

PMC_USE_LIB?=a # 'a' for static and 'so' for dynamic

define help
################################################################################
#  Make file targets                                                           #
################################################################################
#                                                                              #
#   all              Build all targets.                                        #
#                                                                              #
#   clean            Clean build files.                                        #
#                                                                              #
#   distclean        Perform full clean.                                       #
#                                                                              #
#   format           Format source code and warn of format issues.             #
#                                                                              #
#   doxygen          Create library documentation.                             #
#                                                                              #
#   checkall         Call doxygen and format targets.                          #
#                                                                              #
#   help             See this help.                                            #
#                                                                              #
#   install          Install application, libraries, and headers in system.    #
#                                                                              #
#   utest            Build and run the unit test                               #
#                                                                              #
#   utest <filter>   Build and run the unit test with filer                    #
#                                                                              #
#   deb              Build Debian packages.                                    #
#                                                                              #
#   deb_arc          Build Debian packages for other architecture.             #
#                    Use DEB_ARC to specify architecture.                      #
#                                                                              #
#   deb_arc <arc>    Build Debian packages for other architecture.             #
#                    With the architecture, skip using DEB_ARC                 #
#                                                                              #
#   deb_clean        Clean Debian intermediate files.                          #
#                                                                              #
#   srcpkg           Create source tar with library code only.                 #
#                                                                              #
#   rpm              Build Red Hat packages.                                   #
#                                                                              #
#   pkg              Build Arch Linux packages.                                #
#                                                                              #
#   gentoo           Build on gentoo target.                                   #
#                                                                              #
#   config           Configure using system default configuration              #
#                                                                              #
################################################################################
#  Make file parameters                                                        #
################################################################################
#                                                                              #
#   PMC_USE_LIB      Select the pmc tool library link,                         #
#                    use 'a' for static library or 'so' for shared library.    #
#                                                                              #
#   DESTDIR          Destination folder for install target.                    #
#                    Installation prefix.                                      #
#                                                                              #
#   DEV_PKG          Development package name, default libptpmgmt-dev.         #
#                                                                              #
#   USE_ASAN         Use the AddressSanitizer, for testing!                    #
#                                                                              #
#   NO_COL           Prevent colour output.                                    #
#                                                                              #
#   USE_COL          Force colour when using pipe for tools like 'aha'.        #
#                    For example: make -j USE_COL=1 | aha > out.html           #
#                                                                              #
#   DEB_ARC          Specify Debian architectue to build                       #
#                                                                              #
#   PY_USE_S_THRD    Use python with 'Global Interpreter Lock',                #
#                    Which use mutex on all library functions.                 #
#                    So poll() and tpoll() can block other threads.            #
#                    In this case, users may prefer Python native select.      #
#                                                                              #
################################################################################

endef

###############################################################################
### General macroes
which=$(shell which $1 2>/dev/null)
NOP:=@:
define depend
$1: $2

endef
define phony
.PHONY: $1
$1:
	$(NOP)

endef
SP:=$(subst X, ,X)
verCheckDo=$(shell if [ $1 -eq $4 ];then test $2 -eq $5 && a=$3 b=$6 ||\
  a=$2 b=$5; else a=$1 b=$4;fi;test $$a -lt $$b && echo l)
verCheck=$(call verCheckDo,$(firstword $(subst ., ,$1 0 0 0)),$(word 2,\
  $(subst ., ,$1 0 0 0)),$(word 3,$(subst ., ,$1 0 0 0)),$(firstword\
  $(subst ., ,$2 0)),$(word 2,$(subst ., ,$2 0)),$(word 3,$(subst ., ,$2 0)))

# Make support new file function
ifeq ($(call cmp,$(MAKE_VERSION),4.2),)
USE_FILE_OP:=1
endif
define lbase
A

endef
line=$(subst A,,$(lbase))
space=$(subst A,,A A)

###############################################################################
### output shaper

ifdef USE_COL
GTEST_NO_COL:=--gtest_color=yes
RUBY_NO_COL:=--use-color=yes
PHP_NO_COL:=--colors=always
else
ifdef NO_COL # gtest handles terminal by itself
GTEST_NO_COL:=--gtest_color=no
RUBY_NO_COL:=--no-use-color
PHP_NO_COL:=--colors=never
endif
endif

# Use tput to check if we have ANSI Colour code
# tput works only if TERM is set
ifneq ($(and $(TERM),$(call which,tput)),)
ifeq ($(shell tput setaf 1),)
NO_COL:=1
endif
endif # which tput
# Detect output is not device (terminal), it must be a pipe or a file
ifndef USE_COL
ifndef MAKE_TERMOUT
NO_COL:=1
endif
endif # USE_COL

# Terminal colours
ifndef NO_COL
ESC!=printf '\e['
COLOR_BLACK:=      $(ESC)30m
COLOR_RED:=        $(ESC)31m
COLOR_GREEN:=      $(ESC)32m
COLOR_YELLOW:=     $(ESC)33m
COLOR_BLUE:=       $(ESC)34m
COLOR_MAGENTA:=    $(ESC)35m
COLOR_CYAN:=       $(ESC)36m
COLOR_LTGRAY:=     $(ESC)37m
COLOR_DRKGRAY:=    $(ESC)1;30m
COLOR_NORM:=       $(ESC)00m
COLOR_BACKGROUND:= $(ESC)07m
COLOR_BRIGHTEN:=   $(ESC)01m
COLOR_UNDERLINE:=  $(ESC)04m
COLOR_BLINK:=      $(ESC)05m
GTEST_NO_COL?=--gtest_color=auto
RUBY_NO_COL?=--use-color=auto
PHP_NO_COL?=--colors=auto
endif

ifneq ($(V),1)
Q:=@
COLOR_WARNING:=$(COLOR_RED)
COLOR_BUILD:=$(COLOR_MAGENTA)
Q_CLEAN=$Q$(info $(COLOR_BUILD)Cleaning$(COLOR_NORM))
Q_DISTCLEAN=$Q$(info $(COLOR_BUILD)Cleaning all$(COLOR_NORM))
Q_TAR=$Q$(info $(COLOR_BUILD)[TAR] $@$(COLOR_NORM))
MAKE_NO_DIRS:=--no-print-directory
endif

###############################################################################
### Generic definitions
.ONESHELL: # Run rules in a single shell
include version
# ver_maj=PACKAGE_VERSION_MAJ
# ver_min=PACKAGE_VERSION_MIN

SRC:=src
PMC_DIR:=tools
JSON_SRC:=json
OBJ_DIR:=objs

SONAME:=.$(ver_maj)
LIB_NAME:=libptpmgmt
LIB_NAME_SO:=$(LIB_NAME).so
LIB_NAME_A:=$(LIB_NAME).a
LIB_NAME_FSO:=$(LIB_NAME_SO)$(SONAME)
PMC_NAME:=$(PMC_DIR)/pmc
SWIG_NAME:=PtpMgmtLib
SWIG_LNAME:=ptpmgmt
SWIG_LIB_NAME:=$(SWIG_LNAME).so
D_FILES:=$(wildcard */*.d */*/*.d)
PHP_LNAME:=php/$(SWIG_LNAME)
HEADERS_GEN_COMP:=$(addprefix $(SRC)/,ids.h mngIds.h callDef.h ver.h)
HEADERS_GEN:=$(HEADERS_GEN_COMP) $(addprefix $(SRC)/,vecDef.h cnvFunc.h)
HEADERS_SRCS:=$(filter-out $(HEADERS_GEN),$(wildcard $(SRC)/*.h))
HEADERS:=$(HEADERS_SRCS) $(HEADERS_GEN_COMP)
HEADERS_INST:=$(filter-out $(addprefix $(SRC)/,comp.h ids.h),$(HEADERS))
SRCS:=$(wildcard $(SRC)/*.cpp)
COMP_DEPS:=$(OBJ_DIR) $(HEADERS_GEN_COMP)
# json-c
JSONC_LIB:=$(LIB_NAME)_jsonc.so
JSONC_LIBA:=$(LIB_NAME)_jsonc.a
JSONC_FLIB:=$(JSONC_LIB)$(SONAME)
# fastjson
FJSON_LIB:=$(LIB_NAME)_fastjson.so
FJSON_LIBA:=$(LIB_NAME)_fastjson.a
FJSON_FLIB:=$(FJSON_LIB)$(SONAME)
TGT_LNG:=perl5 lua python3 ruby php tcl
UTEST_TGT:=utest_cpp utest_json utest_sys utest_json_load\
  $(foreach n,$(TGT_LNG),utest_$n)
INS_TGT:=install_main $(foreach n,$(TGT_LNG),install_$n)
PHONY_TGT:=all clean distclean format install deb deb_arc deb_clean\
  doxygen checkall help srcpkg rpm pkg gentoo utest config\
  $(UTEST_TGT) $(INS_TGT) utest_lua_a
.PHONY: $(PHONY_TGT)
NONPHONY_TGT:=$(firstword $(filter-out $(PHONY_TGT),$(MAKECMDGOALS)))

####### Source tar file #######
TAR:=tar cfJ
SRC_NAME:=$(LIB_NAME)-$(ver_maj).$(ver_min)
ifneq ($(call which,git),)
INSIDE_GIT!=git rev-parse --is-inside-work-tree 2>/dev/null
endif
SRC_FILES_DIR:=$(wildcard scripts/* *.sh *.pl *.md *.cfg *.opt *.in\
  config.guess config.sub configure.ac install-sh $(SRC)/*.in $(SRC)/*.m4\
  php/*.sh tcl/*.sh swig/*.md swig/*/* */*.i man/* LICENSES/* .reuse/*\
  $(PMC_DIR)/phc_ctl $(PMC_DIR)/*.[ch]* $(JSON_SRC)/* */Makefile)\
  $(SRCS) $(HEADERS_SRCS) LICENSE $(MAKEFILE_LIST)
ifeq ($(INSIDE_GIT),true)
SRC_FILES!=git ls-files $(foreach n,archlinux debian rpm sample gentoo\
  utest/*.[ch]*,':!/:$n') ':!:*.gitignore' ':!:*test.*'
# compare manual source list to git based:
diff1:=$(filter-out $(SRC_FILES_DIR),$(SRC_FILES))
diff2:=$(filter-out $(SRC_FILES),$(SRC_FILES_DIR))
ifneq ($(diff1),)
$(info $(COLOR_WARNING)source files missed in SRC_FILES_DIR: $(diff1)$(COLOR_NORM))
endif
ifneq ($(diff2),)
$(info $(COLOR_WARNING)source files present only in SRC_FILES_DIR: $(diff2))
endif
else # ($(INSIDE_GIT),true)
SRC_FILES:=$(SRC_FILES_DIR)
endif # ($(INSIDE_GIT),true)
# Add configure script for source archive
SRC_FILES+=configure

###############################################################################
### Configure area
ifeq ($(wildcard defs.mk),)
ifeq ($(MAKECMDGOALS),)
$(info defs.mk is missing, please run ./configure)
endif
all: configure
	$(NOP)

###############################################################################
### Build area
else # wildcard defs.mk
include defs.mk

ifneq ($(V),1)
Q_DOXY=$Q$(info $(COLOR_BUILD)Doxygen$(COLOR_NORM))
Q_FRMT=$Q$(info $(COLOR_BUILD)Format$(COLOR_NORM))
Q_TAGS=$Q$(info $(COLOR_BUILD)[TAGS]$(COLOR_NORM))
Q_GEN=$Q$(info $(COLOR_BUILD)[GEN] $@$(COLOR_NORM))
Q_SWIG=$Q$(info $(COLOR_BUILD)[SWIG] $@$(COLOR_NORM))
Q_LD=$Q$(info $(COLOR_BUILD)[LD] $@$(COLOR_NORM))
Q_AR=$Q$(info $(COLOR_BUILD)[AR] $@$(COLOR_NORM))
Q_LCC=$(info $(COLOR_BUILD)[LCC] $<$(COLOR_NORM))
Q_CC=$Q$(info $(COLOR_BUILD)[CC] $<$(COLOR_NORM))
Q_UTEST=$Q$(info $(COLOR_BUILD)[UTEST $1]$(COLOR_NORM))
LIBTOOL_QUIET:=--quiet
endif

LN:=$(LN_S) -f
ifeq ($(findstring -O,$(CXXFLAGS)),)
# Add debug optimization, unless we already have an optimization :-)
override CXXFLAGS+=-Og
endif # find '-O'
override CXXFLAGS+=-Wdate-time -Wall -std=c++11 -g -Isrc
override CXXFLAGS+=-MT $@ -MMD -MP -MF $(basename $@).d
ifeq ($(USE_ASAN),)
else
# Use https://github.com/google/sanitizers/wiki/AddressSanitizer
ASAN_FLAGS:=$(addprefix -fsanitize=,address pointer-compare pointer-subtract\
  undefined leak)
override CXXFLAGS+=$(ASAN_FLAGS) -fno-omit-frame-pointer
override LDFLAGS+=$(ASAN_FLAGS)
endif # USE_ASAN
LIBTOOL_CC=$Q$(Q_LCC)libtool --mode=compile --tag=CXX $(LIBTOOL_QUIET)
LDFLAGS_NM=-Wl,--version-script,scripts/lib.ver -Wl,-soname,$@$(SONAME)
$(LIB_NAME_SO)_LDLIBS:=-lm -ldl
LIB_OBJS:=$(subst $(SRC)/,$(OBJ_DIR)/,$(SRCS:.cpp=.o))
PMC_OBJS:=$(subst $(PMC_DIR)/,$(OBJ_DIR)/,$(patsubst %.cpp,%.o,\
  $(wildcard $(PMC_DIR)/*.cpp)))
$(OBJ_DIR)/ver.o: override CXXFLAGS+=-DVER_MAJ=$(ver_maj)\
  -DVER_MIN=$(ver_min) -DVER_VAL=$(PACKAGE_VERSION_VAL)
D_INC=$(if $($1),$(SED) -i 's@$($1)@\$$($1)@g' $(basename $@).d)
LLC=$(Q_LCC)$(CXX) $(CXXFLAGS) $(CXXFLAGS_SWIG) -fPIC -DPIC -I. $1 -c $< -o $@
LLA=$(Q_AR)$(AR) rcs $@ $^;$(RANLIB) $@

ifeq ($(call verCheck,$(shell $(CXX) -dumpversion),4.9),)
# GCC output colours
ifndef NO_COL
CXXFLAGS_COLOR:=-fdiagnostics-color=always
else
CXXFLAGS_COLOR:=-fdiagnostics-color=never
endif
endif # verCheck CXX 4.9
# https://clang.llvm.org/docs/UsersManual.html
# -fcolor-diagnostics
override CXXFLAGS+=$(CXXFLAGS_COLOR)

ALL:=$(PMC_NAME) $(LIB_NAME_FSO) $(LIB_NAME_A)

%.so:
	$(Q_LD)$(CXX) $(LDFLAGS) $(LDFLAGS_NM) -shared $^ $(LOADLIBES)\
	  $($@_LDLIBS) $(LDLIBS) -o $@

# JSON libraries
include json/Makefile

# Compile library source code
$(LIB_OBJS): $(OBJ_DIR)/%.o: $(SRC)/%.cpp | $(COMP_DEPS)
	$(LIBTOOL_CC) $(CXX) -c $(CXXFLAGS) $< -o $@

# Depened shared library objects on the static library to ensure build
$(eval $(foreach obj,$(notdir $(LIB_OBJS)),\
  $(call depend,$(OBJ_DIR)/.libs/$(obj),$(OBJ_DIR)/$(obj))))

$(LIB_NAME_A): $(LIB_OBJS)
	$(LLA)
$(LIB_NAME_FSO): $(LIB_NAME_SO)
	$Q$(LN) $^ $@
$(LIB_NAME_SO): $(addprefix $(OBJ_DIR)/.libs/,$(notdir $(LIB_OBJS)))

include utest/Makefile

# pmc tool
$(PMC_OBJS): $(OBJ_DIR)/%.o: $(PMC_DIR)/%.cpp | $(COMP_DEPS)
	$(Q_CC)$(CXX) $(CXXFLAGS) $(CXXFLAGS_PMC) -c -o $@ $<
$(PMC_NAME): $(PMC_OBJS) $(LIB_NAME).$(PMC_USE_LIB)
	$(Q_LD)$(CXX) $(LDFLAGS) $^ $(LOADLIBES) $(LDLIBS) -o $@

$(SRC)/%.h: $(SRC)/%.m4 $(SRC)/ids_base.m4
	$(Q_GEN)m4 -I $(SRC) $< > $@
$(SRC)/ver.h: $(SRC)/ver.h.in
	$(Q_GEN)$(SED) $(foreach n,PACKAGE_VERSION_MAJ PACKAGE_VERSION_MIN\
	  PACKAGE_VERSION_VAL PACKAGE_VERSION,-e 's/@$n@/$($n)/') $< > $@

ifneq ($(ASTYLEMINVER),)
EXTRA_SRCS:=$(wildcard $(foreach n,sample utest,$n/*.cpp $n/*.h))
format: $(HEADERS_GEN) $(HEADERS_SRCS) $(SRCS) $(EXTRA_SRCS)
	$(Q_FRMT)
	r=`$(ASTYLE) --project=none --options=astyle.opt $^`
	test -z "$$r" || echo "$$r";./format.pl $^
	if test $$? -ne 0 || test -n "$$r"; then echo '';exit 1;fi
ifneq ($(CPPCHECK),)
	$(CPPCHECK) --quiet --language=c++ --error-exitcode=-1\
	  $(filter-out $(addprefix $(SRC)/,ids.h proc.cpp),$^)
endif
endif # ASTYLEMINVER

ifneq ($(SWIGMINVER),)
SWIG_ALL:=
ifneq ($(SWIGARGCARGV),)
# Only python and ruby have argcargv.i
perl_SFLAGS+=-Iswig/perl5
$(foreach n,lua php tcl,$(eval $(n)_SFLAGS+=-Iswig/$n))
endif #SWIGARGCARGV

# SWIG warnings
# comparison integer of different signedness
CXXFLAGS_RUBY+=-Wno-sign-compare
# a label defined but not used
CXXFLAGS_PHP+=-Wno-unused-label
# variable defined but not used
CXXFLAGS_PHP+=-Wno-unused-variable
# suppress swig compilation warnings for old swig versions
ifneq ($(call verCheck,$(SWIGVER),4.1),)
# ANYARGS is deprecated (seems related to ruby headers)
CXXFLAGS_RUBY+=-Wno-deprecated-declarations
# label 'thrown' is not used
CXXFLAGS_PHP+=-Wno-unused-label
# 'result' may be used uninitialized
CXXFLAGS_LUA+=-Wno-maybe-uninitialized
ifeq ($(PY_USE_S_THRD),)
# PyEval_InitThreads is deprecated
CXXFLAGS_PY+=-Wno-deprecated-declarations
endif
ifneq ($(call verCheck,$(SWIGVER),4.0),)
# catching polymorphic type 'class std::out_of_range' by value
CXXFLAGS_RUBY+=-Wno-catch-value
# 'argv[1]' may be used uninitialized
CXXFLAGS_RUBY+=-Wno-maybe-uninitialized
# strncpy() specified bound depends on the length of the source argument
CXXFLAGS_PY+=-Wno-stringop-overflow
endif # ! swig 4.0.0
endif # ! swig 4.1.0

%/$(SWIG_NAME).cpp: $(SRC)/$(LIB_NAME).i $(HEADERS)
	$(Q_SWIG)$(SWIG) -c++ -Isrc -I$(@D) -outdir $(@D) -Wextra\
	  $($(@D)_SFLAGS) -o $@ $<
# As SWIG does not create a dependencies file
# We create it during compilation from the compilation dependencies file
SWIG_DEP=$(SED) -e '1 a\ $(SRC)/$(LIB_NAME).i $(SRC)/mngIds.h \\'\
  $(foreach n,$(wildcard $(<D)/*.i),-e '1 a\ $n \\')\
  -e 's@.*\.o:\s*@@;s@\.cpp\s*@.cpp: @' $*.d > $*_i.d
SWIG_LD=$(Q_LD)$(CXX) $(LDFLAGS) -shared $^ $(LOADLIBES) $(LDLIBS)\
  $($@_LDLIBS) -o $@

ifeq ($(SKIP_PERL5),)
include perl/Makefile
endif
ifeq ($(SKIP_LUA),)
include lua/Makefile
endif
ifeq ($(SKIP_PYTHON3),)
include python/Makefile
endif
ifeq ($(SKIP_RUBY),)
include ruby/Makefile
endif
ifeq ($(SKIP_PHP),)
include php/Makefile
endif
ifeq ($(SKIP_TCL),)
include tcl/Makefile
endif

ALL+=$(SWIG_ALL)
endif # SWIGMINVER

ifneq ($(DOXYGENMINVER),)
doxygen: $(HEADERS_GEN) $(HEADERS)
ifeq ($(DOTTOOL),)
	$Q$(info $(COLOR_WARNING)You miss the 'dot' application.$(COLOR_NORM))
	$Q$(SED) -i 's/^\#HAVE_DOT\s.*/HAVE_DOT               = NO/' doxygen.cfg
endif
ifdef Q_DOXY
	$(Q_DOXY)$(DOXYGEN) doxygen.cfg >/dev/null
else
	$(DOXYGEN) doxygen.cfg
endif
ifeq ($(DOTTOOL),)
	$Q$(SED) -i 's/^HAVE_DOT\s.*/\#HAVE_DOT               = YES/' doxygen.cfg
endif
endif # DOXYGENMINVER

checkall: format doxygen

ifneq ($(CTAGS),)
tags: $(filter-out $(SRC)/ids.h,$(HEADERS_GEN_COMP)) $(HEADERS_SRCS) $(SRCS)\
	$(wildcard $(JSON_SRC)/*.cpp)
	$(Q_TAGS)$(CTAGS) -R $^
ALL+=tags
endif # CTAGS

.DEFAULT_GOAL=all
all: $(COMP_DEPS) $(ALL)
	$(NOP)

####### installation #######
URL:=html/index.html
REDIR:="<meta http-equiv=\"refresh\" charset=\"utf-8\" content=\"0; url=$(URL)\"/>"
INSTALL_FOLDER:=$(INSTALL) -d
TOOLS_EXT:=-ptpmgmt
DEV_PKG?=$(LIB_NAME)-dev
DLIBDIR:=$(DESTDIR)$(libdir)
DOCDIR:=$(DESTDIR)$(datarootdir)/doc/$(LIB_NAME)-doc
MANDIR:=$(DESTDIR)$(mandir)/man8
# 1=Dir 2=file 3=link
ifeq ($(USE_FULL_PATH_LINK),)
mkln=$(LN) $2 $(DESTDIR)$1/$3
else
mkln=$(LN) $1/$2 $(DESTDIR)$1/$3
endif

install: $(INS_TGT)
install_main:
	$(Q)for lib in $(LIB_NAME)*.so
	  do $(INSTALL_PROGRAM) -D $$lib $(DLIBDIR)/$$lib.$(PACKAGE_VERSION)
	  $(call mkln,$(libdir),$$lib.$(PACKAGE_VERSION),$$lib$(SONAME))
	  $(call mkln,$(libdir),$$lib$(SONAME),$$lib);done
	$(INSTALL_DATA) $(LIB_NAME)*.a $(DLIBDIR)
	$(INSTALL_DATA) -D $(HEADERS_INST) -t $(DESTDIR)/usr/include/ptpmgmt
	$(foreach f,$(notdir $(HEADERS_INST)),$(SED) -i\
	  's!#include\s*\"\([^"]\+\)\"!#include <ptpmgmt/\1>!'\
	  $(DESTDIR)/usr/include/ptpmgmt/$f;)
	$(INSTALL_DATA) -D scripts/*.mk -t $(DESTDIR)/usr/share/$(DEV_PKG)
	$(INSTALL_PROGRAM) -D $(PMC_NAME) $(DESTDIR)$(sbindir)/pmc$(TOOLS_EXT)
	if [ ! -f $(MANDIR)/pmc$(TOOLS_EXT).8.gz ]
	  then $(INSTALL_DATA) -D man/pmc.8 $(MANDIR)/pmc$(TOOLS_EXT).8
	  gzip $(MANDIR)/pmc$(TOOLS_EXT).8;fi
	$(INSTALL_PROGRAM) -D $(PMC_DIR)/phc_ctl\
	  $(DESTDIR)$(sbindir)/phc_ctl$(TOOLS_EXT)
	if [ ! -f $(MANDIR)/phc_ctl$(TOOLS_EXT).8.gz ]; then
	  $(INSTALL_DATA) -D man/phc_ctl.8 $(MANDIR)/phc_ctl$(TOOLS_EXT).8
	  gzip $(MANDIR)/phc_ctl$(TOOLS_EXT).8;fi
	$(MKDIR_P) "doc/html"
	$(RM) doc/html/*.md5
	$(INSTALL_FOLDER) $(DOCDIR)
	cp -a *.md doc/html $(DOCDIR)
	printf $(REDIR) > $(DOCDIR)/index.html

ifeq ($(filter distclean clean,$(MAKECMDGOALS)),)
include $(D_FILES)
endif

$(OBJ_DIR):
	$Q$(MKDIR_P) "$@"

endif # wildcard defs.mk
###############################################################################

####### Debain build #######
ifneq ($(and $(wildcard debian/rules),$(call which,dpkg-buildpackage)),)
ifneq ($(filter deb_arc,$(MAKECMDGOALS)),)
ifeq ($(DEB_ARC),)
ifneq ($(NONPHONY_TGT),)
ifneq ($(shell dpkg-architecture -qDEB_TARGET_ARCH -a$(NONPHONY_TGT) 2>/dev/null),)
DEB_ARC:=$(NONPHONY_TGT)
$(eval $(call phony,$(DEB_ARC)))
endif # dpkg-architecture -qDEB_TARGET_ARCH
endif # $(NONPHONY_TGT)
endif # $(DEB_ARC)
endif # filter deb_arc,$(MAKECMDGOALS)
deb:
	$(Q)MAKEFLAGS=$(MAKE_NO_DIRS) Q=$Q dpkg-buildpackage -b --no-sign
ifneq ($(DEB_ARC),)
deb_arc:
	$(Q)MAKEFLAGS=$(MAKE_NO_DIRS) Q=$Q dpkg-buildpackage -B --no-sign\
	  -a$(DEB_ARC)
endif
deb_clean:
	$Q$(MAKE) $(MAKE_NO_DIRS) -f debian/rules deb_clean Q=$Q
endif # and wildcard debian/rules, which dpkg-buildpackage

####### library code only #######
LIB_SRC:=$(SRC_NAME).txz
$(LIB_SRC): $(SRC_FILES)
	$(Q_TAR)$(TAR) $@ $^ --transform "s#^#$(SRC_NAME)/#S"
srcpkg: $(LIB_SRC)

####### RPM build #######
ifneq ($(call which,rpmbuild),)
rpm/SOURCES:
	$(Q)mkdir -p "$@"
rpm: $(LIB_SRC) rpm/SOURCES
	$(Q)cp $(LIB_SRC) rpm/SOURCES/
	$(Q)rpmbuild --define "_topdir $(PWD)/rpm" -bb rpm/$(LIB_NAME).spec
endif # which rpmbuild

####### Arch Linux build #######
ifneq ($(call which,makepkg),)
ARCHL_BLD:=archlinux/PKGBUILD
$(ARCHL_BLD): $(ARCHL_BLD).org | $(LIB_SRC)
	$(Q)cp $^ $@
	cp $(LIB_SRC) archlinux/
	printf "sha256sums=('%s')\n"\
	  $(firstword $(shell sha256sum $(LIB_SRC))) >> $@
pkg: $(ARCHL_BLD)
	$(Q)cd archlinux && makepkg
endif # which makepkg

####### Gentoo build #######
ifneq ($(call which,ebuild),)
gentoo: $(LIB_SRC)
	$(Q)gentoo/build.sh
endif # which ebuild

####### Generic rules #######

ifeq ($(filter distclean,$(MAKECMDGOALS)),)
configure: configure.ac
	$(Q)autoconf
# Debian default configuration
ifneq ($(call which,dh_auto_configure),)
HAVE_CONFIG_GAOL:=1
config: configure
	$(Q)dh_auto_configure
endif # which,dh_auto_configure
ifeq ($(HAVE_CONFIG_GAOL),)
ifneq ($(call which,rpm),)
rpm_list!=rpm -qa 2>/dev/null
ifneq ($(rpm_list),)
# Default configuration on RPM based distributions
HAVE_CONFIG_GAOL:=1
config: configure
	$(Q)`rpm --eval %configure | sed -ne '/^\s*.\/configure/,$$ p'`
endif # rpm_list
endif # which rpm
endif # HAVE_CONFIG_GAOL
ifeq ($(HAVE_CONFIG_GAOL),)
ifneq ($(wildcard /usr/share/pacman/PKGBUILD.proto),)
# Default configuration on Arch Linux
HAVE_CONFIG_GAOL:=1
config: configure
	$(Q)`grep configure /usr/share/pacman/PKGBUILD.proto`
endif # wildcard pacman/PKGBUILD.proto
endif # HAVE_CONFIG_GAOL
endif # filter distclean,MAKECMDGOALS

ifeq ($(filter help distclean clean,$(MAKECMDGOALS)),)
ifneq ($(wildcard config.status),)
config.status: configure
	$(Q)./config.status --recheck

defs.mk: defs.mk.in config.status
	$(Q)./config.status
endif # config.status
endif # MAKECMDGOALS

CLEAN:=$(wildcard */*.o */*/*.o */$(SWIG_NAME).cpp archlinux/*.pkg.tar.zst\
  $(LIB_NAME)*.so $(LIB_NAME)*.a $(LIB_NAME)*.so.$(ver_maj) */*.so */*/*.so\
  python/*.pyc php/*.h php/*.ini perl/*.pm) $(D_FILES) $(LIB_SRC)\
  $(ARCHL_BLD) tags python/ptpmgmt.py $(PHP_LNAME).php $(PMC_NAME)\
  tcl/pkgIndex.tcl php/.phpunit.result.cache .phpunit.result.cache\
  $(HEADERS_GEN)
CLEAN_DIRS:=$(filter %/, $(wildcard lua/*/ python/*/ rpm/*/\
  archlinux/*/)) doc $(OBJ_DIR) perl/auto
DISTCLEAN:=$(foreach n, log status,config.$n) configure configure~ defs.mk
DISTCLEAN_DIRS:=autom4te.cache

clean: deb_clean
	$(Q_CLEAN)$(RM) $(CLEAN)
	$(RM) -R $(CLEAN_DIRS)
distclean: deb_clean
	$(Q_DISTCLEAN)$(RM) $(CLEAN) $(DISTCLEAN)
	$(RM) -R $(CLEAN_DIRS) $(DISTCLEAN_DIRS)

help:
	$(NOP)$(info $(help))
