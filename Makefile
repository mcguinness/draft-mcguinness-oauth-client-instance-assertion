MOVED_DRAFTS := draft-mcguinness-oauth-client-attesters \
               draft-mcguinness-oauth-client-instance-id
GHPAGES_EXTRA += $(addsuffix .html,$(MOVED_DRAFTS))

LIBDIR := lib
-include $(LIBDIR)/main.mk

$(LIBDIR)/main.mk:
ifneq (,$(shell grep "path *= *$(LIBDIR)" .gitmodules 2>/dev/null))
	git submodule sync
	git submodule update --init
else
ifneq (,$(wildcard $(ID_TEMPLATE_HOME)))
	ln -s "$(ID_TEMPLATE_HOME)" $(LIBDIR)
else
	git clone -q --depth 10 -b main \
	    https://github.com/martinthomson/i-d-template $(LIBDIR)
endif
endif

# Preserve existing editor-copy URLs after the drafts move repositories.
$(addsuffix .html,$(MOVED_DRAFTS)): %.html: docs/%.html
	cp $< $@
