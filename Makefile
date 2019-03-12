include platform.mk

LUA_CLIB_PATH ?= luaclib
CSERVICE_PATH ?= cservice
RS232_CLIB_PATH ?= luaclib/rs232

SKYNET_BUILD_PATH ?= .

CFLAGS = -g -O2 -Wall -I$(LUA_INC) $(MYCFLAGS)
# CFLAGS += -DUSE_PTHREAD_LOCK

# lua

LUA_STATICLIB := 3rd/lua/liblua.a
LUA_LIB ?= $(LUA_STATICLIB)
LUA_INC ?= 3rd/lua

$(LUA_STATICLIB) :
	cd 3rd/lua && $(MAKE) CC='$(CC) -std=gnu99' $(PLAT)

# jemalloc 

JEMALLOC_STATICLIB := 3rd/jemalloc/lib/libjemalloc_pic.a
JEMALLOC_INC := 3rd/jemalloc/include/jemalloc

all : jemalloc
	
.PHONY : jemalloc update3rd

MALLOC_STATICLIB := $(JEMALLOC_STATICLIB)

$(JEMALLOC_STATICLIB) : 3rd/jemalloc/Makefile
	cd 3rd/jemalloc && $(MAKE) CC=$(CC) 

3rd/jemalloc/autogen.sh :
	git submodule update --init

3rd/jemalloc/Makefile : | 3rd/jemalloc/autogen.sh
	cd 3rd/jemalloc && ./autogen.sh --with-jemalloc-prefix=je_ --disable-valgrind

jemalloc : $(MALLOC_STATICLIB)

update3rd :
	rm -rf 3rd/jemalloc && git submodule update --init

# skynet

CSERVICE = snlua logger gate harbor
LUA_CLIB = skynet \
  client \
  bson md5 sproto lpeg \
  \

LUA_EX_CLIB = \
  lfs cjson iconv \
  rs232/core mosquitto \
  lcurl zlib lsocket \
  \

ICONV_LIBS :=
ifeq ($(PLAT),openwrt)
	ICONV_LIBS := -liconv -L/usr/lib/libiconv-full-full/lib
else
ifeq ($(PLAT),android)
	ICONV_LIBS := -liconv
else
	LUA_EX_CLIB += enet libmodbus
endif
endif

LUA_CLIB_SKYNET = \
  lua-skynet.c lua-seri.c \
  lua-socket.c \
  lua-mongo.c \
  lua-netpack.c \
  lua-memory.c \
  lua-profile.c \
  lua-multicast.c \
  lua-cluster.c \
  lua-crypt.c lsha1.c \
  lua-sharedata.c \
  lua-stm.c \
  lua-debugchannel.c \
  lua-datasheet.c \
  \

SKYNET_SRC = skynet_main.c skynet_handle.c skynet_module.c skynet_mq.c \
  skynet_server.c skynet_start.c skynet_timer.c skynet_error.c \
  skynet_harbor.c skynet_env.c skynet_monitor.c skynet_socket.c socket_server.c \
  malloc_hook.c skynet_daemon.c skynet_log.c

