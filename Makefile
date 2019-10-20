
IN_DIR := in
OUT_DIR := out
TMP_DIR := tmp

JQ_FILTER_DIR := jq/filter
JQ_FILTER_FILE = $(JQ_FILTER_DIR)/$(1).jq
JQ_FILTERS := $(foreach _,$(wildcard $(JQ_FILTER_DIR)/*),$(patsubst $(JQ_FILTER_DIR)/%.jq,%,$(_)))

EXAMPLE_COLLECT_FILES := $(foreach _,$(wildcard $(IN_DIR)/entity/*.yaml),$(patsubst $(IN_DIR)/%.yaml,$(TMP_DIR)/%.json,$(_)))

COLLECTED_FILE = $(TMP_DIR)/$(1).collected.json
FILTERED_FILE = $(patsubst %.json,%.filtered.json,$(call COLLECTED_FILE,$(1)))

PRINT = @echo -e '\033[1;35m$(1)\033[0m'
TO_NAME = $(shell echo '$(1)' | sed -e 's/[^0-1a-zA-Z]/_/g')
TO_SHORT_NAME = $(call TO_NAME,$(call TRIM_EXT,$(call TRIM_DIR,$(1))))
TO_UPPER = $(shell echo '$(1)' | sed -e 's/\(.*\)/\U\1/')
TO_UPPER_NAME = $(call TO_NAME,$(call TO_UPPER,$(1)))
TRIM_DIR = $(shell echo '$(1)' | sed -e 's|.*/||g')
TRIM_EXT = $(shell echo '$(1)' | sed -e 's|\..*||g')

.PHONY: all
all: $(foreach _,$(JQ_FILTERS),$(OUT_DIR)/$(_).yaml)

$(OUT_DIR)/%.yaml: $(patsubst %.json,%.yaml,$(call FILTERED_FILE,%))
	$(call PRINT,$@: Copying...)
	mkdir -p $(@D)
	cp -f $< $@

define FILTER_RULE
$(call FILTERED_FILE,$(1)): $(call COLLECTED_FILE,$(1)) $(call JQ_FILTER_FILE,$(1))
	$$(call PRINT,$$@: Filtering...)
	jq \
		--sort-keys \
		"$$$$(cat $(call JQ_FILTER_FILE,$(1)))" \
		$$< \
		> $$@.tmp
	mv -f $$@.tmp $$@

endef
$(eval $(foreach _,$(JQ_FILTERS),$(call FILTER_RULE,$(_))))

define COLLECT_RULE
$(call COLLECTED_FILE,$(1)): $($(call TO_UPPER_NAME,$(1))_COLLECT_FILES)
	$$(call PRINT,$$@: Collecting...)
	mkdir -p $$(@D)
	jq \
		--null-input \
		--sort-keys \
		$(foreach _,$($(call TO_UPPER_NAME,$(1))_COLLECT_FILES),--slurpfile $(call TO_SHORT_NAME,$(_)) $(_)) \
		'{ $(foreach _,$($(call TO_UPPER_NAME,$(1))_COLLECT_FILES),$(call TO_SHORT_NAME,$(_)): $$$$$(call TO_SHORT_NAME,$(_))[0],) }' \
		> $$@.tmp
	mv -f $$@.tmp $$@

endef
$(eval $(foreach _,$(JQ_FILTERS),$(call COLLECT_RULE,$(_))))

$(TMP_DIR)/%.yaml: $(TMP_DIR)/%.json
	$(call PRINT,$@: Converting to YAML...)
	yq -y . $< > $@.tmp
	mv -f $@.tmp $@

$(TMP_DIR)/%.json: $(IN_DIR)/%.yaml
	$(call PRINT,$@: Converting from YAML...)
	mkdir -p $(@D)
	yq . $< > $@.tmp
	mv -f $@.tmp $@

$(TMP_DIR)/%: $(IN_DIR)/%
	$(call PRINT,$@: Copying...)
	mkdir -p $(@D)
	cp -f $< $@

.PHONY: clean
clean:
	$(call PRINT,Cleaning...)
	rm -rf $(OUT_DIR) $(TMP_DIR)

