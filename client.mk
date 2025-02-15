# -*- makefile -*-
# vim:set ts=8 sw=8 sts=8 noet:
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Defines main targets for driving the Firefox build system.
#
# This make file should not be invoked directly. Instead, use
# `mach` (likely `mach build`) for invoking the build system.
#
# Options:
#   MOZ_OBJDIR           - Destination object directory
#   MOZ_MAKE_FLAGS       - Flags to pass to $(MAKE)
#
#######################################################################
# Defines

ifdef MACH
ifndef NO_BUILDSTATUS_MESSAGES
define BUILDSTATUS
@echo 'BUILDSTATUS $1'

endef
endif
endif


CWD := $(CURDIR)

ifeq "$(CWD)" "/"
CWD   := /.
endif

ifndef TOPSRCDIR
ifeq (,$(wildcard client.mk))
TOPSRCDIR := $(patsubst %/,%,$(dir $(MAKEFILE_LIST)))
else
TOPSRCDIR := $(CWD)
endif
endif

PYTHON ?= $(shell which python2.7 > /dev/null 2>&1 && echo python2.7 || echo python)

CONFIG_GUESS := $(shell $(TOPSRCDIR)/build/autoconf/config.guess)

####################################
# Sanity checks

# Windows checks.
ifneq (,$(findstring mingw,$(CONFIG_GUESS)))

# Set this for baseconfig.mk
HOST_OS_ARCH=WINNT
endif

####################################
# Load mozconfig Options

# See build pages, http://www.mozilla.org/build/ for how to set up mozconfig.

define CR


endef

# As $(shell) doesn't preserve newlines, use sed to replace them with an
# unlikely sequence (||), which is then replaced back to newlines by make
# before evaluation. $(shell) replacing newlines with spaces, || is always
# followed by a space (since sed doesn't remove newlines), except on the
# last line, so replace both '|| ' and '||'.
MOZCONFIG_CONTENT := $(subst ||,$(CR),$(subst || ,$(CR),$(shell $(TOPSRCDIR)/mach environment --format=client.mk | sed 's/$$/||/')))
$(eval $(MOZCONFIG_CONTENT))

export FOUND_MOZCONFIG

# As '||' was used as a newline separator, it means it's not occurring in
# lines themselves. It can thus safely be used to replaces normal spaces,
# to then replace newlines with normal spaces. This allows to get a list
# of mozconfig output lines.
MOZCONFIG_OUT_LINES := $(subst $(CR), ,$(subst $(NULL) $(NULL),||,$(MOZCONFIG_CONTENT)))
# Filter-out comments from those lines.
START_COMMENT = \#
MOZCONFIG_OUT_FILTERED := $(filter-out $(START_COMMENT)%,$(MOZCONFIG_OUT_LINES))

ifdef AUTOCLOBBER
export AUTOCLOBBER=1
endif

ifdef MOZ_PARALLEL_BUILD
  MOZ_MAKE_FLAGS := $(filter-out -j%,$(MOZ_MAKE_FLAGS))
  MOZ_MAKE_FLAGS += -j$(MOZ_PARALLEL_BUILD)
endif

# Automatically add -jN to make flags if not defined. N defaults to number of cores.
ifeq (,$(findstring -j,$(MOZ_MAKE_FLAGS)))
  cores=$(shell $(PYTHON) -c 'import multiprocessing; print(multiprocessing.cpu_count())')
  MOZ_MAKE_FLAGS += -j$(cores)
endif

ifdef MOZ_AUTOMATION
ifeq (4.0,$(firstword $(sort 4.0 $(MAKE_VERSION))))
MOZ_MAKE_FLAGS += --output-sync=line
endif
endif

MOZ_MAKE = $(MAKE) $(MOZ_MAKE_FLAGS) -C $(OBJDIR)

# 'configure' scripts generated by autoconf.
CONFIGURES := $(TOPSRCDIR)/configure
CONFIGURES += $(TOPSRCDIR)/js/src/configure

# Make targets that are going to be passed to the real build system
OBJDIR_TARGETS = install export libs clean realclean distclean upload sdk installer package package-compare stage-package source-package l10n-check automation/build

#######################################################################
# Rules

# The default rule is build
build::

ifndef MACH
$(error client.mk must be used via `mach`. Try running \
`./mach $(firstword $(MAKECMDGOALS) $(.DEFAULT_GOAL))`)
endif