all : \
  $(SKYNET_BUILD_PATH)/skynet \
  $(foreach v, $(CSERVICE), $(CSERVICE_PATH)/$(v).so) \
  $(foreach v, $(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so) \
  $(foreach v, $(LUA_EX_CLIB), $(LUA_CLIB_PATH)/$(v).so) 

$(SKYNET_BUILD_PATH)/skynet : $(foreach v, $(SKYNET_SRC), skynet-src/$(v)) $(LUA_LIB) $(MALLOC_STATICLIB)
	$(CC) $(CFLAGS) -o $@ $^ -Iskynet-src -I$(JEMALLOC_INC) $(LDFLAGS) $(EXPORT) $(SKYNET_LIBS) $(SKYNET_DEFINES)

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(CSERVICE_PATH) :
	mkdir $(CSERVICE_PATH)

$(RS232_CLIB_PATH):
	cp 3rd/librs232/bindings/lua/rs232.lua lualib/
	mkdir $(RS232_CLIB_PATH)

define CSERVICE_TEMP
  $$(CSERVICE_PATH)/$(1).so : service-src/service_$(1).c | $$(CSERVICE_PATH)
	$$(CC) $$(CFLAGS) $$(SHARED) $$< -o $$@ -Iskynet-src
endef

$(foreach v, $(CSERVICE), $(eval $(call CSERVICE_TEMP,$(v))))

$(LUA_CLIB_PATH)/skynet.so : $(addprefix lualib-src/,$(LUA_CLIB_SKYNET)) | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet-src -Iservice-src -Ilualib-src

$(LUA_CLIB_PATH)/bson.so : lualib-src/lua-bson.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Iskynet-src $^ -o $@ -Iskynet-src

$(LUA_CLIB_PATH)/md5.so : 3rd/lua-md5/md5.c 3rd/lua-md5/md5lib.c 3rd/lua-md5/compat-5.2.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-md5 $^ -o $@ 

$(LUA_CLIB_PATH)/client.so : lualib-src/lua-clientsocket.c lualib-src/lua-crypt.c lualib-src/lsha1.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ 

$(LUA_CLIB_PATH)/sproto.so : lualib-src/sproto/sproto.c lualib-src/sproto/lsproto.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Ilualib-src/sproto $^ -o $@ 

$(LUA_CLIB_PATH)/lpeg.so : 3rd/lpeg/lpcap.c 3rd/lpeg/lpcode.c 3rd/lpeg/lpprint.c 3rd/lpeg/lptree.c 3rd/lpeg/lpvm.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lpeg $^ -o $@ 

$(LUA_CLIB_PATH)/lfs.so : 3rd/luafilesystem/src/lfs.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/luafilesystem/src $^ -o $@ 

$(LUA_CLIB_PATH)/cjson.so : 3rd/cjson/fpconv.c 3rd/cjson/lua_cjson.c 3rd/cjson/strbuf.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/cjson $^ -o $@ 

$(LUA_CLIB_PATH)/iconv.so : 3rd/iconv/luaiconv.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/iconv $^ -o $@ $(ICONV_LIBS)

$(LUA_CLIB_PATH)/enet.so : 3rd/lua-enet/enet.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/enet $^ -o $@  -lenet

$(LUA_CLIB_PATH)/rs232/core.so : 3rd/librs232/src/rs232.c 3rd/librs232/src/rs232_posix.c 3rd/librs232/bindings/lua/luars232.c | $(RS232_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/librs232/include $^ -o $@ 

$(LUA_CLIB_PATH)/libmodbus.so : 3rd/lua-libmodbus/lua-libmodbus.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-libmodbus $^ -o $@  -lmodbus

$(LUA_CLIB_PATH)/zlib.so : 3rd/lua-zlib/lua_zlib.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-zlib $^ -o $@  -lz

$(LUA_CLIB_PATH)/lsocket.so : 3rd/lsocket/lsocket.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lsocket $^ -o $@

LUA_CLIB_MQTT_MOSQ = \
	lib/actions.c \
	lib/handle_connack.c \
	lib/handle_publish.c \
	lib/handle_suback.c \
	lib/logging_mosq.c \
	lib/messages_mosq.c \
	lib/options.c \
	lib/send_connect.c \
	lib/send_publish.c \
	lib/socks_mosq.c \
	lib/time_mosq.c \
	lib/util_mosq.c \
	lib/callbacks.c \
	lib/handle_ping.c \
	lib/handle_pubrec.c \
	lib/handle_unsuback.c \
	lib/loop.c \
	lib/mosquitto.c \
	lib/packet_mosq.c \
	lib/send_disconnect.c \
	lib/send_subscribe.c \
	lib/srv_mosq.c \
	lib/tls_mosq.c \
	lib/will_mosq.c \
	lib/connect.c \
	lib/handle_pubackcomp.c \
	lib/handle_pubrel.c \
	lib/helpers.c \
	lib/memory_mosq.c \
	lib/net_mosq.c \
	lib/read_handle.c \
	lib/send_mosq.c \
	lib/send_unsubscribe.c \
	lib/thread_mosq.c \
	lib/utf8_mosq.c \
	\

LUA_CLIB_MOSQ = \
	lua-mosquitto.c \
	\

$(LUA_CLIB_PATH)/mosquitto.so : $(addprefix 3rd/lua-mosquitto/deps/mosquitto/,$(LUA_CLIB_MQTT_MOSQ)) $(addprefix 3rd/lua-mosquitto/,$(LUA_CLIB_MOSQ)) | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I3rd/lua-mosquitto/deps/mosquitto -I3rd/lua-mosquitto/deps/mosquitto/lib -I3rd/lua-mosquitto -DVERSION=\"1.4.12\" -DWITH_TLS -lssl 

LUA_CLIB_LCURL = \
	src/l52util.c \
	src/lceasy.c \
	src/lcerror.c \
	src/lchttppost.c \
	src/lcmime.c \
	src/lcmulti.c \
	src/lcshare.c \
	src/lcurl.c \
	src/lcutils.c \
	\

$(LUA_CLIB_PATH)/lcurl.so : $(addprefix 3rd/curl/,$(LUA_CLIB_LCURL)) | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I3rd/curl/src -DPTHREADS  -lcurl

clean :
	rm -f $(SKYNET_BUILD_PATH)/skynet $(CSERVICE_PATH)/*.so $(LUA_CLIB_PATH)/*.so
	rm -rf $(RS232_CLIB_PATH)

cleanall: clean
ifneq (,$(wildcard 3rd/jemalloc/Makefile))
	cd 3rd/jemalloc && $(MAKE) clean && rm Makefile
endif
	cd 3rd/lua && $(MAKE) clean
	rm -f $(LUA_STATICLIB)

