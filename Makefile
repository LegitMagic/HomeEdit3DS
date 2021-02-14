#---------------------------------------------------------------------------------
.SUFFIXES:
#---------------------------------------------------------------------------------

ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=<path to>devkitARM")
endif

TOPDIR ?= $(CURDIR)
include $(DEVKITARM)/3ds_rules

#---------------------------------------------------------------------------------
# TARGET is the name of the output
# BUILD is the directory where object files & intermediate files will be placed
# SOURCES is a list of directories containing source code
# DATA is a list of directories containing data files
# INCLUDES is a list of directories containing header files
# GRAPHICS is a list of directories containing graphics files
# GFXBUILD is the directory where converted graphics files will be placed
#   If set to $(BUILD), it will statically link in the converted
#   files as if they were data files.
#
# NO_SMDH: if set to anything, no SMDH file is generated.
# ROMFS is the directory which contains the RomFS, relative to the Makefile (Optional)
# APP_TITLE is the name of the app stored in the SMDH file (Optional)
# APP_DESCRIPTION is the description of the app stored in the SMDH file (Optional)
# APP_AUTHOR is the author of the app stored in the SMDH file (Optional)
# ICON is the filename of the icon (.png), relative to the project folder.
#   If not set, it attempts to use one of the following (in this order):
#     - <Project name>.png
#     - icon.png
#     - <libctru folder>/default_icon.png
#---------------------------------------------------------------------------------

APP_TITLE := Home Editor WIP
TARGET    := 3ds/hedit
BUILD     := 3ds/build
SOURCES   += source/imgui
SOURCES  := source source/3ds source/imgui
DATA     := data
GRAPHICS  := 3ds/gfx
ROMFS     := 3ds/romfs
GFXBUILD  := $(ROMFS)
RSF_FILE  := meta/cia.rsf

#GITREV  := $(shell git rev-parse HEAD 2>/dev/null | cut -c1-6)
VERSION_MAJOR := 1
VERSION_MINOR := 0
VERSION_MICRO := 0
VERSION := $(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_MICRO)

APP_DESCRIPTION := v$(VERSION)
APP_AUTHOR      := Legit_Magic

ICON      := meta/icon.png
BNR_IMAGE := meta/banner.png
BNR_AUDIO := meta/audio.wav

#---------------------------------------------------------------------------------
# options for code generation
#---------------------------------------------------------------------------------
OPTIMIZE := -Og
ARCH     := -march=armv6k -mtune=mpcore -mfloat-abi=hard -mtp=soft

CFLAGS   := -g -Wall $(OPTIMIZE) -mword-relocations \
            -fomit-frame-pointer -ffunction-sections -fdata-sections \
            $(ARCH) $(DEFINES) $(CLASSIC)

CFLAGS   +=  $(INCLUDE) -DARM11 -D_3DS \
            -DSTATUS_STRING="\"ftpd v$(VERSION)\"" \
            -DIMGUI_DISABLE_INCLUDE_IMCONFIG_H=1 \
            -DNO_IPV6 -DFTPDCONFIG="\"/config/ftpd/ftpd.cfg\"" \
            -DANTI_ALIAS=1

CXXFLAGS := $(CFLAGS) -fno-rtti -fno-exceptions -std=gnu++17

ASFLAGS  := -g $(ARCH)
LDFLAGS   = -specs=3dsx.specs -g $(ARCH) -Wl,-Map,$(notdir $*.map) $(OPTIMIZE)

CC  := `which ccache 2>/dev/null` $(CC)
CXX := `which ccache 2>/dev/null` $(CXX)

LIBS     := -lcitro3d -lctru -lm

#---------------------------------------------------------------------------------
# list of directories containing libraries, this must be the top level containing
# include and lib
#---------------------------------------------------------------------------------
LIBDIRS  := $(CTRULIB)


#---------------------------------------------------------------------------------
# no real need to edit anything past this point unless you need to add additional
# rules for different file extensions
#---------------------------------------------------------------------------------
ifneq ($(TOPDIR)/$(BUILD),$(CURDIR))
#---------------------------------------------------------------------------------

export OUTPUT  :=  $(CURDIR)/$(TARGET)
export TOPDIR  :=  $(CURDIR)

export VPATH   :=  $(foreach dir,$(SOURCES),$(CURDIR)/$(dir)) \
                   $(foreach dir,$(GRAPHICS),$(CURDIR)/$(dir)) \
                   $(foreach dir,$(DATA),$(CURDIR)/$(dir))