# Include baseconfig.mk for its $(MAKE) validation.
include $(TOPSRCDIR)/config/baseconfig.mk

# Define mkdir
include $(TOPSRCDIR)/config/makefiles/makeutils.mk
include $(TOPSRCDIR)/config/makefiles/autotargets.mk

# For now, only output "export" lines and lines containing UPLOAD_EXTRA_FILES
# from mach environment --format=client.mk output.
MOZCONFIG_MK_LINES := $(filter export||% UPLOAD_EXTRA_FILES% %UPLOAD_EXTRA_FILES%,$(MOZCONFIG_OUT_LINES))
$(OBJDIR)/.mozconfig.mk: $(TOPSRCDIR)/client.mk $(FOUND_MOZCONFIG) $(call mkdir_deps,$(OBJDIR)) $(OBJDIR)/CLOBBER
	$(if $(MOZCONFIG_MK_LINES),( $(foreach line,$(MOZCONFIG_MK_LINES), echo '$(subst ||, ,$(line))';) )) > $@

# Include that makefile so that it is created. This should not actually change
# the environment since MOZCONFIG_CONTENT, which MOZCONFIG_OUT_LINES derives
# from, has already been eval'ed.
include $(OBJDIR)/.mozconfig.mk

# Print out any options loaded from mozconfig.
all build clean distclean export libs install realclean::
ifneq (,$(strip $(MOZCONFIG_OUT_FILTERED)))
	$(info Adding client.mk options from $(FOUND_MOZCONFIG):)
	$(foreach line,$(MOZCONFIG_OUT_FILTERED),$(info $(NULL) $(NULL) $(NULL) $(NULL) $(subst ||, ,$(line))))
endif

# helper target for mobile
build_and_deploy: build package install

# In automation, manage an sccache daemon. The starting of the server
# needs to be in a make file so sccache inherits the jobserver.
ifdef MOZBUILD_MANAGE_SCCACHE_DAEMON
build::
	# Terminate any sccache server that might still be around.
	-$(MOZBUILD_MANAGE_SCCACHE_DAEMON) --stop-server > /dev/null 2>&1
	# Start a new server, ensuring it gets the jobserver file descriptors
	# from make (but don't use the + prefix when make -n is used, so that
	# the command doesn't run in that case)
	$(if $(findstring n,$(filter-out --%, $(MAKEFLAGS))),,+)env RUST_LOG=sccache::compiler=debug SCCACHE_ERROR_LOG=$(OBJDIR)/dist/sccache.log $(MOZBUILD_MANAGE_SCCACHE_DAEMON) --start-server
endif

####################################
# Configure

MAKEFILE      = $(wildcard $(OBJDIR)/Makefile)
CONFIG_STATUS = $(wildcard $(OBJDIR)/config.status)

EXTRA_CONFIG_DEPS := \
  $(TOPSRCDIR)/aclocal.m4 \
  $(TOPSRCDIR)/old-configure.in \
  $(wildcard $(TOPSRCDIR)/build/autoconf/*.m4) \
  $(TOPSRCDIR)/js/src/aclocal.m4 \
  $(TOPSRCDIR)/js/src/old-configure.in \
  $(NULL)

$(CONFIGURES): %: %.in $(EXTRA_CONFIG_DEPS)
	@echo Generating $@
	cp -f $< $@
	chmod +x $@

CONFIG_STATUS_DEPS := \
  $(wildcard $(TOPSRCDIR)/*/confvars.sh) \
  $(CONFIGURES) \
  $(TOPSRCDIR)/CLOBBER \
  $(TOPSRCDIR)/nsprpub/configure \
  $(TOPSRCDIR)/config/milestone.txt \
  $(TOPSRCDIR)/browser/config/version.txt \
  $(TOPSRCDIR)/browser/config/version_display.txt \
  $(TOPSRCDIR)/build/virtualenv_packages.txt \
  $(TOPSRCDIR)/python/mozbuild/mozbuild/virtualenv.py \
  $(TOPSRCDIR)/testing/mozbase/packages.txt \
  $(OBJDIR)/.mozconfig.json \
  $(NULL)

# Include a dep file emitted by configure to track Python files that
# may influence the result of configure.
-include $(OBJDIR)/configure.d

