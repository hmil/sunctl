include env.make

NODEMCU-COMMAND=$(NODEMCU-UPLOADER) -b $(SPEED) --start_baud $(SPEED) -p $(PORT)

LUA_FILES := $(wildcard *.lua)

.PHONY: clean
clean:
	$(NODEMCU-COMMAND) file format

.PHONY: list
list:
	$(NODEMCU-COMMAND) file list

.PHONY: restart
restart:
	$(NODEMCU-COMMAND) node restart

.PHONY: upload
upload: $(LUA_FILES)
	$(NODEMCU-COMMAND) upload $(foreach f, $^, $(f))

.PHONY: flash
flash:
	# Erase flash to avoid inconsistent state:
	esptool.py --port $(PORT) erase_flash
	# Upload firmware
	esptool.py --port $(PORT) write_flash -fm dio 0x00000 nodemcu_float_master_20190331-1807.bin