export DEPSDIR :=  $(CURDIR)/$(BUILD)

CFILES      := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.c)))
CPPFILES    := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.cpp)))
SFILES      := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.s)))
SHLISTFILES := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.shlist)))
GFXFILES    := $(foreach dir,$(GRAPHICS),$(notdir $(wildcard $(dir)/*.t3s)))
BINFILES    := $(foreach dir,$(DATA),$(notdir $(wildcard $(dir)/*.*)))

ifeq ($(strip $(CLASSIC)),)
PICAFILES   := $(foreach dir,$(SOURCES),$(notdir $(wildcard $(dir)/*.v.pica)))
endif

#---------------------------------------------------------------------------------
# use CXX for linking C++ projects, CC for standard C
#---------------------------------------------------------------------------------
ifeq ($(strip $(CPPFILES)),)
  export LD := $(CC)
else
  export LD := $(CXX)
endif
#---------------------------------------------------------------------------------

#---------------------------------------------------------------------------------
ifeq ($(GFXBUILD),$(BUILD))
#---------------------------------------------------------------------------------
export T3XFILES :=  $(GFXFILES:.t3s=.t3x)
#---------------------------------------------------------------------------------
else
#---------------------------------------------------------------------------------
export ROMFS_T3XFILES := $(patsubst %.t3s,$(GFXBUILD)/%.t3x,$(GFXFILES))
export T3XHFILES      := $(patsubst %.t3s,$(BUILD)/%.h,$(GFXFILES))
#---------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------

export OFILES_SOURCES := $(CPPFILES:.cpp=.o) $(CFILES:.c=.o) $(SFILES:.s=.o)

export OFILES_BIN     := $(addsuffix .o,$(BINFILES)) \
                         $(PICAFILES:.v.pica=.shbin.o) $(SHLISTFILES:.shlist=.shbin.o) \
                         $(addsuffix .o,$(T3XFILES))

export OFILES    := $(OFILES_BIN) $(OFILES_SOURCES)

export HFILES    := $(PICAFILES:.v.pica=_shbin.h) $(SHLISTFILES:.shlist=_shbin.h) \
                    $(addsuffix .h,$(subst .,_,$(BINFILES))) \
                    $(GFXFILES:.t3s=.h)

export INCLUDE   := $(foreach dir,$(INCLUDES),-I$(CURDIR)/$(dir)) \
                    $(foreach dir,$(LIBDIRS),-I$(dir)/include) \
                    -I$(CURDIR)/$(BUILD)

export LIBPATHS  :=  $(foreach dir,$(LIBDIRS),-L$(dir)/lib)

export _3DSXDEPS := $(if $(NO_SMDH),,$(OUTPUT).smdh)

ifeq ($(strip $(ICON)),)
  icons := $(wildcard *.png)
  ifneq (,$(findstring $(TARGET).png,$(icons)))
    export APP_ICON := $(TOPDIR)/$(TARGET).png
  else
    ifneq (,$(findstring icon.png,$(icons)))
      export APP_ICON := $(TOPDIR)/icon.png
    endif
  endif
else
  export APP_ICON := $(TOPDIR)/$(ICON)
endif

ifeq ($(strip $(NO_SMDH)),)
  export _3DSXFLAGS += --smdh=$(CURDIR)/$(TARGET).smdh
endif

ifneq ($(ROMFS),)
  export _3DSXFLAGS += --romfs=$(CURDIR)/$(ROMFS)
endif

.PHONY: $(BUILD) clean all 3dsx cia 3dslink

#---------------------------------------------------------------------------------
all: $(BUILD) $(GFXBUILD) $(DEPSDIR) $(ROMFS_T3XFILES) $(T3XHFILES)
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile

$(BUILD):
	@mkdir -p $@

ifneq ($(GFXBUILD),$(BUILD))
$(GFXBUILD):
	@mkdir -p $@
endif

ifneq ($(DEPSDIR),$(BUILD))
$(DEPSDIR):
	mkdir -p $@
endif

#---------------------------------------------------------------------------------
$(GFXBUILD)/%.t3x $(BUILD)/%.h: %.t3s
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	tex3ds -i $< -H $(BUILD)/$*.h -d $(DEPSDIR)/$*.d -o $(GFXBUILD)/$*.t3x

3dsx: $(BUILD) $(GFXBUILD) $(DEPSDIR) $(ROMFS_T3XFILES) $(T3XHFILES)
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile 3dsx

cia: $(BUILD) $(GFXBUILD) $(DEPSDIR) $(ROMFS_T3XFILES) $(T3XHFILES)
	@$(MAKE) --no-print-directory -C $(BUILD) -f $(CURDIR)/Makefile cia

3dslink: 3dsx
	@3dslink $(OUTPUT).3dsx

#---------------------------------------------------------------------------------
clean:
	@echo clean ...
	@$(RM) -r $(BUILD) \
		$(TARGET).3dsx \
		$(OUTPUT).smdh \
		$(TARGET).elf \
		$(TARGET).cia \
		$(ROMFS_T3XFILES) \
		output/ 

#---------------------------------------------------------------------------------
else
#---------------------------------------------------------------------------------
# main targets
#---------------------------------------------------------------------------------
all: $(OUTPUT).cia $(OUTPUT).3dsx

3dsx: $(OUTPUT).3dsx

cia: $(OUTPUT).cia

ifeq ($(strip $(NO_SMDH)),)
.PHONY: all
all:            $(OUTPUT).3dsx $(OUTPUT).smdh
$(OUTPUT).smdh: $(TOPDIR)/Makefile
$(OUTPUT).3dsx: $(OUTPUT).smdh
endif

$(OUTPUT).3dsx: $(OUTPUT).elf $(_3DSXDEPS)

$(OFILES_SOURCES): $(HFILES)

$(OUTPUT).elf:  $(OFILES)

#---------------------------------------------------------------------------------
# you need a rule like this for each extension you use as binary data
#---------------------------------------------------------------------------------
%.bin.o %_bin.h: %.bin
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	@$(bin2o)

$(OFILES): $(TOPDIR)/Makefile

#---------------------------------------------------------------------------------
.PRECIOUS: %.t3x
#---------------------------------------------------------------------------------
%.t3x.o %_t3x.h: %.t3x
#---------------------------------------------------------------------------------
	@echo $(notdir $<)
	@$(bin2o)

#---------------------------------------------------------------------------------
# rules for assembling GPU shaders
#---------------------------------------------------------------------------------
define shader-as
	$(eval CURBIN := $*.shbin)
	$(eval DEPSFILE := $(DEPSDIR)/$*.shbin.d)
	echo "$(CURBIN).o: $< $1" > $(DEPSFILE)
	echo "extern const u8" `(echo $(CURBIN) | sed -e 's/^\([0-9]\)/_\1/' | tr . _)`"_end[];" > `(echo $(CURBIN) | tr . _)`.h
	echo "extern const u8" `(echo $(CURBIN) | sed -e 's/^\([0-9]\)/_\1/' | tr . _)`"[];" >> `(echo $(CURBIN) | tr . _)`.h
	echo "extern const u32" `(echo $(CURBIN) | sed -e 's/^\([0-9]\)/_\1/' | tr . _)`_size";" >> `(echo $(CURBIN) | tr . _)`.h
	picasso -o $(CURBIN) $1
	bin2s $(CURBIN) | $(AS) -o $*.shbin.o
endef

%.shbin.o %_shbin.h : %.v.pica %.g.pica
	@echo $(notdir $^)
	@$(call shader-as,$^)

%.shbin.o %_shbin.h : %.v.pica
	@echo $(notdir $<)
	@$(call shader-as,$<)

%.shbin.o %_shbin.h : %.shlist
	@echo $(notdir $<)
	@$(call shader-as,$(foreach file,$(shell cat $<),$(dir $<)$(file)))

$(OUTPUT).cia:  $(OUTPUT).elf $(OUTPUT).smdh $(TARGET).bnr $(TOPDIR)/$(RSF_FILE)
	@makerom -f cia -target t -exefslogo -o $@ \
	  -elf $(OUTPUT).elf -rsf $(TOPDIR)/$(RSF_FILE) \
	  -ver "$$(($(VERSION_MAJOR)*1024+$(VERSION_MINOR)*16+$(VERSION_MICRO)))" \
	  -banner $(TARGET).bnr \
	  -icon $(OUTPUT).smdh
	@echo "built ... $(notdir $@)"

$(TARGET).bnr:  $(TOPDIR)/$(BNR_IMAGE) $(TOPDIR)/$(BNR_AUDIO)
	@[ -d $(dir $@) ] || mkdir -p $(dir $@)
	@bannertool makebanner -o $@ -i $(TOPDIR)/$(BNR_IMAGE) -a $(TOPDIR)/$(BNR_AUDIO)
	@echo "built ... $@"


-include $(DEPSDIR)/*.d

#---------------------------------------------------------------------------------------
endif
#---------------------------------------------------------------------------------------