CONFIGURE_ENV_ARGS += \
  MAKE='$(MAKE)' \
  $(NULL)

# configure uses the program name to determine @srcdir@. Calling it without
#   $(TOPSRCDIR) will set @srcdir@ to "."; otherwise, it is set to the full
#   path of $(TOPSRCDIR).
ifeq ($(TOPSRCDIR),$(OBJDIR))
  CONFIGURE = ./configure
else
  CONFIGURE = $(TOPSRCDIR)/configure
endif

$(OBJDIR)/CLOBBER: $(TOPSRCDIR)/CLOBBER
	$(PYTHON) $(TOPSRCDIR)/config/pythonpath.py -I $(TOPSRCDIR)/testing/mozbase/mozfile \
	    $(TOPSRCDIR)/python/mozbuild/mozbuild/controller/clobber.py $(TOPSRCDIR) $(OBJDIR)

configure-files: $(CONFIGURES)

configure-preqs = \
  $(OBJDIR)/CLOBBER \
  configure-files \
  $(call mkdir_deps,$(OBJDIR)) \
  save-mozconfig \
  $(OBJDIR)/.mozconfig.json \
  $(NULL)

CREATE_MOZCONFIG_JSON = $(shell $(TOPSRCDIR)/mach environment --format=json -o $(OBJDIR)/.mozconfig.json)
# Force CREATE_MOZCONFIG_JSON above to be resolved, without side effects in
# case the result is non empty, and allowing an override on the make command
# line not running the command (using := $(shell) still runs the shell command).
ifneq (,$(CREATE_MOZCONFIG_JSON))
endif

$(OBJDIR)/.mozconfig.json: $(call mkdir_deps,$(OBJDIR)) ;

save-mozconfig: $(FOUND_MOZCONFIG)
ifdef FOUND_MOZCONFIG
	-cp $(FOUND_MOZCONFIG) $(OBJDIR)/.mozconfig
endif

configure:: $(configure-preqs)
	$(call BUILDSTATUS,TIERS configure)
	$(call BUILDSTATUS,TIER_START configure)
	@echo cd $(OBJDIR);
	@echo $(CONFIGURE) $(CONFIGURE_ARGS)
	@cd $(OBJDIR) && $(BUILD_PROJECT_ARG) $(CONFIGURE_ENV_ARGS) $(CONFIGURE) $(CONFIGURE_ARGS) \
	  || ( echo '*** Fix above errors and then restart with\
               "$(MAKE) -f client.mk build"' && exit 1 )
	@touch $(OBJDIR)/Makefile
	$(call BUILDSTATUS,TIER_FINISH configure)

ifneq (,$(MAKEFILE))
$(OBJDIR)/Makefile: $(OBJDIR)/config.status

$(OBJDIR)/config.status: $(CONFIG_STATUS_DEPS)
else
$(OBJDIR)/Makefile: $(CONFIG_STATUS_DEPS)
endif
	@$(MAKE) -f $(TOPSRCDIR)/client.mk configure CREATE_MOZCONFIG_JSON=

ifneq (,$(CONFIG_STATUS))
$(OBJDIR)/config/autoconf.mk: $(TOPSRCDIR)/config/autoconf.mk.in
	$(PYTHON) $(OBJDIR)/config.status -n --file=$(OBJDIR)/config/autoconf.mk
endif

####################################
# Build it

build::  $(OBJDIR)/Makefile $(OBJDIR)/config.status
	+$(MOZ_MAKE)

####################################
# Other targets

# Pass these target onto the real build system
$(OBJDIR_TARGETS):: $(OBJDIR)/Makefile $(OBJDIR)/config.status
	+$(MOZ_MAKE) $@

ifdef MOZ_AUTOMATION
build::
	$(MAKE) -f $(TOPSRCDIR)/client.mk automation/build
endif

ifdef MOZBUILD_MANAGE_SCCACHE_DAEMON
build::
	# Terminate sccache server. This prints sccache stats.
	-$(MOZBUILD_MANAGE_SCCACHE_DAEMON) --stop-server
endif

# This makefile doesn't support parallel execution. It does pass
# MOZ_MAKE_FLAGS to sub-make processes, so they will correctly execute
# in parallel.
.NOTPARALLEL:

.PHONY: \
    build \
    configure \
    $(OBJDIR_TARGETS)
